# Salli — native app (Flutter)

This is the native rebuild of the Salli money manager. It signs in to **the same cloud account** as the Salli web app/APK, so both apps show the same data. Keep using the current Salli app until this one has every section.

## Get the APK (no installation needed)
1. Create a **new** GitHub repository (for example `Salli-Flutter`) and upload everything in this folder.
2. Open the **Actions** tab → **Build Salli native APK**. It runs automatically after each upload (or press *Run workflow*).
3. When it turns green, open the run → **Artifacts** → download **Salli-native-apk** and install it.
   It installs as **"Salli Native"** next to your current Salli app (different app ID: `com.salli.salli_flutter`).

If a build turns red: open the failed step, copy the red error lines (or screenshot them) and send them to Claude to fix.

## 2.0.9 (this version)
- **Agreed exchange rates (loans & lendings):** when the loan / lending isn't in USD, other currencies are entered against USD (e.g. on an LKR loan: "1 USD = x LKR" and "1 USD = x MVR"). The MVR ⇄ LKR rate is worked out automatically from those two (if the USD row is empty, the app's USD rate is used).
- **Lendings — settle against expenses:** now has the same currency button as Cash settle. Changing it converts the amount using the lending's agreed rate first (else the app rate) and shows how much comes off the balance.

## 2.0.8
- **Phone navigation bar:** with the 3-button bar, every page and bottom sheet now stops above the buttons (Quick Save, Save etc. are no longer hidden). With swipe gestures the app stays full screen.
- **Lendings — agreed exchange rates:** New / Edit Lending has "Agreed exchange rates (optional)", same as loans. The amount taken from the account, the balance in other currencies (net worth, overview) and received payments use the agreed rate first; without one the app rate is used. Shown on the lending page as "Agreed rate".
- **Lendings — settle against expenses:** "Receive Payment" now asks how to settle: **Cash settle** (as before) or **Settle against expenses** (e.g. they paid for your food). The lending goes down and the amount is booked as an expense in the chosen category; your account balances don't change. Deleting that payment removes the expense too.

## 2.0.7
- **Side menu:** going back from any section no longer shows the menu moving / half-closing. The menu now closes fully while the section opens.

## 2.0.6
- **Smoother page opening from the side menu:** the page now slides in first and the menu closes behind it (before, both animated at once). Cards no longer fade in one by one while a page opens, which was what made My Accounts, Financial Overview, Categories, Tags, Account Setup, Customize Dashboard and Settings lag. Every page now opens at the same speed as Transfers.

## 2.0.5
- **Faster, smoother page changes:** opening and closing pages now takes 0.3 s (was about 0.45 s) with a lighter slide-and-fade; cards settle in quicker too.

## 2.0.4
- **Add Expense / Income:** fixed the "Select Category" title showing one letter per line; the amount now types cleanly (no doubled / blurry numbers) and only the newest digit glides in.

## 2.0.3
- **Add Expense / Add Income** works like the web app now: **Select Category** (search, Frequently Used, all categories in a grid, subcategory picker, Create) → **Select Account + calculator** (7 8 9 ÷ … C 0 ⌫ + . =) with **Quick Save** or **Add More Details** → **Add Note, Tags, Receipt, or Date** (date & time, spending plan, tags, conversion rate for foreign-currency accounts, note, receipt photo) → **Save**. Editing a saved transaction, SMS drafts and spending-plan "Add transaction" still use the existing form.
- **Lendings:** new **Lending taken date** on New / Edit Lending; the lending and its "lend" transaction use that date.
- **Budget:** removed the empty gap at the top of the page.
- **Smoother animations:** cards ease in and sink slightly when tapped, page changes slide, fade and scale, and the new add flow animates between steps.
- **Phone notifications:** due reminders (loans, lendings, subscriptions, installments, recurring, cards, budgets, to-dos, SMS drafts) now also appear in the phone's notification panel. They're sent when the app opens or comes back, and upcoming dues are scheduled for 9:00 AM on the due day even if the app is closed. Android asks once for permission — tap **Allow**.
- **Build file:** `.github/workflows/build-apk.yml` has a new "Phone notifications support" step — replace it too.

