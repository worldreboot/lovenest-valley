import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-cron-secret"
};

// Helper to get today's UTC date
function getUtcDate(date = new Date()) {
  return date.toISOString().split('T')[0];
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: corsHeaders
    });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const supabase = createClient(supabaseUrl, serviceKey);

    const today = getUtcDate();
    console.log(`Assigning daily questions for ${today}`);

    // Get all users who have profiles (active users)
    const { data: users, error: usersError } = await supabase
      .from("profiles")
      .select("id, username")
      .not("username", "is", null);

    if (usersError) {
      console.error("Failed to fetch users", usersError);
      return new Response(JSON.stringify({
        error: usersError.message
      }), {
        status: 500,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json"
        }
      });
    }

    if (!users || users.length === 0) {
      return new Response(JSON.stringify({
        success: true,
        message: "No active users found",
        assigned: 0
      }), {
        status: 200,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json"
        }
      });
    }

    let totalAssigned = 0;

    for (const user of users) {
      try {
        // Get questions user has already seen (answered or assigned)
        const { data: seenQuestions, error: seenError } = await supabase
          .from("user_questions")
          .select("question_id")
          .eq("user_id", user.id)
          .or("answered.eq.true,answered.is.null");

        if (seenError) {
          console.error(`Failed to get seen questions for user ${user.id}`, seenError);
          continue;
        }

        const seenQuestionIds = seenQuestions?.map((q) => q.question_id) || [];

        // Get a random unseen question
        let questionQuery = supabase
          .from("questions")
          .select("id, text");

        if (seenQuestionIds.length > 0) {
          questionQuery = questionQuery.not("id", "in", `(${seenQuestionIds.join(',')})`);
        }

        const { data: availableQuestions, error: questionsError } = await questionQuery;

        if (questionsError) {
          console.error(`Failed to get questions for user ${user.id}`, questionsError);
          continue;
        }

        if (!availableQuestions || availableQuestions.length === 0) {
          console.log(`No new questions available for user ${user.id}, will reuse questions`);
          // If all questions have been seen, get all questions and pick randomly
          const { data: allQuestions } = await supabase
            .from("questions")
            .select("id, text");

          if (!allQuestions || allQuestions.length === 0) continue;

          const randomQuestion = allQuestions[Math.floor(Math.random() * allQuestions.length)];

          // Assign the question
          const { error: assignError } = await supabase
            .from("user_questions")
            .insert({
              user_id: user.id,
              question_id: randomQuestion.id,
              received_at: new Date().toISOString()
            });

          if (assignError) {
            console.error(`Failed to assign question to user ${user.id}`, assignError);
          } else {
            totalAssigned++;
            console.log(`Assigned reused question to user ${user.username || user.id}: ${randomQuestion.text}`);
          }
        } else {
          // Pick a random unseen question
          const randomQuestion = availableQuestions[Math.floor(Math.random() * availableQuestions.length)];

          // Assign the question
          const { error: assignError } = await supabase
            .from("user_questions")
            .insert({
              user_id: user.id,
              question_id: randomQuestion.id,
              received_at: new Date().toISOString()
            });

          if (assignError) {
            console.error(`Failed to assign question to user ${user.id}`, assignError);
          } else {
            totalAssigned++;
            console.log(`Assigned new question to user ${user.username || user.id}: ${randomQuestion.text}`);
          }
        }
      } catch (error) {
        console.error(`Error processing user ${user.id}`, error);
      }
    }

    return new Response(JSON.stringify({
      success: true,
      message: `Assigned daily questions to ${totalAssigned} users`,
      assigned: totalAssigned,
      date: today
    }), {
      status: 200,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json"
      }
    });
  } catch (e) {
    console.error("assign-daily-questions error", e);
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
