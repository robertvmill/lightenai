create table agent_config_versions (
  id uuid default gen_random_uuid() primary key,
  agent_id text not null,
  system_prompt text not null,
  allowed_tools text[] not null default '{}',
  source text not null default 'ui',
  note text,
  created_at timestamptz default now() not null
);

alter table agent_config_versions enable row level security;

create policy "Authenticated users can read versions"
  on agent_config_versions for select
  using (auth.role() = 'authenticated');

create policy "Authenticated users can insert versions"
  on agent_config_versions for insert
  with check (auth.role() = 'authenticated');

create index idx_config_versions_agent
  on agent_config_versions (agent_id, created_at desc);
