-- Allow authenticated users to discover other profiles by username search.
-- This is intentionally broad for social discovery UX.
drop policy if exists profiles_discover_all on public.profiles;
create policy profiles_discover_all on public.profiles
for select to authenticated
using (true);
