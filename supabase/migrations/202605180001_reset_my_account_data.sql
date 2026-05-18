create or replace function public.reset_my_account_data()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  delete from public.notifications
  where recipient_id = v_uid or actor_id = v_uid;

  delete from public.time_transfers
  where sender_id = v_uid or receiver_id = v_uid;

  delete from public.friendships
  where requester_id = v_uid or addressee_id = v_uid;

  insert into public.time_wallets (
    user_id,
    balance_seconds,
    daily_limit_seconds,
    reset_interval_seconds,
    reset_anchor_at,
    bonus_refill_interval_seconds,
    bonus_amount_seconds,
    last_bonus_at,
    daily_time_ran_out_at,
    version,
    updated_at
  )
  values (
    v_uid,
    0,
    0,
    86400,
    null,
    3600,
    300,
    null,
    null,
    1,
    now()
  )
  on conflict (user_id) do update set
    balance_seconds = 0,
    daily_limit_seconds = 0,
    reset_interval_seconds = 86400,
    reset_anchor_at = null,
    bonus_refill_interval_seconds = 3600,
    bonus_amount_seconds = 300,
    last_bonus_at = null,
    daily_time_ran_out_at = null,
    version = public.time_wallets.version + 1,
    updated_at = now();

  update public.profiles
  set last_seen_at = now()
  where id = v_uid;
end;
$$;
