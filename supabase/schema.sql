-- Fantasy RM Online V1 - Supabase schema
create table if not exists public.player_saves (
  user_id uuid primary key references auth.users(id) on delete cascade,
  email text, character_name text not null default 'Heroi', class_name text not null default 'Guerreiro',
  level int not null default 1, stage int not null default 1, power int not null default 0,
  player jsonb not null default '{}'::jsonb, updated_at timestamptz not null default now()
);
alter table public.player_saves enable row level security;
create policy "players read own save" on public.player_saves for select using (auth.uid() = user_id);
create policy "players insert own save" on public.player_saves for insert with check (auth.uid() = user_id);
create policy "players update own save" on public.player_saves for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create or replace view public.global_ranking as
select character_name,class_name,level,stage,power,updated_at from public.player_saves order by power desc, level desc, stage desc limit 100;
grant select on public.global_ranking to anon, authenticated;
