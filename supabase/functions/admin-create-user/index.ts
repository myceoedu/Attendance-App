import { createClient } from "jsr:@supabase/supabase-js@2";

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const USER_LIST_SELECT =
  "id,username,name,email,role,phone,created_at,employment_start_date,job_title,department,employee_code";

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function normalizeUsername(raw: string): string {
  return raw.trim().replace(/\s+/g, " ");
}

function isValidEmail(email: string): boolean {
  return /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/.test(email);
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!supabaseUrl || !anonKey || !serviceKey) {
    return json({ error: "Server is not configured" }, 500);
  }

  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader.toLowerCase().startsWith("bearer ")) {
    return json({ error: "Please sign in again" }, 401);
  }

  try {
    const caller = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const {
      data: { user },
      error: userErr,
    } = await caller.auth.getUser();
    if (userErr || user == null) {
      return json({ error: "Please sign in again" }, 401);
    }

    const { data: profile, error: profileErr } = await caller
      .from("users")
      .select("role")
      .eq("id", user.id)
      .maybeSingle();
    if (profileErr || profile?.role !== "admin") {
      return json({ error: "Only admins can add employees" }, 403);
    }

    let body: Record<string, unknown>;
    try {
      body = (await req.json()) as Record<string, unknown>;
    } catch {
      return json({ error: "Invalid request" }, 400);
    }

    const name = String(body.name ?? "").trim();
    const email = String(body.email ?? "").trim().toLowerCase();
    const username = normalizeUsername(String(body.username ?? ""));
    const password = String(body.password ?? "");

    if (name.length < 2) {
      return json({ error: "Enter the employee's full name" }, 400);
    }
    if (!isValidEmail(email)) {
      return json({ error: "Enter a valid email" }, 400);
    }
    if (username.length < 3 || username.length > 64) {
      return json({ error: "Username must be 3–64 characters" }, 400);
    }
    if (password.length < 6) {
      return json({ error: "Password must be at least 6 characters" }, 400);
    }

    const admin = createClient(supabaseUrl, serviceKey);

    const { data: available, error: availErr } = await admin.rpc(
      "is_username_available",
      { p_username: username },
    );
    if (availErr) {
      console.error("is_username_available", availErr);
      return json({ error: "Could not check username" }, 500);
    }
    if (available !== true) {
      return json({ error: "Username is already taken" }, 409);
    }

    const { data: created, error: createErr } = await admin.auth.admin
      .createUser({
        email,
        password,
        email_confirm: true,
        user_metadata: {
          username,
          name,
          role: "employee",
        },
      });

    if (createErr || created.user == null) {
      const raw = (createErr?.message ?? "").toLowerCase();
      if (
        raw.includes("already") ||
        raw.includes("registered") ||
        raw.includes("exists")
      ) {
        return json(
          { error: "An account with this email already exists" },
          409,
        );
      }
      if (raw.includes("username required")) {
        return json({ error: "Username is required" }, 400);
      }
      console.error("createUser", createErr);
      return json({ error: "Could not create employee. Try again." }, 400);
    }

    const newId = created.user.id;

    let { data: row, error: rowErr } = await admin
      .from("users")
      .select(USER_LIST_SELECT)
      .eq("id", newId)
      .maybeSingle();

    if (rowErr) {
      console.error("select profile", rowErr);
    }

    if (row == null) {
      const { error: insertErr } = await admin.from("users").insert({
        id: newId,
        email,
        name,
        username,
        role: "employee",
      });
      if (insertErr) {
        const dup = (insertErr.message ?? "").toLowerCase();
        if (dup.includes("users_username") || dup.includes("username")) {
          return json({ error: "Username is already taken" }, 409);
        }
        console.error("insert profile", insertErr);
        return json({ error: "Account created but profile failed. Try again." }, 500);
      }
      const second = await admin
        .from("users")
        .select(USER_LIST_SELECT)
        .eq("id", newId)
        .maybeSingle();
      row = second.data;
    }

    if (row == null) {
      return json({ error: "Account created but profile was not found." }, 500);
    }

    return json({ user: row }, 201);
  } catch (e) {
    console.error("admin-create-user", e);
    return json({ error: "Could not create employee. Try again." }, 500);
  }
});
