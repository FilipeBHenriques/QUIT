create or replace function public.search_profiles(p_query text, p_limit int default 8)
returns table (
  id uuid,
  username text,
  avatar_url text
)
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

  return query
  select p.id, p.username, p.avatar_url
  from public.profiles p
  where p.id <> v_uid
    and p.username ilike ('%' || trim(p_query) || '%')
  order by p.username asc
  limit greatest(1, least(coalesce(p_limit, 8), 25));
end;
$$;
