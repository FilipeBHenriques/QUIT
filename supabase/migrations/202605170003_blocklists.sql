create table if not exists public.user_blocklists (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  blocked_apps text[] not null default '{}',
  blocked_websites text[] not null default '{}',
  custom_websites text[] not null default '{}',
  updated_at timestamptz not null default now()
);

alter table public.user_blocklists enable row level security;

drop policy if exists user_blocklists_owner_select on public.user_blocklists;
create policy user_blocklists_owner_select on public.user_blocklists
for select to authenticated
using (user_id = auth.uid());

drop policy if exists user_blocklists_owner_upsert on public.user_blocklists;
create policy user_blocklists_owner_upsert on public.user_blocklists
for all to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

create or replace function public.set_user_blocklists(
  p_blocked_apps text[],
  p_blocked_websites text[],
  p_custom_websites text[]
)
returns public.user_blocklists
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_row public.user_blocklists;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  insert into public.user_blocklists (
    user_id,
    blocked_apps,
    blocked_websites,
    custom_websites,
    updated_at
  )
  values (
    v_uid,
    coalesce(p_blocked_apps, '{}'),
    coalesce(p_blocked_websites, '{}'),
    coalesce(p_custom_websites, '{}'),
    now()
  )
  on conflict (user_id) do update set
    blocked_apps = coalesce(excluded.blocked_apps, '{}'),
    blocked_websites = coalesce(excluded.blocked_websites, '{}'),
    custom_websites = coalesce(excluded.custom_websites, '{}'),
    updated_at = now();

  select * into v_row from public.user_blocklists where user_id = v_uid;
  return v_row;
end;
$$;
