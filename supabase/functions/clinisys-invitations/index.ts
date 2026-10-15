import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type", "Access-Control-Allow-Methods": "POST, OPTIONS", "Content-Type": "application/json" };
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: cors });
async function sha256(value: string) { const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value)); return Array.from(new Uint8Array(digest)).map(x => x.toString(16).padStart(2, "0")).join(""); }
function requestClient(req: Request) { return createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!, { global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } } }); }
function adminClient() { return createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { autoRefreshToken: false, persistSession: false } }); }

Deno.serve(async req => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "Méthode non autorisée." }, 405);
  try {
    const body = await req.json();
    const { data: { user }, error: userError } = await requestClient(req).auth.getUser();
    if (userError || !user) return json({ error: "Connexion requise." }, 401);
    const admin = adminClient();
    if (body?.action === "create") {
      const { data: member } = await admin.from("clinisys_workspace_members").select("role").eq("user_id", user.id).maybeSingle();
      if (member?.role !== "admin") return json({ error: "Droits administrateur requis." }, 403);
      const email = String(body.email ?? "").trim().toLowerCase() || null, phone = String(body.phone ?? "").trim(), displayName = String(body.displayName ?? "").trim(), role = body.role === "admin" ? "admin" : "member";
      if (!phone || !displayName || (email && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email))) return json({ error: "Numéro WhatsApp ou nom invalide." }, 400);
      const raw = new Uint8Array(32); crypto.getRandomValues(raw);
      const token = Array.from(raw).map(x => x.toString(16).padStart(2, "0")).join("");
      const expiresAt = new Date(Date.now() + 7 * 86400000).toISOString();
      const { error } = await admin.from("clinisys_invitations").insert({ email, phone, display_name: displayName, role, token_hash: await sha256(token), created_by: user.id, expires_at: expiresAt });
      if (error) return json({ error: error.message }, 400);
      const appUrl = "https://alaeddineghorbel.github.io/Clinisys-infogerance/clinisys_infog%C3%A9rance_gestion_taches.html";
      const inviteUrl = appUrl + "?invite=" + encodeURIComponent(token) + "&phone=" + encodeURIComponent(phone);
      const message = "Vous êtes invité(e) à CliniSys Infogérance. Ouvrez ce lien, saisissez votre e-mail et confirmez-le : " + inviteUrl;
      return json({ inviteUrl, whatsappUrl: "https://wa.me/?text=" + encodeURIComponent(message), expiresAt });
    }
    if (body?.action === "accept") {
      const token = String(body.token ?? ""), displayName = String(body.displayName ?? "").trim();
      if (!token || !displayName) return json({ error: "Invitation ou nom manquant." }, 400);
      const { data: invitation } = await admin.from("clinisys_invitations").select("id,email,phone,role,expires_at,accepted_at").eq("token_hash", await sha256(token)).maybeSingle();
      if (!invitation || invitation.accepted_at || new Date(invitation.expires_at).getTime() < Date.now()) return json({ error: "Invitation invalide, expirée ou déjà utilisée." }, 400);
      if (invitation.email && (user.email ?? "").toLowerCase() !== String(invitation.email).toLowerCase()) return json({ error: "L’adresse e-mail du compte ne correspond pas à l’invitation." }, 403);
      const { error: profileError } = await admin.from("clinisys_profiles").upsert({ user_id: user.id, display_name: displayName, email: user.email, phone: invitation.phone, updated_at: new Date().toISOString() });
      if (profileError) return json({ error: profileError.message }, 400);
      const { error: memberError } = await admin.from("clinisys_workspace_members").upsert({ user_id: user.id, role: invitation.role === "admin" ? "admin" : "member" });
      if (memberError) return json({ error: memberError.message }, 400);
      const { error: acceptError } = await admin.from("clinisys_invitations").update({ accepted_at: new Date().toISOString() }).eq("id", invitation.id);
      if (acceptError) return json({ error: acceptError.message }, 400);
      return json({ ok: true, displayName });
    }
    return json({ error: "Action inconnue." }, 400);
  } catch (error) { return json({ error: error instanceof Error ? error.message : "Erreur serveur." }, 500); }
});

