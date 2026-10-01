# MoneyMind – Plan Your Money. Track Your Future.

Flutter (Android · iOS · Web · Windows) personal-finance app: salary-cycle budgeting, savings wallet,
lending with monthly interest, reports, calendar, reminders, CSV/PDF export.

Stack: Flutter · GetX · Clean Architecture · Supabase (Postgres + Auth + RLS) · Decimal money math.

> **Status:** written without a Flutter SDK available, so it has **not been compiled or run**.
> Expect to spend a little time on `flutter analyze` fixes (package-version API drift). See "First run" below.

## 1. Set up Supabase
1. Create a project at supabase.com.
2. SQL Editor → paste and run **`supabase/schema.sql`** (tables, RLS, triggers, RPC functions, default categories).
3. Authentication → URL configuration: add your app/web URL as a redirect URL (for password-reset links).
   Optional for testing: Authentication → Providers → Email → disable "Confirm email".
4. Copy the project URL and the **anon (public)** key. Never put a service-role key in the app.

## 2. First run
```bash
cd moneymind
flutter create . --platforms=android,ios,web,windows --project-name moneymind --org com.moneymind
flutter pub get
flutter analyze          # fix any API drift reported here
flutter test             # pure-logic + widget tests

flutter run \
  --dart-define=SUPABASE_URL=https://YOUR-PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR-ANON-KEY \
  --dart-define=DEMO_MODE=true          # optional: shows "Load demo data" in More
```
Requires Flutter 3.24+ (Dart 3.3+).
`flutter create .` keeps the existing `lib/`, `test/` and `pubspec.yaml`; if it overwrites `test/widget_test.dart`, restore ours.

### Android notifications
`flutter_local_notifications` needs core-library desugaring. In `android/app/build.gradle(.kts)`:
```
compileOptions { isCoreLibraryDesugaringEnabled = true }
dependencies { coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4") }
```
and set `minSdk = 21` or higher. Add to `AndroidManifest.xml` if you want exact alarms: `POST_NOTIFICATIONS` (Android 13+).
iOS: no extra steps beyond the permission prompt. Web/Windows: reminders show inside the app (More → Notifications).

## 3. How the money rules work
| Rule | Where enforced |
|---|---|
| Remaining = salary + extra income − **completed** items only | `budget_summaries` view, `BudgetCalculator` |
| Complete/undo never double-counts | `complete_budget_item` / `undo_budget_item` (row lock + status check), unique index on `transactions(ref_type, ref_id)` |
| Cycle can be closed once | `close_budget` (row lock, `ALREADY_CLOSED`), unique index on `savings_transactions(budget_id)` |
| Closed cycles are read-only | trigger `guard_budget_items` |
| Savings ops are atomic & idempotent | `savings_operation` (wallet row lock + idempotency key) |
| Interest payments can't over-pay or double-post | `record_interest_payment` (period row lock, `OVERPAYMENT`, idempotency key generated per form open) |
| Lending is a transfer, not an expense; principal return is not income; interest is income | `create_loan`, `close_loan`, `ReportCalculator` |
| Net cash flow = income + interest − expenses | `ReportCalculator.netFlow` |
| Net worth = available + savings + outstanding principal | `HomeController.netWorth` |

The same rules exist as pure Dart in `lib/domain/services` and are unit-tested in `test/`.

## 4. Project layout
```
lib/core        theme, routes, services (Supabase, notifications, export), utils, error mapping, shared config
lib/domain      entities, repository contracts, pure business logic (services), use cases
lib/data        mappers (JSON ⇄ entity), Supabase datasource, repository implementations
lib/presentation  controllers (GetX), bindings (DI), pages, shared widgets
supabase/       schema.sql
test/           unit + widget tests
```

## 5. Assumptions & limitations (please review)
- **Salary day is 1–28**, avoiding short-month edge cases. Cycle mode: salary cycle or calendar month.
- **Only the current cycle is auto-created.** Past cycles show a "Create budget" button; future cycles can't be created.
  Switching cycle mode/salary day affects new cycles only; a new cycle may overlap an existing one by a few days.
- **Interest periods** run from `start_date + k months`; the period's due date is the last day of the period,
  or the "expected day" you set. A payment can be recorded any time, but only against generated periods
  (no advance payments – server returns `OVERPAYMENT`). "Overdue" is derived on the client (paid → partial → overdue → pending).
- Editing a loan's rate/principal changes **future** months only; past months keep their amounts.
- **Lending does not reduce budget "remaining"** (it is tracked as a transfer). If you lend from this month's salary,
  net worth adds the principal back, so treat lending as coming from money already outside the budget or record it accordingly.
- Completed expenses can't be edited/deleted until you undo them (protects the ledger).
- Savings "adjustment" exists in the RPC but has no UI. No social login (email + password only).
- PDF export uses "Rs" because built-in PDF fonts lack ₹. CSV/PDF save via `file_saver` on every platform.
- Transaction search runs client-side over the loaded (max 1000) rows.
- Currency symbol/grouping: INR uses Indian grouping (₹1,25,000); USD/EUR/GBP use Western grouping.
- `seed_demo_data()` is a dev helper (only visible with `DEMO_MODE=true` or debug builds) and refuses to run if loans exist.

## 6. Security notes
- Only the anon key is shipped; supply it with `--dart-define`. All tables have RLS (`user_id = auth.uid()`).
- All RPCs are `SECURITY INVOKER`, so RLS applies inside them; `auth.uid()` is used for ownership.
- Raw database errors are mapped to friendly messages (`lib/core/error/failure.dart`).
