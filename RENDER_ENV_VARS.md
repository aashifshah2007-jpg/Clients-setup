# Render environment variables (exactly what the final code reads)

| Variable | Required | Per-client value |
|---|---|---|
| `SUPABASE_URL` | yes | Client's Supabase Project URL |
| `SUPABASE_SERVICE_ROLE_KEY` | yes | Client's `service_role` key (secret; Render only) |
| `RESEND_API_KEY` | for email | Client's Resend API key. Missing = emails skipped, orders still saved |
| `CLIENT_EMAIL` | for email | Where order alerts go |
| `RESEND_FROM` | optional | Default `BASEIC Store <onboarding@resend.dev>` |
| `FRONTEND_URL` | yes (browsers) | The client's Netlify URL, no trailing slash. Comma-separate for several |
| `PORT` | no | Render sets it |

Resend note: the test sender `onboarding@resend.dev` can only deliver to the email the client used to
register on Resend, so `CLIENT_EMAIL` must be that address. Customer confirmations (and any other
recipient) require a verified domain, which matches the proposal ("once your domain is connected").

Frontend (per client, `js/config.js`, all public): `orders.endpoint` = the Render URL,
`admin.supabaseUrl`, `admin.supabaseAnonKey` (anon/public key only), store name/phone/email, and
replace `assets/images/qr.jpg` with the client's payment QR.

Keep-alive: point your uptime pinger at `https://<render-url>/health` (touches Supabase, so the free
project is not paused; `/` only keeps Render awake).
