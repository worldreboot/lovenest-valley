import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Create Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL')
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
    
    if (!supabaseUrl || !supabaseServiceKey) {
      throw new Error('Missing Supabase environment variables')
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    // Get all users with push tokens
    const { data: pushSubscriptions, error: fetchError } = await supabase
      .from('push_subscriptions')
      .select('user_id, token, platform')

    if (fetchError) {
      console.error('Error fetching push subscriptions:', fetchError)
      return new Response(
        JSON.stringify({ error: 'Failed to fetch push subscriptions' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    if (!pushSubscriptions || pushSubscriptions.length === 0) {
      return new Response(
        JSON.stringify({ message: 'No push subscriptions found', count: 0 }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Get FCM credentials
    const fcmServerKey = Deno.env.get('FCM_SERVER_KEY')
    if (!fcmServerKey) {
      throw new Error('Missing FCM_SERVER_KEY environment variable')
    }

    // Group tokens by platform for efficient sending
    const androidTokens = pushSubscriptions
      .filter(sub => sub.platform === 'android')
      .map(sub => sub.token)
    
    const iosTokens = pushSubscriptions
      .filter(sub => sub.platform === 'ios')
      .map(sub => sub.token)

    let totalSent = 0
    let totalFailed = 0

    // Send to Android devices
    if (androidTokens.length > 0) {
      const androidResult = await sendFCMNotification(
        androidTokens,
        'Test Notification - Lovenest Valley',
        'This is a test push notification to all users! 🎉',
        fcmServerKey
      )
      totalSent += androidResult.success
      totalFailed += androidResult.failed
    }

    // Send to iOS devices
    if (iosTokens.length > 0) {
      const iosResult = await sendFCMNotification(
        iosTokens,
        'Test Notification - Lovenest Valley',
        'This is a test push notification to all users! 🎉',
        fcmServerKey
      )
      totalSent += iosResult.success
      totalFailed += iosResult.failed
    }

    return new Response(
      JSON.stringify({
        message: 'Test notification sent',
        totalSubscriptions: pushSubscriptions.length,
        androidTokens: androidTokens.length,
        iosTokens: iosTokens.length,
        totalSent,
        totalFailed
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Error sending test notification:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})

async function sendFCMNotification(tokens, title, body, serverKey) {
  const fcmUrl = 'https://fcm.googleapis.com/fcm/send'
  
  const payload = {
    registration_ids: tokens,
    notification: {
      title: title,
      body: body,
      sound: 'default',
      badge: '1'
    },
    data: {
      event: 'test_notification',
      timestamp: new Date().toISOString()
    },
    priority: 'high'
  }

  try {
    const response = await fetch(fcmUrl, {
      method: 'POST',
      headers: {
        'Authorization': `key=${serverKey}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(payload)
    })

    if (!response.ok) {
      const errorText = await response.text()
      console.error('FCM request failed:', response.status, errorText)
      return { success: 0, failed: tokens.length }
    }

    const result = await response.json()
    
    // Count successful and failed deliveries
    let success = 0
    let failed = 0
    
    if (result.results) {
      result.results.forEach((item, index) => {
        if (item.message_id) {
          success++
        } else {
          failed++
          console.error(`Failed to send to token ${index}:`, item.error)
        }
      })
    }

    return { success, failed }
  } catch (error) {
    console.error('Error sending FCM notification:', error)
    return { success: 0, failed: tokens.length }
  }
}
