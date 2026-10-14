-- Fantasy RM: boss compartilhado da guilda (100.000 HP).
-- Execute no SQL Editor do Supabase antes de habilitar o combate no cliente.
create table if not exists public.guild_boss_state (
  guild_id uuid primary key references public.guilds(id) on delete cascade,
  hp integer not null default 100000 check (hp between 0 and 100000),
  max_hp integer not null default 100000 check (max_hp = 100000),
  defeated_at timestamptz,
  updated_at timestamptz not null default now()
);
create table if not exists public.guild_boss_damage (
  guild_id uuid not null references public.guilds(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  character_name text not null default 'Aventureiro',
  total_damage bigint not null default 0 check (total_damage >= 0),
  updated_at timestamptz not null default now(),
  primary key (guild_id,user_id)
);
alter table public.guild_boss_state enable row level security;
alter table public.guild_boss_damage enable row level security;
drop policy if exists guild_boss_state_read on public.guild_boss_state;
create policy guild_boss_state_read on public.guild_boss_state for select to authenticated
 using (exists(select 1 from public.guild_members gm where gm.guild_id = guild_boss_state.guild_id and gm.user_id = auth.uid()));
drop policy if exists guild_boss_damage_read on public.guild_boss_damage;
create policy guild_boss_damage_read on public.guild_boss_damage for select to authenticated
 using (exists(select 1 from public.guild_members gm where gm.guild_id = guild_boss_damage.guild_id and gm.user_id = auth.uid()));
create or replace function public.guild_boss_hit(p_damage integer, p_character_name text default 'Aventureiro')
returns table(hp integer, dealt integer, defeated boolean)
language plpgsql security definer set search_path = public, pg_temp as $$
declare v_guild uuid; v_hp integer; v_dealt integer;
begin
  select gm.guild_id into v_guild from public.guild_members gm where gm.user_id = auth.uid() limit 1;
  if v_guild is null then raise exception 'Você não pertence a uma guilda'; end if;
  if p_damage is null or p_damage < 1 or p_damage > 100000 then raise exception 'Dano inválido'; end if;
  insert into public.guild_boss_state(guild_id) values(v_guild) on conflict(guild_id) do nothing;
  select s.hp into v_hp from public.guild_boss_state s where s.guild_id=v_guild for update;
  v_dealt := least(v_hp,p_damage);
  update public.guild_boss_state s set hp=s.hp-v_dealt, updated_at=now(),
    defeated_at=case when s.hp-v_dealt=0 then coalesce(s.defeated_at,now()) else null end
    where s.guild_id=v_guild returning s.hp into v_hp;
  if v_dealt>0 then
    insert into public.guild_boss_damage(guild_id,user_id,character_name,total_damage)
    values(v_guild,auth.uid(),left(coalesce(nullif(trim(p_character_name),''),'Aventureiro'),80),v_dealt)
    on conflict(guild_id,user_id) do update
    set total_damage=public.guild_boss_damage.total_damage+excluded.total_damage,
        character_name=excluded.character_name,updated_at=now();
  end if;
  return query select v_hp,v_dealt,v_hp=0;
end $$;
revoke all on function public.guild_boss_hit(integer,text) from public;
grant execute on function public.guild_boss_hit(integer,text) to authenticated;
-- OBS: a RPC deve ser combinada com rate limit/validação de dano no servidor
-- antes de produção competitiva; o cliente não é uma fonte confiável de dano.
