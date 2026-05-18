create or replace function public.decline_time_request(p_request_transfer_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_req public.time_transfers%rowtype;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  select * into v_req
  from public.time_transfers
  where id = p_request_transfer_id
  for update;

  if v_req.id is null then
    raise exception 'request not found';
  end if;

  if v_req.receiver_id <> v_uid then
    raise exception 'not request target';
  end if;

  if v_req.type <> 'request' or v_req.status <> 'pending' then
    raise exception 'request not pending';
  end if;

  update public.time_transfers
  set status = 'declined', updated_at = now()
  where id = p_request_transfer_id;
end;
$$;

create or replace function public.cancel_time_request(p_request_transfer_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_req public.time_transfers%rowtype;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  select * into v_req
  from public.time_transfers
  where id = p_request_transfer_id
  for update;

  if v_req.id is null then
    raise exception 'request not found';
  end if;

  if v_req.sender_id <> v_uid then
    raise exception 'not request sender';
  end if;

  if v_req.type <> 'request' or v_req.status <> 'pending' then
    raise exception 'request not pending';
  end if;

  update public.time_transfers
  set status = 'canceled', updated_at = now()
  where id = p_request_transfer_id;
end;
$$;
