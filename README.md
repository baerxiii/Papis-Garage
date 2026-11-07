# Papi's Bin Finder

Inventories and shelf settings belong to individual accounts. People who need to
use Dad's inventory should sign in to that **same account**. A QR code contains
only a bin ID and the app URL, not an account or access token: after signing in,
it opens that ID in the signed-in account's inventory, not necessarily Dad's.

## Setup and migration

**The client alone does not secure the database.** Existing data remains exposed
until the SQL migration below is successfully applied and verified. Do not
deploy the new client before the database is migrated and legacy data claimed.

1. Back up/export both `public.bins` and `public.settings` in Supabase. Stop
   using the old app during migration and claim; it cannot work with the new
   policies. Review existing access, including custom roles, views, functions
   and triggers, which this setup does not audit.
2. In Supabase Auth, enable email/password sign-in. Configure the site URL and
   allowed redirect URLs for your deployed app, and email delivery/confirmation
   as appropriate. Create Dad's account in Authentication > Users before
   migrating. If email confirmation is enabled, confirm the email before signing
   in. Copy Dad's UUID from Authentication > Users; verify it belongs to the
   intended account.
3. Run `supabase-setup.sql` in the Supabase SQL Editor as the project owner. It
   creates missing tables or migrates the existing tables in one transaction,
   replaces existing policies, enables RLS, and removes `anon`/public table
   access. Existing rows get a **NULL** owner and are invisible to app users
   until claimed. The script expects the existing columns described by the app;
   extra constraints, unique indexes, foreign-key dependencies, or an existing
   `user_id` can cause it to abort and roll back. If it fails, inspect the schema
   and dependencies, adapt the migration deliberately, and rerun only after
   checking the rollback. Do not drop constraints blindly.
4. Before Dad saves any bins or settings in the new app, claim the legacy rows
   in the SQL Editor using the block below. Replace the UUID with Dad's verified
   UUID. It refuses to merge into an already populated account, or to guess
   which settings row to use. It claims **all** unowned rows; inspect them first
   if the legacy tables contain data belonging to anyone else. If there are
   multiple settings rows or duplicate bin IDs, resolve them from the backup
   deliberately before claiming. Never run this with an unverified UUID.

   ```sql
   begin;
   lock table public.bins, public.settings in access exclusive mode;
   do $$
   declare
       dad uuid := '00000000-0000-0000-0000-000000000000'; -- replace
   begin
       if not exists (select 1 from auth.users where id = dad) then
           raise exception 'Account UUID not found';
       end if;
       if exists (select 1 from public.bins where user_id = dad)
          or exists (select 1 from public.settings where user_id = dad) then
           raise exception 'Account already has data; resolve the merge manually';
       end if;
       if (select count(*) from public.settings where user_id is null) > 1
          or exists (select 1 from public.bins where user_id is null
                     group by id having count(*) > 1) then
           raise exception 'Ambiguous legacy rows; resolve them manually';
       end if;
       update public.bins set user_id = dad where user_id is null;
       update public.settings set user_id = dad where user_id is null;
   end $$;
   commit;
   ```

5. In Table Editor, verify both tables have RLS enabled, the ownership policies
   are present, and the expected legacy rows have Dad's UUID. Test with two
   separate accounts: each can save `BIN01` and a layout without seeing or
   changing the other's data; anonymous and cross-account API requests must be
   denied. SQL Editor/project-owner and service-role access bypass RLS; keep
   those credentials private. A policy or schema change can undo this isolation.
6. Configure `SUPABASE_URL` and `SUPABASE_KEY` near the top of the inline script
   in `index.html` using your project URL and **publishable** (or legacy anon)
   key from Supabase. These values are public in the browser; never put a
   service-role or secret key there. Deploy the static files to your HTTPS
   host (or serve locally for testing), then sign in. The app restores sessions
   on reload and asks for sign-in again when they expire.

The existing “Print All Labels” feature requests QR images from
`api.qrserver.com`, which receives the app URL and bin ID, but not inventory
contents or credentials.