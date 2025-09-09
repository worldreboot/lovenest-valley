import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  }

  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const { data: pushSubscriptions } = await supabase
      .from('push_subscriptions')
      .select('user_id, token, platform')

    if (!pushSubscriptions || pushSubscriptions.length === 0) {
      return new Response(
        JSON.stringify({ message: 'No push subscriptions found', count: 0 }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const fcmServerKey = Deno.env.get('FCM_SERVER_KEY')
    if (!fcmServerKey) {
      throw new Error('Missing FCM_SERVER_KEY')
    }

    const tokens = pushSubscriptions.map(sub => sub.token)
    const payload = {
      registration_ids: tokens,
      notification: {
        title: 'Test Notification - Lovenest Valley',
        body: 'This is a test push notification to all users! 🎉',
        sound: 'default',
        badge: '1'
      },
      data: {
        event: 'test_notification',
        timestamp: new Date().toISOString()
      },
      priority: 'high'
    }

    const response = await fetch('https://fcm.googleapis.com/fcm/send', {
      method: 'POST',
      headers: {
        'Authorization': `key=${fcmServerKey}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(payload)
    })

    const result = await response.json()
    let success = 0
    let failed = 0

    if (result.results) {
      result.results.forEach((item: any) => {
        if (item.message_id) success++
        else failed++
      })
    }

    return new Response(
      JSON.stringify({
        message: 'Test notification sent',
        totalSubscriptions: pushSubscriptions.length,
        totalSent: success,
        totalFailed: failed
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
