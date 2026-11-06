# Onboarding a new client (about 30 minutes)

1. Client creates Supabase + Resend accounts and invites you (or shares keys safely).
2. Supabase > SQL Editor: run `sql/01_fresh_install.sql`.
3. Edit `products_template.csv` to the client's catalogue. Table Editor > products > Import CSV.
   **`id`, `name`, `price` must match the storefront `js/products.js` exactly**: the backend charges the
   database price and rejects any id that is missing or `active=false`.
4. Create the admin user (see `ADMIN_ACCOUNT_SETUP.md`).
5. Resend: create API key. Note the account email.
6. Render: new Web Service from the backend repo; `npm install` / `npm start`; set the env vars from `RENDER_ENV_VARS.md`.
7. Frontend copy: edit `js/config.js` (name, phone, email, Render URL, Supabase URL + anon key), `js/products.js`, images, `assets/images/qr.jpg`, about/contact copy in `index.html`, colours in `css/variables.css`.
8. Netlify: deploy the frontend; put its URL into Render `FRONTEND_URL`; redeploy Render.
9. Test: COD order, bank order with screenshot, check the client's inbox, log in at `/admin.html`, verify payment, mark Completed, confirm revenue moves.
10. Add the `/health` pinger. Hand over.
