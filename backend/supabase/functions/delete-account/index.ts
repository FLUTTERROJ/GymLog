// Called by the Flutter app with the caller's own session. Deletes the
// caller's own auth user via the Admin API -- the client SDK has no
// self-delete call, so this has to go through a service-role Edge Function,
// same shape as calendar-preview's auth check.
//
// Everything else (profile, workouts, workout_sets, custom exercises,
// monthly challenges, calendar connection/mappings, session reminders)
// cascades from auth.users via ON DELETE CASCADE -- see
// 20260727000100_init.sql and later migrations. Deleting the auth user is
// enough; there's nothing else to clean up by hand.
//
// A trainer's *trainees* are unaffected: profiles.trainer_id and
// workouts.trainer_id are ON DELETE SET NULL, so a trainee's own logged
// history survives their trainer's account being deleted.

import { createClient } from "npm:@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  const jsonHeaders = { ...corsHeaders, "Content-Type": "application/json" };

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return new Response(JSON.stringify({ error: "Not authenticated" }), {
      status: 401,
      headers: jsonHeaders,
    });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;

  // Scoped to the caller's own JWT, used only to find out who's asking --
  // deleteUser() below always targets that same id, never one from the
  // request body, so there's no way to delete anyone else's account.
  const callerClient = createClient(
    supabaseUrl,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authHeader } } },
  );

  const { data: { user }, error: userError } = await callerClient.auth
    .getUser();
  if (userError || !user) {
    return new Response(JSON.stringify({ error: "Not authenticated" }), {
      status: 401,
      headers: jsonHeaders,
    });
  }

  const adminClient = createClient(
    supabaseUrl,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const { error: deleteError } = await adminClient.auth.admin.deleteUser(
    user.id,
  );

  if (deleteError) {
    console.error(`Account deletion failed for ${user.id}:`, deleteError);
    return new Response(
      JSON.stringify({ error: "Could not delete your account. Try again." }),
      { status: 500, headers: jsonHeaders },
    );
  }

  return new Response(JSON.stringify({ deleted: true }), {
    headers: jsonHeaders,
  });
});
