import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-cron-secret"
};
// Helper to get today's UTC start/end
function getUtcDayRange(date = new Date()) {
  const start = new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate(), 0, 0, 0));
  const end = new Date(start.getTime() + 24 * 60 * 60 * 1000);
  return {
    start,
    end
  };
}
serve(async (req)=>{
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: corsHeaders
    });
  }
  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const supabase = createClient(supabaseUrl, serviceKey);
    const { start, end } = getUtcDayRange();
    // 1) Fetch today's assigned questions with question text
    const { data: todaysAssignments, error: uqError } = await supabase.from("user_questions").select(`
        user_id,
        question_id,
        received_at,
        questions!inner(text)
      `).gte("received_at", start.toISOString()).lt("received_at", end.toISOString()).eq("answered", false);
    if (uqError) {
      console.error("Failed to fetch user_questions", uqError);
      return new Response(JSON.stringify({
        error: uqError.message
      }), {
        status: 500,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json"
        }
      });
    }
    if (!todaysAssignments || todaysAssignments.length === 0) {
      return new Response(JSON.stringify({
        success: true,
        reminded: 0,
        reason: "no assignments today"
      }), {
        status: 200,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json"
        }
      });
    }
    // 2) Get couples data to group users
    const { data: couples, error: couplesError } = await supabase.from("couples").select("user1_id, user2_id");
    if (couplesError) {
      console.error("Failed to fetch couples", couplesError);
    }
    // Create a map of user -> couple
    const userToCouple = new Map();
    const coupleMap = new Map();
    if (couples) {
      couples.forEach((couple)=>{
        userToCouple.set(couple.user1_id, couple);
        userToCouple.set(couple.user2_id, couple);
        coupleMap.set(`${couple.user1_id}-${couple.user2_id}`, couple);
      });
    }
    // 3) Group assignments by question and couple status
    const questionGroups = new Map();
    todaysAssignments.forEach((assignment)=>{
      const key = assignment.question_id;
      if (!questionGroups.has(key)) {
        questionGroups.set(key, {
          questionText: assignment.questions?.text || "Today's question",
          soloUsers: [],
          coupleUsers: new Map()
        });
      }
      const group = questionGroups.get(key);
      const couple = userToCouple.get(assignment.user_id);
      if (couple) {
        const coupleKey = `${couple.user1_id}-${couple.user2_id}`;
        if (!group.coupleUsers.has(coupleKey)) {
          group.coupleUsers.set(coupleKey, []);
        }
        group.coupleUsers.get(coupleKey).push(assignment.user_id);
      } else {
        group.soloUsers.push(assignment.user_id);
      }
    });
    // 4) Send notifications
    let totalReminded = 0;
    const pushUrl = `${supabaseUrl}/functions/v1/send-push`;
    const pushSecret = Deno.env.get("PUSH_FUNCTION_SECRET") || undefined;
    for (const [questionId, group] of questionGroups){
      // Send to solo users
      if (group.soloUsers.length > 0) {
        try {
          const res = await fetch(pushUrl, {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              ...pushSecret ? {
                "x-push-secret": pushSecret
              } : {}
            },
            body: JSON.stringify({
              user_ids: group.soloUsers,
              title: "Daily Question Reminder",
              body: group.questionText,
              data: {
                event: "daily_question_reminder",
                question_id: questionId,
                type: "solo"
              }
            })
          });
          if (res.ok) {
            totalReminded += group.soloUsers.length;
            console.log(`Sent solo reminder to ${group.soloUsers.length} users for question: ${group.questionText}`);
          } else {
            console.error(`Failed to send solo notification:`, await res.text());
          }
        } catch (error) {
          console.error("Error sending solo notification:", error);
        }
      }
      // Send to couples (if both users haven't answered)
      for (const [coupleKey, userIds] of group.coupleUsers){
        if (userIds.length === 2) {
          // Both users in couple haven't answered
          try {
            const res = await fetch(pushUrl, {
              method: "POST",
              headers: {
                "Content-Type": "application/json",
                ...pushSecret ? {
                  "x-push-secret": pushSecret
                } : {}
              },
              body: JSON.stringify({
                user_ids: userIds,
                title: "Couple Question Reminder 💕",
                body: group.questionText,
                data: {
                  event: "daily_question_reminder",
                  question_id: questionId,
                  type: "couple"
                }
              })
            });
            if (res.ok) {
              totalReminded += userIds.length;
              console.log(`Sent couple reminder to 2 users for question: ${group.questionText}`);
            } else {
              console.error(`Failed to send couple notification:`, await res.text());
            }
          } catch (error) {
            console.error("Error sending couple notification:", error);
          }
        } else if (userIds.length === 1) {
          // Only one user hasn't answered, send solo notification
          try {
            const res = await fetch(pushUrl, {
              method: "POST",
              headers: {
                "Content-Type": "application/json",
                ...pushSecret ? {
                  "x-push-secret": pushSecret
                } : {}
              },
              body: JSON.stringify({
                user_ids: userIds,
                title: "Daily Question Reminder",
                body: group.questionText,
                data: {
                  event: "daily_question_reminder",
                  question_id: questionId,
                  type: "solo_couple_member"
                }
              })
            });
            if (res.ok) {
              totalReminded += userIds.length;
              console.log(`Sent solo reminder to 1 couple member for question: ${group.questionText}`);
            } else {
              console.error(`Failed to send solo couple member notification:`, await res.text());
            }
          } catch (error) {
            console.error("Error sending solo couple member notification:", error);
          }
        }
      }
    }
    return new Response(JSON.stringify({
      success: true,
      reminded: totalReminded,
      questions: questionGroups.size,
      breakdown: {
        solo_users: Array.from(questionGroups.values()).reduce((sum, g)=>sum + g.soloUsers.length, 0),
        couples: Array.from(questionGroups.values()).reduce((sum, g)=>sum + g.coupleUsers.size, 0)
      }
    }), {
      status: 200,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json"
      }
    });
  } catch (e) {
    console.error("daily-question-reminder error", e);
    return new Response(JSON.stringify({
      error: e.message || "Unknown error"
    }), {
      status: 500,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json"
      }
    });
  }
});
