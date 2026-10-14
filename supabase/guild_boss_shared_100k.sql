-- Fantasy RM: boss compartilhado da guilda (100.000 HP).
-- Execute no SQL Editor do Supabase antes de habilitar o combate no cliente.
create table if not exists public.guild_boss_state (
  guild_id uuid primary key references public.guilds(id) on delete cascade,
  hp bigint not null default 100000 check (hp >= 0),
  max_hp bigint not null default 100000 check (max_hp >= 100000),
  boss_level integer not null default 1 check (boss_level >= 1),
  bosses_defeated integer not null default 0 check (bosses_defeated >= 0),
  defeated_at timestamptz,
  updated_at timestamptz not null default now()
);
-- Compatibilidade com instalações que já executaram a primeira versão.
alter table public.guild_boss_state drop constraint if exists guild_boss_state_hp_check;
alter table public.guild_boss_state drop constraint if exists guild_boss_state_max_hp_check;
alter table public.guild_boss_state alter column hp type bigint;
alter table public.guild_boss_state alter column max_hp type bigint;
alter table public.guild_boss_state add column if not exists boss_level integer not null default 1;
alter table public.guild_boss_state add column if not exists bosses_defeated integer not null default 0;
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
drop function if exists public.guild_boss_hit(integer,text);
create function public.guild_boss_hit(p_damage integer, p_character_name text default 'Aventureiro')
returns table(hp bigint, dealt integer, defeated boolean, boss_level integer, max_hp bigint, bosses_defeated integer)
language plpgsql security definer set search_path = public, pg_temp as $$
declare v_guild uuid; v_hp bigint; v_dealt integer; v_level integer; v_max bigint; v_kills integer; v_defeated boolean := false;
begin
  select gm.guild_id into v_guild from public.guild_members gm where gm.user_id = auth.uid() limit 1;
  if v_guild is null then raise exception 'Você não pertence a uma guilda'; end if;
  if p_damage is null or p_damage < 1 or p_damage > 100000 then raise exception 'Dano inválido'; end if;
  insert into public.guild_boss_state(guild_id) values(v_guild) on conflict(guild_id) do nothing;
  select s.hp,s.boss_level,s.max_hp,s.bosses_defeated into v_hp,v_level,v_max,v_kills from public.guild_boss_state s where s.guild_id=v_guild for update;
  v_dealt := least(v_hp,p_damage);
  v_defeated := v_hp > 0 and v_dealt = v_hp;
  if v_defeated then
    v_kills := v_kills+1;
    v_level := v_level+1;
    v_max := least(9000000000000000000::bigint,ceil(v_max::numeric*1.5)::bigint);
    v_hp := v_max;
  else
    v_hp := v_hp-v_dealt;
  end if;
  update public.guild_boss_state s set hp=v_hp,max_hp=v_max,boss_level=v_level,bosses_defeated=v_kills,
    updated_at=now(),defeated_at=case when v_defeated then now() else s.defeated_at end where s.guild_id=v_guild;
  if v_dealt>0 then
    insert into public.guild_boss_damage(guild_id,user_id,character_name,total_damage)
    values(v_guild,auth.uid(),left(coalesce(nullif(trim(p_character_name),''),'Aventureiro'),80),v_dealt)
    on conflict(guild_id,user_id) do update
    set total_damage=public.guild_boss_damage.total_damage+excluded.total_damage,
        character_name=excluded.character_name,updated_at=now();
  end if;
  return query select v_hp,v_dealt,v_defeated,v_level,v_max,v_kills;
end $$;
revoke all on function public.guild_boss_hit(integer,text) from public;
grant execute on function public.guild_boss_hit(integer,text) to authenticated;
-- OBS: a RPC deve ser combinada com rate limit/validação de dano no servidor
-- antes de produção competitiva; o cliente não é uma fonte confiável de dano.
