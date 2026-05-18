create or replace function public.set_wallet_balance(p_balance_seconds int)
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

  insert into public.time_wallets (user_id, balance_seconds, version, updated_at)
  values (v_uid, greatest(0, p_balance_seconds), 1, now())
  on conflict (user_id) do update set
    balance_seconds = greatest(0, p_balance_seconds),
    version = public.time_wallets.version + 1,
    updated_at = now();

  select * into v_wallet
  from public.time_wallets
  where user_id = v_uid;

  return v_wallet;
end;
$$;
