# Creating the client's first admin

The admin role is `app_metadata.role = "admin"` (kept from your design). `app_metadata`
can only be written with the service-role key, so customers/users cannot give it to themselves.

1. Supabase > Authentication > Providers > Email: **turn OFF "Allow new users to sign up"**
   (extra protection; the role check already blocks non-admins).
2. Supabase > Authentication > Users > **Add user > Create new user**. Enter the client's email and
   a strong password, tick **Auto Confirm User**. Copy the user's **UUID**.
3. On your own computer, in the backend folder, with a `.env` holding that client's
   `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY`:
   `node make-admin.js <the-user-uuid>`
   (Or in the SQL editor: `update auth.users set raw_app_meta_data = coalesce(raw_app_meta_data,'{}'::jsonb) || '{"role":"admin"}' where id = '<uuid>';`)
4. Sign out and in again (the role lives in the login token). Open `/admin.html`.
5. Never paste the service-role key into any HTML/JS file or chat. `.env` is git-ignored.
