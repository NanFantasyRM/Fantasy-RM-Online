-- Execute no SQL Editor do Supabase antes de ativar os espaços 2 e 3.
-- O personagem original permanece na tabela public.player_saves (espaço 1).
create table if not exists public.player_character_slots (
  user_id uuid not null references auth.users(id) on delete cascade,
  slot smallint not null check (slot in (2,3)),
  player jsonb not null,
  updated_at timestamptz not null default now(),
  primary key (user_id,slot)
);
alter table public.player_character_slots enable row level security;
drop policy if exists "character_slots_select_own" on public.player_character_slots;
drop policy if exists "character_slots_insert_own" on public.player_character_slots;
drop policy if exists "character_slots_update_own" on public.player_character_slots;
drop policy if exists "character_slots_delete_own" on public.player_character_slots;
create policy "character_slots_select_own" on public.player_character_slots for select to authenticated using (auth.uid()=user_id);
create policy "character_slots_insert_own" on public.player_character_slots for insert to authenticated with check (auth.uid()=user_id);
create policy "character_slots_update_own" on public.player_character_slots for update to authenticated using (auth.uid()=user_id) with check (auth.uid()=user_id);
create policy "character_slots_delete_own" on public.player_character_slots for delete to authenticated using (auth.uid()=user_id);
