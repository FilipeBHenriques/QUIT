alter table public.time_wallets
  add column if not exists daily_limit_seconds integer not null default 0,
  add column if not exists reset_interval_seconds integer not null default 86400,
  add column if not exists reset_anchor_at timestamptz,
  add column if not exists bonus_refill_interval_seconds integer not null default 3600,
  add column if not exists bonus_amount_seconds integer not null default 300,
  add column if not exists last_bonus_at timestamptz,
  add column if not exists daily_time_ran_out_at timestamptz;

create or replace function public.set_wallet_state(
  p_balance_seconds int,
  p_daily_limit_seconds int,
  p_reset_interval_seconds int,
  p_reset_anchor_ms bigint,
  p_bonus_refill_interval_seconds int,
  p_bonus_amount_seconds int,
  p_last_bonus_ms bigint,
  p_daily_time_ran_out_ms bigint
)
returns public.time_wallets
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_wallet public.time_wallets;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

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
    greatest(0, p_balance_seconds),
    greatest(0, p_daily_limit_seconds),
    greatest(1, p_reset_interval_seconds),
    case when p_reset_anchor_ms > 0 then to_timestamp(p_reset_anchor_ms / 1000.0) else null end,
    greatest(1, p_bonus_refill_interval_seconds),
    greatest(0, p_bonus_amount_seconds),
    case when p_last_bonus_ms > 0 then to_timestamp(p_last_bonus_ms / 1000.0) else null end,
    case when p_daily_time_ran_out_ms > 0 then to_timestamp(p_daily_time_ran_out_ms / 1000.0) else null end,
    1,
    now()
  )
  on conflict (user_id) do update set
    balance_seconds = greatest(0, p_balance_seconds),
    daily_limit_seconds = greatest(0, p_daily_limit_seconds),
    reset_interval_seconds = greatest(1, p_reset_interval_seconds),
    reset_anchor_at = case when p_reset_anchor_ms > 0 then to_timestamp(p_reset_anchor_ms / 1000.0) else null end,
    bonus_refill_interval_seconds = greatest(1, p_bonus_refill_interval_seconds),
    bonus_amount_seconds = greatest(0, p_bonus_amount_seconds),
    last_bonus_at = case when p_last_bonus_ms > 0 then to_timestamp(p_last_bonus_ms / 1000.0) else null end,
    daily_time_ran_out_at = case when p_daily_time_ran_out_ms > 0 then to_timestamp(p_daily_time_ran_out_ms / 1000.0) else null end,
    version = public.time_wallets.version + 1,
    updated_at = now();

  select * into v_wallet from public.time_wallets where user_id = v_uid;
  return v_wallet;
end;
$$;
