import { createClient } from "@/lib/supabase/server";
import { createAdminClient } from "@/lib/supabase/admin";
import { NextRequest } from "next/server";

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ agentId: string }> }
) {
  const { agentId } = await params;
  const { searchParams } = new URL(request.url);
  const versionId = searchParams.get("id");

  const supabase = await createClient();

  // Single version with full content
  if (versionId) {
    const { data, error } = await supabase
      .from("agent_config_versions")
      .select("*")
      .eq("id", versionId)
      .eq("agent_id", agentId)
      .single();

    if (error || !data) {
      return Response.json({ error: "Version not found" }, { status: 404 });
    }

    return Response.json(data);
  }

  // List versions (omit full prompt for speed)
  const { data, error } = await supabase
    .from("agent_config_versions")
    .select("id, agent_id, source, note, allowed_tools, created_at")
    .eq("agent_id", agentId)
    .order("created_at", { ascending: false })
    .limit(50);

  if (error) {
    return Response.json({ error: error.message }, { status: 500 });
  }

  return Response.json(data ?? []);
}

export async function POST(
  request: NextRequest,
  { params }: { params: Promise<{ agentId: string }> }
) {
  const { agentId } = await params;
  const body = await request.json();

  const { systemPrompt, allowedTools, source, note } = body;

  if (!systemPrompt) {
    return Response.json({ error: "systemPrompt is required" }, { status: 400 });
  }

  // Use admin client to bypass RLS (called from terminal script)
  const supabase = createAdminClient();
  const { data, error } = await supabase
    .from("agent_config_versions")
    .insert({
      agent_id: agentId,
      system_prompt: systemPrompt,
      allowed_tools: allowedTools ?? [],
      source: source ?? "api",
      note: note ?? null,
    })
    .select()
    .single();

  if (error) {
    return Response.json({ error: error.message }, { status: 500 });
  }

  return Response.json(data, { status: 201 });
}