## 2.0.2
- **Transfer money:** From / To account are tappable boxes again (icon, name, currency · balance, ›) with the swap button between them. Tapping opens a "From Account" / "To Account" list of all accounts with balances and a ✓ on the selected one.
- **Home → Spending Trend:** tapping or dragging now glides the cursor line, dots and tooltip smoothly to the new day.
- **Loans → loan page ⋮:** new **Close loan** (Close without paying / Pay and complete from an account) and **Manual override** (Mark as Settled / Reopen with Custom Balance). A closed or settled loan shows PAID, moves to Paid Loans and is removed from liabilities. Saved on the loan as `settled` / `remainAdj` (the web app ignores these fields for now).
- **Account page** (tap an account → Transactions): green header with the balance and the month's In / Out, month chips going back through your history, day groups with in / out totals, an empty state, a + button (Add Expense with this account already chosen) and a ⋮ menu: Edit Account, Create Account, Correct Balance, Set as Default Wallet, Delete Account.

## 2.0.1 — Correction 3
- **Transfers:** typing in "Amount received" or clearing the exchange rate no longer jumps the cursor to the amount box.
- **Account selection everywhere** (lending, add / edit transaction, transfers, card payments, loans, goals, plans…) is now a sideways-scrolling row of account cards with the balance, like the web app.
- **Privacy & lock:** with App Lock on, the app switcher (recents) shows the Salli cover instead of your details. When the lock time has passed, reopening shows the Salli lock screen with fingerprint / face unlock (or PIN) **above the page you were on** — after unlocking you're back exactly where you stopped.
- **Keyboard fix:** after the keyboard closes the page is redrawn, so no part of the screen stays blank.
- **Back button on Home** asks "Exit App? Do you really want to exit the app?" (other tabs go back to Home first).
- **Home:** account tiles scroll sideways under My Accounts (tap to open the account), "Credit cards available" line; **Spending Trend** is now a line chart (Income, Expense, Cash In, Cash Out) with touch / drag tooltips and Monthly / Weekly; **Monthly Budgeting** cards.
- **Financial Overview:** Share button opens the phone's share menu.
- **Loan Analyzer** rebuilt: 3 steps (Loan Basics with loan type & typical rates, term in months or years, interest rate **or** monthly installment; Your Finances; Review & Analyze with processing fees) → **Loan Analysis** (status, EMI, end date, principal vs interest, Why? risk factors, total payment / interest, income breakdown, insights; Analysis tab with yearly → monthly amortization schedule and extra-payment savings) and **Compare Loans** (Loan A vs Loan B side by side).

## Round 7 (all sections native)
- **Reports → Share**: download or share the report as a **PDF** or an **Excel (.xlsx)** file (Save to phone or Share to Gmail / Drive / WhatsApp). Bank statements are included when switched on in Export settings.
- **Backup & Restore**: Backup Now (save to phone or share), Restore Data from a backup file (same file format as the web app — backups move between both apps), Export all transactions to Excel, **Automatic backup** (daily / weekly / monthly copy kept on the phone) and **Also send to Gmail** (when due, Salli opens the share menu with the backup attached).
- **App Lock**: 4-digit PIN (the same PIN works in the web app) and **Biometric Unlock** (fingerprint / face). Locks again after a minute in the background. "Forgot PIN?" turns the lock off after you enter your account password.
- **Settings**: profile (saved to your account), Light / Dark / System, **accent colour**, **font size**, **Currency Settings** (functional currency, my currencies), **Exchange Rates** (manual rates, reference rates, update from the internet), **Notification Settings**, cloud sync, sign out, Erase Data.
- **Notifications** bell on Home: bills & due dates, budget alerts, subscriptions, installments, loans, cards, lendings, to-dos, recurring and SMS drafts.
- **SMS Automation / SMS Parser / SMS Drafts**: paste bank messages; OTPs and promotions are skipped, account numbers masked; review each draft or Save all.
- **Admin approvals** (admins only): approve, reject or suspend registrations.
- Not included: the language switch (the native app is English for now).

**Build file update (needed once for fingerprint unlock):** replace the content of `.github/workflows/build-apk.yml` on GitHub with the new `build-apk.yml` (adds the fingerprint permission). Without it the app still builds and the PIN lock works; only fingerprint unlock is unavailable.

