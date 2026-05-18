-- social wallet schema + rls + rpc
create extension if not exists "pgcrypto";

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text not null,
  avatar_url text,
  created_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now()
);

create table if not exists public.friendships (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid not null references public.profiles(id) on delete cascade,
  addressee_id uuid not null references public.profiles(id) on delete cascade,
  status text not null check (status in ('pending','accepted','blocked')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint no_self_friend check (requester_id <> addressee_id)
);

create unique index if not exists friendships_pair_unique
on public.friendships (least(requester_id, addressee_id), greatest(requester_id, addressee_id));

create table if not exists public.time_wallets (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  balance_seconds integer not null default 0 check (balance_seconds >= 0),
  version integer not null default 0,
  updated_at timestamptz not null default now()
);

create table if not exists public.time_transfers (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references public.profiles(id) on delete cascade,
  receiver_id uuid not null references public.profiles(id) on delete cascade,
  seconds integer not null check (seconds > 0),
  type text not null check (type in ('gift','request','request_approved')),
  status text not null check (status in ('pending','approved','declined','completed','canceled')),
  memo text,
  request_transfer_id uuid references public.time_transfers(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references public.profiles(id) on delete set null,
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  type text not null,
  payload jsonb not null default '{}'::jsonb,
  read boolean not null default false,
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;
alter table public.friendships enable row level security;
alter table public.time_wallets enable row level security;
alter table public.time_transfers enable row level security;
alter table public.notifications enable row level security;

drop policy if exists profiles_read on public.profiles;
create policy profiles_read on public.profiles
for select to authenticated
using (
  id = auth.uid()
  or exists (
    select 1 from public.friendships f
    where f.status = 'accepted'
      and ((f.requester_id = auth.uid() and f.addressee_id = profiles.id)
      or (f.addressee_id = auth.uid() and f.requester_id = profiles.id))
  )
);

drop policy if exists profiles_update_self on public.profiles;
create policy profiles_update_self on public.profiles
for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

drop policy if exists friendships_participant on public.friendships;
create policy friendships_participant on public.friendships
for select to authenticated
using (requester_id = auth.uid() or addressee_id = auth.uid());

drop policy if exists wallets_owner on public.time_wallets;
create policy wallets_owner on public.time_wallets
for select to authenticated using (user_id = auth.uid());

drop policy if exists transfers_participant on public.time_transfers;
create policy transfers_participant on public.time_transfers
for select to authenticated
using (sender_id = auth.uid() or receiver_id = auth.uid());

drop policy if exists notifications_owner on public.notifications;
create policy notifications_owner on public.notifications
for select to authenticated
using (recipient_id = auth.uid());

create or replace function public.bootstrap_profile(p_username text, p_avatar_url text)
returns public.profiles
language plpgsql
security definer
as $$
declare
  v_uid uuid := auth.uid();
  v_profile public.profiles;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  insert into public.profiles (id, username, avatar_url)
  values (v_uid, coalesce(nullif(trim(p_username), ''), 'User'), p_avatar_url)
  on conflict (id) do update set
    username = excluded.username,
    avatar_url = coalesce(excluded.avatar_url, public.profiles.avatar_url),
    last_seen_at = now();

  insert into public.time_wallets (user_id, balance_seconds)
  values (v_uid, 0)
  on conflict (user_id) do nothing;

  select * into v_profile from public.profiles where id = v_uid;
  return v_profile;
end;
$$;

create or replace function public.get_transfer_limits()
returns jsonb
language plpgsql
security definer
as $$
declare
  v_uid uuid := auth.uid();
  v_daily_cap int := 3600;
  v_per_transfer int := 900;
  v_cooldown int := 60;
  v_today_sent int := 0;
  v_remaining int := 0;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  select coalesce(sum(seconds), 0)
  into v_today_sent
  from public.time_transfers
  where sender_id = v_uid
    and type in ('gift','request_approved')
    and status = 'completed'
    and created_at >= date_trunc('day', now());

  v_remaining := greatest(0, v_daily_cap - v_today_sent);
  return jsonb_build_object(
    'daily_cap_seconds', v_daily_cap,
    'daily_remaining_seconds', v_remaining,
    'per_transfer_max_seconds', v_per_transfer,
    'cooldown_seconds', v_cooldown
  );
end;
$$;

create or replace function public.send_friend_request(p_target_user_id uuid)
returns void
language plpgsql
security definer
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'not authenticated'; end if;
  if v_uid = p_target_user_id then raise exception 'cannot friend yourself'; end if;

  insert into public.friendships(requester_id, addressee_id, status)
  values (v_uid, p_target_user_id, 'pending')
  on conflict ((least(requester_id, addressee_id)), (greatest(requester_id, addressee_id))) do nothing;

  insert into public.notifications(actor_id, recipient_id, type, payload)
  values (v_uid, p_target_user_id, 'friend_request', jsonb_build_object('from', v_uid));
end;
$$;

create or replace function public.accept_friend_request(p_friendship_id uuid)
returns void
language plpgsql
security definer
as $$
declare
  v_uid uuid := auth.uid();
  v_requester uuid;
  v_addressee uuid;
begin
  if v_uid is null then raise exception 'not authenticated'; end if;

  select requester_id, addressee_id into v_requester, v_addressee
  from public.friendships where id = p_friendship_id for update;

  if v_addressee <> v_uid then raise exception 'not authorized'; end if;

  update public.friendships
  set status='accepted', updated_at=now()
  where id = p_friendship_id;

  insert into public.notifications(actor_id, recipient_id, type, payload)
  values (v_uid, v_requester, 'friend_accepted', jsonb_build_object('friendship_id', p_friendship_id));
end;
$$;

create or replace function public.request_time(p_from_user_id uuid, p_seconds int, p_memo text)
returns uuid
language plpgsql
security definer
as $$
declare
  v_uid uuid := auth.uid();
  v_transfer_id uuid;
begin
  if v_uid is null then raise exception 'not authenticated'; end if;

  insert into public.time_transfers(sender_id, receiver_id, seconds, type, status, memo)
  values (v_uid, p_from_user_id, p_seconds, 'request', 'pending', p_memo)
  returning id into v_transfer_id;

  insert into public.notifications(actor_id, recipient_id, type, payload)
  values (v_uid, p_from_user_id, 'time_request', jsonb_build_object('request_id', v_transfer_id, 'seconds', p_seconds));

  return v_transfer_id;
end;
$$;

create or replace function public.send_time_gift(p_to_user_id uuid, p_seconds int, p_memo text)
returns uuid
language plpgsql
security definer
as $$
declare
  v_uid uuid := auth.uid();
  v_transfer_id uuid;
  v_sender_balance int;
begin
  if v_uid is null then raise exception 'not authenticated'; end if;

  select balance_seconds into v_sender_balance from public.time_wallets where user_id = v_uid for update;
  if v_sender_balance < p_seconds then raise exception 'insufficient balance'; end if;

  update public.time_wallets
  set balance_seconds = balance_seconds - p_seconds,
      version = version + 1,
      updated_at = now()
  where user_id = v_uid;

  update public.time_wallets
  set balance_seconds = balance_seconds + p_seconds,
      version = version + 1,
      updated_at = now()
  where user_id = p_to_user_id;

  insert into public.time_transfers(sender_id, receiver_id, seconds, type, status, memo)
  values (v_uid, p_to_user_id, p_seconds, 'gift', 'completed', p_memo)
  returning id into v_transfer_id;

  insert into public.notifications(actor_id, recipient_id, type, payload)
  values (v_uid, p_to_user_id, 'time_gift', jsonb_build_object('transfer_id', v_transfer_id, 'seconds', p_seconds));

  return v_transfer_id;
end;
$$;

create or replace function public.approve_time_request(p_request_transfer_id uuid)
returns uuid
language plpgsql
security definer
as $$
declare
  v_uid uuid := auth.uid();
  v_request public.time_transfers%rowtype;
  v_sender_balance int;
  v_transfer_id uuid;
begin
  if v_uid is null then raise exception 'not authenticated'; end if;

  select * into v_request from public.time_transfers where id = p_request_transfer_id for update;
  if v_request.id is null then raise exception 'request not found'; end if;
  if v_request.receiver_id <> v_uid then raise exception 'not request target'; end if;
  if v_request.status <> 'pending' then raise exception 'request not pending'; end if;

  select balance_seconds into v_sender_balance from public.time_wallets where user_id = v_uid for update;
  if v_sender_balance < v_request.seconds then raise exception 'insufficient balance'; end if;

  update public.time_wallets
  set balance_seconds = balance_seconds - v_request.seconds,
      version = version + 1,
      updated_at = now()
  where user_id = v_uid;

  update public.time_wallets
  set balance_seconds = balance_seconds + v_request.seconds,
      version = version + 1,
      updated_at = now()
  where user_id = v_request.sender_id;

  update public.time_transfers
  set status = 'approved', updated_at = now()
  where id = p_request_transfer_id;

  insert into public.time_transfers(sender_id, receiver_id, seconds, type, status, memo, request_transfer_id)
  values (v_uid, v_request.sender_id, v_request.seconds, 'request_approved', 'completed', v_request.memo, p_request_transfer_id)
  returning id into v_transfer_id;

  insert into public.notifications(actor_id, recipient_id, type, payload)
  values (v_uid, v_request.sender_id, 'time_request_approved', jsonb_build_object('request_id', p_request_transfer_id, 'transfer_id', v_transfer_id));

  return v_transfer_id;
end;
$$;
