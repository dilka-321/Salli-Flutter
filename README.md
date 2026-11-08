# Salli — native app (Flutter)

This is the native rebuild of the Salli money manager. It signs in to **the same cloud account** as the Salli web app/APK, so both apps show the same data. Keep using the current Salli app until this one has every section.

## Get the APK (no installation needed)
1. Create a **new** GitHub repository (for example `Salli-Flutter`) and upload everything in this folder.
2. Open the **Actions** tab → **Build Salli native APK**. It runs automatically after each upload (or press *Run workflow*).
3. When it turns green, open the run → **Artifacts** → download **Salli-native-apk** and install it.
   It installs as **"Salli Native"** next to your current Salli app (different app ID: `com.salli.salli_flutter`).

If a build turns red: open the failed step, copy the red error lines (or screenshot them) and send them to Claude to fix.

## Round 3 (this version)
- **Budget tab** (replaces "coming soon"): total budgeted / spent / left with a ring, budget cards with progress (green → orange at 80 % → red), days left. Create / edit (amount, name, daily · weekly · monthly · quarterly · yearly, categories incl. subcategories), budget details with safe daily spend, spending by category and the period's transactions, delete.
- **Subscriptions**: This Month card (paid vs due, monthly total), upcoming payments (60 days), search, All / Active / Overdue. Add / edit (name, amount, currency, category, start, frequency, next date, billed-to account, notes, auto-renew, reminder days). Details with **Pay now**, payment history with **Edit / Delete payment** (deleting the latest payment moves the next date back), Pause / Resume, Delete.
- **Recurring expenses**: list with missed periods, add / edit (amount, name, category, daily · weekly · monthly with day of month · yearly, start, account), details with **Make Payment** and payment history, delete (recorded payments stay in transactions).
- **Installments**: Overview (outstanding, progress ring, upcoming / overdue / active plans, next payment, 30-day commitment), Active / Completed with search, 4-step **New Installment** wizard (advance + account, count, each amount, first due date, already-paid count, pay-from, reminder), plan details with Schedule / Payments, **Make Payment**, delete payment, delete plan.
- Tapping a subscription, recurring or installment payment in any transaction list now opens its plan.
- All of this reads and writes the same data as the web app (same fields and rules), so changes show up in both.
- Not in this round: spending plans / monthly plan (moved to round 4).

## Round 2
- **Transfers** between accounts (incl. credit cards): optional own exchange rate ("1 MVR = 17 LKR", tap to swap) or the amount received; the difference to the app rate is booked as **Exchange Gain / Loss** in the receiving account, exactly like the web app. Fee, date, note. Transfer list with ⋮ Edit / Delete; transfers can also be edited from their transaction.
- **Credit cards**: add / edit (limit, available, billing & due day with grace period, interest, minimum %), card page with available, % used, due date and minimum, monthly transactions, **Pay Now** (Full / Minimum / custom from a wallet).
- **Accounts**: delete (with its transactions, like the web app); currency is locked once an account has transactions.
- **Categories**: income / expense, search, add / edit (name, main category, icon), subcategories, delete (transactions keep their entry; subcategories become main). A **New** category button is also in Add Expense / Income.

## Round 1
- Sign in / create account / forgot password, approval waiting screen, first-time profile details — same accounts and approval process as the web app.
- Works offline: data is saved on the phone first and uploaded when online. If the web app changed the data meanwhile you choose which copy to keep — nothing is overwritten silently.
- Dashboard: Net Cash Flow (Cash In / Cash Out, Income / Expense), My Accounts balance, recent transactions by day.
- Accounts: wallets and credit cards with balances; add/edit wallets (name, currency, balance); transactions per account.
- Transactions: search, month and type filters, details; add / edit / delete income and expenses.
- Light / Dark (true black) / System appearance, your accent colour from the web app, smooth page transitions and haptic feedback.
- Loan, lending and other linked entries are shown but are edited in the web app for now, so their links stay correct. Their main-currency values use each loan's agreed rate, like the web app.

## Next rounds (plan)
4. Spending plans & monthly plan, loans (agreed rates, overdue), lending, fixed deposits, assets, Due Soon, analytics, reports with PDF/Excel export, backup & restore, biometric lock, all settings.

## Safety of your data
The app keeps your cloud data exactly as the web app saved it and only changes the parts it knows about. Every upload sends the whole document back, so nothing the web app stores is lost.
