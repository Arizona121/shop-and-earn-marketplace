# Shop & Earn Marketplace — starter project

This is a first working foundation for a mobile-friendly customer site and protected `/admin` route. It is not yet a complete production-ready rewards/withdrawals system. Read the safety notes before accepting real customers or money.

## Included
- Customer-facing storefront with sample Jumia, Temu, and Selar cards
- Customer registration/login via Supabase Auth
- Product catalogue reading and admin product creation
- Wishlist
- Customer purchase submission history view (submission form still needs completing)
- Wallet balance/history display
- Advertising request form and admin review list
- Admin-only role check in UI plus database row-level security
- SQL function for administrator wallet credits
- Responsive mobile layout

## 1. Create a Supabase project
1. Create a project at https://supabase.com/.
2. Open SQL Editor and run `supabase/schema.sql`.
3. Create a customer account using the app after configuration.
4. In Supabase Authentication > Users, copy your own user UUID.
5. In SQL Editor, run this with your UUID:
   `update public.profiles set role = 'admin' where id = 'YOUR_AUTH_USER_UUID';`
6. Never promote a public/customer account to admin. Do not put a Supabase service-role key in frontend variables.

## 2. Configure locally
1. Install Node.js LTS on your computer.
2. Copy `.env.example` to `.env`.
3. Add your Supabase Project URL and publishable/anon key from Supabase project settings.
4. Optionally set your WhatsApp contact number with country code and community invitation link.
5. Run:
   `npm install`
   `npm run dev`
6. For a production build, run `npm run build`.

## 3. Deploy
- Create a Git repository and upload the project files.
- Import the repository into a host that permits your intended commercial use.
- Add the same `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`, `VITE_WHATSAPP_NUMBER`, and `VITE_WHATSAPP_COMMUNITY_LINK` environment variables in the hosting dashboard.
- Build command: `npm run build`
- Output directory: `dist`
- Configure single-page-app rewrites so `/admin`, `/wallet`, and other app routes serve `index.html`. For Netlify, add a `_redirects` file containing `/* /index.html 200`. For Vercel, use the provided `vercel.json`.
- Configure Supabase Auth site URL and redirect URLs to your deployed domain.
- Review the hosting plan terms and limits for commercial use before launch.

## 4. Two links
After deployment, your customer link is the site root, for example `https://your-site.example/`. Your admin link is `https://your-site.example/admin`. These are routes on one website, not separate hosting accounts. The admin link is not secret security: server-side role checks and database policies protect the actual operations.

## IMPORTANT unfinished items before real launch
- Purchase evidence upload form and private file storage policies
- Withdrawal request UI and secure atomic reserve/release/pay workflow
- Admin screen to list withdrawal requests, mark paid, record date/admin, prevent duplicate payment
- Customer notifications
- Advertiser payment confirmation, ad scheduling/expiry and fair impression rotation
- Product editing/deactivation and category filters
- Support tickets, full activity/audit views, fraud review
- Email verification/password reset flows and account recovery testing
- Rate limits, spam prevention, security review, backups, monitoring, and end-to-end tests
- Confirm each affiliate programme permits cashback/incentive rewards and comply with its terms
- Verify reward funding and cash-flow before promising rewards or withdrawals

The current admin dashboard does NOT yet implement withdrawals or automatically credit a reward when a purchase is verified. This is deliberate: these are money-related operations and must be completed and tested safely before real use. Do not collect real bank account details in this starter.

## Demo-mode warning
If Supabase environment variables are absent, the storefront displays sample products. Those products are examples only, and auth/data-backed features will not work. Do not present demo data as real offers.
