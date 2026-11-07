-- Run once in the Supabase SQL editor as the project owner. See README first.
begin;

create table if not exists public.bins (
    id text primary key,
    name text,
    category text,
    contents text,
    updated_at timestamptz
);
create table if not exists public.settings (
    id integer primary key,
    total_bins integer,
    bins_per_shelf integer
);

lock table public.bins, public.settings in access exclusive mode;

-- Refuse to guess how to migrate an already modified schema.
do $$
declare
    r record;
begin
    if exists (
        select 1 from information_schema.columns
        where table_schema = 'public'
          and table_name in ('bins', 'settings') and column_name = 'user_id'
    ) then
        raise exception 'user_id already exists; inspect the schema before migrating';
    end if;

    for r in
        select conrelid::regclass as table_name, conname
        from pg_constraint
        where conrelid in ('public.bins'::regclass, 'public.settings'::regclass)
          and contype = 'p'
    loop
        execute format('alter table %s drop constraint %I', r.table_name, r.conname);
    end loop;

    if exists (
        select 1 from pg_index
        where indrelid in ('public.bins'::regclass, 'public.settings'::regclass)
          and indisunique
    ) then
        raise exception 'Unexpected unique constraint or index; inspect and remove it before migrating';
    end if;
end $$;

alter table public.bins
    add column user_id uuid references auth.users(id);
alter table public.settings
    add column user_id uuid references auth.users(id);
alter table public.bins alter column user_id set default auth.uid();
alter table public.settings alter column user_id set default auth.uid();

-- NULL ownership preserves legacy rows but makes them inaccessible through RLS.
alter table public.bins alter column id set not null;
alter table public.settings alter column id set not null;
alter table public.bins add constraint bins_user_id_id_key unique (user_id, id);
alter table public.settings add constraint settings_user_id_key unique (user_id);

alter table public.bins enable row level security;
alter table public.settings enable row level security;

-- Remove old permissive policies so they cannot bypass these policies.
do $$
declare
    r record;
begin
    for r in
        select schemaname, tablename, policyname from pg_policies
        where schemaname = 'public' and tablename in ('bins', 'settings')
    loop
        execute format('drop policy %I on %I.%I', r.policyname, r.schemaname, r.tablename);
    end loop;
end $$;

revoke all on public.bins, public.settings from public, anon, authenticated;
grant select, insert, update on public.bins, public.settings to authenticated;

create policy bins_select_own on public.bins for select to authenticated
    using ((select auth.uid()) = user_id);
create policy bins_insert_own on public.bins for insert to authenticated
    with check ((select auth.uid()) = user_id);
create policy bins_update_own on public.bins for update to authenticated
    using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

create policy settings_select_own on public.settings for select to authenticated
    using ((select auth.uid()) = user_id);
create policy settings_insert_own on public.settings for insert to authenticated
    with check ((select auth.uid()) = user_id);
create policy settings_update_own on public.settings for update to authenticated
    using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

commit;
