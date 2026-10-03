-- Fantasy RM Online - perfil público seguro para inspeção de jogadores
-- Expõe apenas os dados necessários do personagem e não email/dados da conta.
create or replace function public.get_public_player_profile(p_user_id uuid)
returns table (
  character_name text,
  class_name text,
  level integer,
  stage integer,
  power bigint,
  player jsonb
)
language sql
security definer
set search_path = public
as $$
  select
    ps.character_name,
    ps.class_name,
    coalesce(ps.level,1)::integer,
    coalesce(ps.stage,1)::integer,
    coalesce(ps.power,0)::bigint,
    jsonb_build_object(
      'cls', ps.player->'cls',
      'hpMax', ps.player->'hpMax',
      'mpMax', ps.player->'mpMax',
      'atk', ps.player->'atk',
      'def', ps.player->'def',
      'str', ps.player->'str',
      'int', ps.player->'int',
      'agi', ps.player->'agi',
      'equip', coalesce(ps.player->'equip','{}'::jsonb)
    )
  from public.player_saves ps
  where ps.user_id = p_user_id
  limit 1;
$$;
revoke all on function public.get_public_player_profile(uuid) from public;
grant execute on function public.get_public_player_profile(uuid) to authenticated;