## Round 6
- **Analytics tab**: General (10 spending highlights, daily income / expense bars, spending by account, category donut with drill-down), Expense Category and Income Category grids, last-12-month chips and a custom date range.
- **Reports tab**: History of generated reports and the generator (This Month, Last Month, Last 3 / 6 / 12 Months, custom range). Report preview with the web report's sections: summary, Financial Health Score with breakdown and recommendations, Net Worth Statement, Cash Flow, Spending Analysis (category bar, day-of-week, transaction sizes), Budget Performance, Debt & Liabilities, Expense Prediction, Behavioral Insights, Top Transactions, Transaction List and Bank Statements — toggled in Export settings (shared with the web app). Copy summary to share. *(PDF / Excel files come in round 7.)*
- **Customize Dashboard**: drag to reorder and switch Home widgets on / off (Due Soon, Balance Overview, My Accounts, Fixed Deposits, Recent Transactions, Spending Trend, Budget Progress, Upcoming Subscriptions, Installment Overview, Loan Overview, Expense Summary, Standing Orders) — same layout setting as the web app.
- **Goals**: active / completed, new / edit (target, date, already saved, icon), goal page with ring, remaining, needed per month, **Add Money / Withdraw** (optionally from / to an account), mark completed, delete.
- **To-Do List** and **Priority Board** (importance × urgency: Do first / Schedule / Delegate / Later, category, reasons, estimated cost in any currency).
- **Tags**: add / rename (renames on every transaction) / delete; tag chips in Add / Edit transaction.
- **Account Setup**: asset & liability groups (name, Assets / Liabilities, balance-sheet type), used by My Assets and the Financial Overview.

## Round 5
- **Loans**: Unpaid / Paid tabs, All / Bank / Personal filter, OVERDUE badges. Add / edit (bank or personal, lender, currency — locked after payments, amount, interest, tenure, first instalment, **agreed exchange rates** per currency with ⇄ swap, optional "money received into" account). Loan page with remaining balance (and main-currency value at the agreed rate), % repaid, EMI, loan information, upcoming schedule with interest / principal, **Pay now** (red **PAY NOW - OVERDUE** when late) in any currency with bank fee, payment history with **Edit / Delete payment**, edit / delete loan (removes its transactions like the web app).
- **Loan Analyzer**: EMI, total interest / payable, principal vs interest bar, EMI-to-income check, extra monthly payment savings, yearly breakdown.
- **Lendings**: Outstanding / Received, new / edit lending (currency, paid-from account with conversion), lending page with totals, progress, information, **Receive Payment** in any currency, payment history (edit / delete), timeline, delete.
- **My Assets & Fixed Deposits**: assets by type, add / edit / delete; FDs with currency, rate (yearly / monthly), term, monthly or at-maturity interest into an account — interest is posted automatically on each date (shared "posted" list with the web app, so nothing is added twice).
- **Financial Overview**: net worth, health badge, assets / liabilities with change vs last month, balance sheet groups, assets-vs-liabilities ring, insights, copy summary.
- **Due Soon** card on the Home screen (overdue or due within 7 days: loans, lendings, subscriptions, recurring, installments) — tap to open, ✕ to dismiss (shared with the web app).
- Loan and lending transactions in any list now open their loan / lending.

## Round 4
- **Side menu** (☰ on the Home screen, or swipe from the left edge): profile header, SMS Automation card and the same sections as the web app — Finance, Planning, Loans & Assets, Productivity, Settings (and Administration for admins). Sections that are not rebuilt yet are marked "soon".
- **Subscriptions, Recurring Expenses and Installments moved to the side menu**; the Budget tab now shows budgets only.
- **Monthly Plan**: intro (with "Don't show this again"), plan list with on-track / over-plan progress, create / edit (name, month, income in any currency, Monthly Expenses by category, Loan Payments, Credit Card Payments, Saving Goals — each amount in any currency), remaining amount with hide/show, "Create Monthly Budgets?" for new plans, plan details with donut chart and per-category spending, Monthly Overview (planned vs actual), delete.
- **Spending Plan**: list with progress and Safe / Warning / Over, create / edit (name, description, start / end date, budget limit, planned expenses), details with remaining balance, limit / planned / unplanned / spent, mood card, by-category progress, transactions + planned items with sort / show / category filters, **Add Transaction** (linked to the plan) and **Add Planned Expense**, delete (transactions are unlinked, not deleted).
- Add / edit expense now has a **Spending plan** selector, like the web app.
- **OT & Salary**: Overview (days logged, worked days, OT hours, today, missing days, day breakdown, hours), Daily Log, Pay Preview (earnings, OT pay, no-pay, EPF, deductions, net), Setup (basic, OT rate, working days, standard hours, Auto-OT, EPF / ETF, allowances with EPF-eligible, deductions), add / edit / delete day entries.
- Credit Cards list page (from the side menu).

## Round 3
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

## Next
Every section of the web app now has a native screen. Report anything missing or different and it will be corrected.

## Safety of your data
The app keeps your cloud data exactly as the web app saved it and only changes the parts it knows about. Every upload sends the whole document back, so nothing the web app stores is lost.
