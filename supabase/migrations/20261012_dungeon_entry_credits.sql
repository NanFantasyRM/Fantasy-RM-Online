-- Entradas extras concedidas pelo ADM: persistentes, por conta e consumidas atomicamente.
create table if not exists public.dungeon_entry_credits (
 user_id uuid primary key references auth.users(id) on delete cascade,
 pet integer not null default 0 check (pet>=0),
 exp integer not null default 0 check (exp>=0),
 guild integer not null default 0 check (guild>=0),
 updated_at timestamptz not null default now()
);
alter table public.dungeon_entry_credits enable row level security;
revoke all on public.dungeon_entry_credits from anon,authenticated;
create or replace function public.dungeon_entry_balance()
returns jsonb language sql security definer set search_path=public as $$
 select jsonb_build_object('pet',coalesce((select pet from public.dungeon_entry_credits where user_id=auth.uid()),0),
 'exp',coalesce((select exp from public.dungeon_entry_credits where user_id=auth.uid()),0),
 'guild',coalesce((select guild from public.dungeon_entry_credits where user_id=auth.uid()),0))
$$;
create or replace function public.admin_grant_dungeon_entries(p_target uuid,p_dungeon text,p_amount integer)
returns jsonb language plpgsql security definer set search_path=public as $$
declare v public.dungeon_entry_credits;
begin
 if not public.is_admin() then raise exception 'Acesso restrito ao ADM'; end if;
 if p_target is null or not exists(select 1 from auth.users where id=p_target) then raise exception 'Jogador inexistente'; end if;
 if p_dungeon not in ('pet','exp','guild') or p_amount not between 1 and 100 then raise exception 'Dados inválidos'; end if;
 insert into public.dungeon_entry_credits(user_id) values(p_target) on conflict(user_id) do nothing;
 if p_dungeon='pet' then update public.dungeon_entry_credits set pet=pet+p_amount,updated_at=now() where user_id=p_target returning * into v;
 elsif p_dungeon='exp' then update public.dungeon_entry_credits set exp=exp+p_amount,updated_at=now() where user_id=p_target returning * into v;
 else update public.dungeon_entry_credits set guild=guild+p_amount,updated_at=now() where user_id=p_target returning * into v;
 end if;
 return jsonb_build_object('pet',v.pet,'exp',v.exp,'guild',v.guild);
end $$;
create or replace function public.consume_dungeon_entry_credit(p_dungeon text)
returns boolean language plpgsql security definer set search_path=public as $$
declare changed integer;
begin
 if auth.uid() is null or p_dungeon not in ('pet','exp','guild') then return false; end if;
 if p_dungeon='pet' then update public.dungeon_entry_credits set pet=pet-1,updated_at=now() where user_id=auth.uid() and pet>0;
 elsif p_dungeon='exp' then update public.dungeon_entry_credits set exp=exp-1,updated_at=now() where user_id=auth.uid() and exp>0;
 else update public.dungeon_entry_credits set guild=guild-1,updated_at=now() where user_id=auth.uid() and guild>0;
 end if;
 get diagnostics changed=row_count;
 return changed=1;
end $$;
revoke all on function public.dungeon_entry_balance() from public;
revoke all on function public.admin_grant_dungeon_entries(uuid,text,integer) from public;
revoke all on function public.consume_dungeon_entry_credit(text) from public;
grant execute on function public.dungeon_entry_balance() to authenticated;
grant execute on function public.admin_grant_dungeon_entries(uuid,text,integer) to authenticated;
grant execute on function public.consume_dungeon_entry_credit(text) to authenticated;
