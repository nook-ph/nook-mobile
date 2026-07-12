// Supabase Edge Function: delete-user
//
// Deploy from the Supabase project's CLI workspace (where `supabase/` lives):
//
//   supabase functions new delete-user
//   # paste the contents of `index` below into supabase/functions/delete-user/index.ts
//   supabase functions deploy delete-user --no-verify-jwt
//
// This function is invoked by the Flutter app via:
//   Supabase.instance.client.functions.invoke('delete-user', method: HttpMethod.post)
//
// Required env vars (auto-set by Supabase):
//   - SUPABASE_URL
//   - SUPABASE_ANON_KEY
//   - SUPABASE_SERVICE_ROLE_KEY
//
// The caller's JWT is passed in the Authorization header. The function:
//   1. Verifies the JWT and extracts the user id.
//   2. Hard-deletes every row linked to the user across public tables.
//   3. Deletes the `profiles` row.
//   4. Calls `supabase.auth.admin.deleteUser(userId)` to permanently erase
//      the `auth.users` record.
//
// IMPORTANT: Before deploying, verify whether `profiles.id -> auth.users(id)`
// and the child-table FKs already have `ON DELETE CASCADE`. If they do, the
// explicit deletes below are redundant but harmless. If they don't, the
// explicit deletes are required or `admin.deleteUser` will fail with an FK
// violation.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), {
      status: 405,
    })
  }

  const authHeader = req.headers.get('Authorization')
  if (!authHeader) {
    return new Response(JSON.stringify({ error: 'Missing auth header' }), {
      status: 401,
    })
  }

  const supabaseAdmin = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    { auth: { autoRefreshToken: false, persistSession: false } }
  )

  const supabaseClient = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_ANON_KEY')!,
    { global: { headers: { Authorization: authHeader } } }
  )

  const { data: { user }, error: userError } = await supabaseClient.auth.getUser()
  if (userError || !user) {
    return new Response(JSON.stringify({ error: 'Unauthorized' }), {
      status: 401,
    })
  }

  const userId = user.id

  // Child tables first (explicit deletes safe even if CASCADE exists)
  await supabaseAdmin.from('crawl_stamps').delete().eq('user_id', userId)
  await supabaseAdmin.from('crawl_registrations').delete().eq('user_id', userId)
  await supabaseAdmin.from('user_achievements').delete().eq('user_id', userId)
  await supabaseAdmin.from('review_helpful_votes').delete().eq('user_id', userId)
  await supabaseAdmin.from('reviews').delete().eq('user_id', userId)
  await supabaseAdmin.from('list_members').delete().eq('user_id', userId)
  await supabaseAdmin.from('list_cafes').delete().eq('added_by', userId)
  await supabaseAdmin.from('cafe_claims').delete().eq('claimant_id', userId)
  await supabaseAdmin.from('cafe_owner_cafe').delete().eq('owner_id', userId)
  await supabaseAdmin.from('owner_invites').delete().eq('invited_profile_id', userId)
  await supabaseAdmin.from('owner_invites').delete().eq('created_by', userId)
  await supabaseAdmin.from('owner_invites').delete().eq('resent_by', userId)
  await supabaseAdmin.from('review_reports').delete().eq('reporter_id', userId)
  await supabaseAdmin.from('review_moderation_actions').delete().eq('moderator_id', userId)
  await supabaseAdmin.from('blocked_users').delete().eq('blocker_id', userId)
  await supabaseAdmin.from('blocked_users').delete().eq('blocked_id', userId)
  await supabaseAdmin.from('menu_categories').delete().eq('created_by', userId)
  await supabaseAdmin.from('crawls').delete().eq('created_by', userId)
  await supabaseAdmin.from('audit_logs').delete().eq('actor_id', userId)

  await supabaseAdmin.from('profiles').delete().eq('id', userId)

  const { error: deleteError } = await supabaseAdmin.auth.admin.deleteUser(userId)
  if (deleteError) {
    return new Response(JSON.stringify({ error: deleteError.message }), {
      status: 500,
    })
  }

  return new Response(JSON.stringify({ success: true }), { status: 200 })
})
