update auth.users
set raw_app_meta_data = coalesce
(raw_app_meta_data,'{}'::jsonb) ||
'{"role":"admin"}'
where id =
'paste your uuid';
