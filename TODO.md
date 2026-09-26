# Personal Finance Tracker — Build Plan

## Current Architecture (post-cleanup, 2026-09-26)

- **Flutter app** (`lib/`) — primary client, offline-first. Local SQLite mirror synced with Supabase via outbox + watermark-based incremental pulls. All CRUD (categories, transactions, budgets, recurring) handled client-side.
- **Supabase** — single source of truth (Postgres). RLS-enabled, publishable-key access from Flutter.
- **Bottom nav:** Home · Activity · Budgets · Recurring · Categories (5 tabs, no "More" sheet).

Removed during cleanup: React/Vite client (`client/`), all CRUD/analytics FastAPI routers, OCR pipeline, STT endpoint, root `package.json`, `pillow`/`pytesseract` deps, Agent Assistant feature (screen + chat_messages table + agentBaseUrl config), Shopping feature (screen + models + repo methods + sync tables + DB tables).

---

## Historical Log

Stack: **React + Vite** (client) · **FastAPI / Python** (server) · **SQLite** (db) → migrated to Flutter + Supabase.
Scope: local single-user, single currency. Amounts stored as integer cents.

Phase 1 = working web app with all features (NO agent). Phase 2 = agentX integration
(chat / voice / images / OCR → creates finance records via API).

Legend: [ ] todo · [x] done · [~] in progress

## Phase 1 — Core web app

### Backend
- [x] Scaffold monorepo (backend/ + client/) with .venv, .gitignore
- [x] Design & create SQLite schema (categories, transactions, budgets)
- [x] FastAPI REST API: categories CRUD
- [x] FastAPI REST API: transactions CRUD + filters
- [x] FastAPI REST API: budgets CRUD
- [x] FastAPI REST API: recurring expenses CRUD + next-due calc + post-now
- [x] FastAPI REST API: shopping lists/items CRUD
- [x] FastAPI REST API: bulk transaction import (/transactions/import)
- [x] FastAPI REST API: summary/analytics endpoints (daily/monthly/yearly)
- [x] Seed default categories + sample data script (python -m backend.seed --sample)
- [x] Migrate Node/Express backend → Python/FastAPI (stdlib sqlite3); old server/ removed
      - [x] Ported dates/recurring/errors helpers; verified next_occurrence == JS across 8 edge cases
      - [x] Smoke-tested every endpoint against the real DB (data carried over intact)
      - [x] Playwright E2E green against the new backend (all 17 checks, no console errors)

### Frontend
- [x] App shell, routing, layout, theme
- [x] Dashboard (today / this month / this year totals + budget health)
- [x] Transactions page (list, filter by date/category/type, search)
- [x] Add/Edit transaction form (modal or route)
- [x] Categories management page
- [x] Budgets page (set monthly limits per category, progress bars)
- [x] Recurring expenses page (list, add/edit modal, upcoming-dues strip, post-now)
- [x] Shopping lists page (master-detail, checkable items, qty/prices, est. totals)
- [x] Reports/charts (daily, monthly, yearly breakdowns)
- [x] Dark mode (class-based, light/dark/system toggle + persistence, full component audit)
- [x] CSV export/import (export filtered rows; bulk import with per-row validation)
- [x] Wire API client layer + error/loading states

### QA
- [x] End-to-end test: run server+client, verify all features in browser
- [x] Write README with setup/run instructions

## Phase 2 — AgentX integration (later)
- [x] Unify backend stack: moved OCR pipeline into backend/, grouped agent CLIs under agent/,
      test-fixture gen under scripts/; removed the sys.path hack in app.py. Root now has no stray .py.
- [~] Image/OCR ingestion endpoint (receipt photo → structured fields)
      - [x] backend/ocr.py — Tesseract extract_text w/ grayscale+upscale preprocessing
      - [x] backend/receipt_parser.py — qwen3 OCR-text → strict JSON schema (+ to_import_row mapper)
      - [x] Merged into main FastAPI app: backend/routers_ocr.py POST /api/ocr/receipt (threadpool-wrapped)
      - [x] scripts/make_test_receipt.py + test_receipt.png synthetic fixture
      - [x] Verified end-to-end on the merged server (:3001): merchant/date/total/line items all correct
       - [x] Wire into JS app (upload UI + preview + confirm) — folded into the Assistant page as a
             composer panel (camera button), separate /scan route retired. Playwright-verified.
      - [x] Scanned receipts tagged source='receipt' (was defaulting to 'manual') so they're distinguishable
      - [x] Accuracy hardening: anti-fabrication prompt (no invented subtotal/tax, no UPC-as-price)
            + deterministic _sanity_check_line_prices guard (nulls line prices outside 0.6–1.3× total band)
            + low/medium-confidence warning banner in the confirm UI. Tested on real Walmart receipt
              (barcode-only item lines → bogus $ cleared/confidence lowered) and Green Valley fixture
              (legit prices preserved, high confidence).
       - [x] Regression-checked: full e2e.mjs suite (17 checks) + focused Assistant-page scan Playwright pass, zero errors
- [ ] Expose an agent-friendly API surface (create record from parsed receipt)
- [x] Voice input path — local dictation via faster-whisper (base.en, fully offline):
      backend/stt.py + POST /api/stt/transcribe; mic button in the Assistant composer records with
      MediaRecorder (webm/opus), transcribes locally, and appends the transcript to the message box.
      Ollama can't run Whisper (no first-party ASR model), so STT lives in our own backend. Playwright-verified.
- [x] Chat interface wired to the PydanticAI agent's finance tools — /assistant page (multi-turn, tool-call chips)
- [x] Assistant chat history persisted in SQLite (chat_messages table; /api/chat endpoints) so it survives
      reloads and works across browsers/devices on this machine. Receipt cards rehydrated from stored JSON.
      "Started <date time>" header above the thread, per-message timestamps, and a Clear-chat button.
      Playwright-verified (persists across reload, clear wipes DB).
- [ ] Confirmation UX before committing agent-created records

## Phase 3 — Cross-platform (Flutter + Supabase)  · plan: docs/architecture-plan.md
Goal: one Flutter codebase (Android + Linux desktop) sharing a single Supabase Postgres
source of truth; offline-capable on-device AI assistant on the phone. React client becomes
throwaway prototype. FastAPI shrinks to Ollama-8B agent + OCR only.

### Phase 0 — Data spine (foundation)
- [x] Architecture plan written & decisions locked (docs/architecture-plan.md)
- [x] Postgres DDL translated from SQLite schema (supabase/migrations/0001_initial_schema.sql)
      - validated against a throwaway postgres:16 container: all 7 tables, indexes, and the
        updated_at touch-trigger apply cleanly; case-insensitive unique name + FK cascade verified
      - NOTE: SQLite's `COLLATE NOCASE` has no Postgres equivalent → replaced with a
        lowercased unique index (uq_categories_name_ci)
- [x] RLS policies draft (supabase/migrations/0002_rls_policies.sql) — enable RLS on all 7
      tables, broad access for `authenticated`. Applies on real Supabase (role exists there);
      expected to error on vanilla Postgres only due to missing `authenticated` role.
- [x] Create Supabase project (effnfuwgjupfigckapst); run both migrations in SQL editor — 7 tables + RLS applied cleanly
- [x] Captured anon + service-role keys into .env (anon verified working via PostgREST). SERVICE KEY WAS EXPOSED IN CHAT —
      rotate when convenient: Settings→API→Reset key, then update .env.
- [ ] Decide auth method (magic-link vs app-PIN JWT) and wire login into Flutter later
- [x] One-time migration script: scripts/migrate_sqlite_to_supabase.py — copies all 7 tables preserving ids/FKs via
      PostgREST + service_role key (no raw DB password needed), idempotent (skips existing ids), booleans 0/1→true/false.
- [x] Changed id columns GENERATED ALWAYS → BY DEFAULT AS IDENTITY (supabase/migrations/0003_identity_by_default.sql) so
      explicit-id inserts work; applied to live DB. Syntax validated against throwaway postgres:16.
- [x] Ran migration against the REAL Supabase DB: 52 rows copied (14 cat / 9 tx / 3 recurring / 1 list / 1 item / 24 chat).
      Verified live: counts match, zero dangling FKs, values correct, booleans converted. Phase 0 COMPLETE.

### Phase 1 — Point FastAPI at Supabase Postgres  · DONE
Approach: keep the single `db_conn()` seam, swap its engine from sqlite3 → psycopg3.
Every router + agent tool + OCR persistence now hits ONE shared Postgres DB. No split-brain;
React app keeps working as a fallback client.
- [x] backend/db.py rewritten as a thin psycopg3 adapter exposing the old sqlite3 surface
      (`execute().fetchall()`, `.lastrowid`, `.commit()`, dict rows). Normalizes `?`→`%s` and
      `:name`→`%(name)s`; auto-appends `RETURNING id` to bare INSERTs so lastrowid works.
- [x] Coerce Postgres-native types back to SQLite-era shapes on read: date→"YYYY-MM-DD",
      datetime→ISO string, Decimal→int/float. Whole codebase + clients behave unchanged.
- [x] deps.py re-exports db_conn; app.py startup = lightweight `SELECT 1` (no init_schema);
      seed.py switched to ON CONFLICT DO NOTHING.
- [x] SQL dialect translations across routers + agent_tools: COLLATE NOCASE→lower(),
      strftime('%Y-%m')→to_char(date::date,'YYYY-MM'), datetime('now')→now().
- [x] Boolean fix: budgets.active / recurring.active / shopping.done written as real booleans
      (was int 0/1); WHERE b.active=1 → active=true.
- [x] Sequence desync fix: migration preserved explicit ids but left identity sequences behind
      → new inserts collided on PK. supabase/migrations/0004_sync_sequences.sql advances each
      seq to max(id); applied live + documented in migrate script docstring.
- [x] Ambiguous-column fix: transactions↔categories join exposed unqualified `type`/`date`
      (both tables have them) → qualified with t. in routers_transactions filter builder.
- [x] Mixed-placeholder fix: search_transactions + report_top_merchants mixed :name and ? in
      one query → normalized to all-positional ?.
- [x] parse_date now accepts datetime.date objects (Postgres) not just ISO strings.
- [x] .env loading wired into db.py (python-dotenv) so SUPABASE_DB_URL resolves however launched.
- [x] VERIFIED end-to-end vs live Supabase: 13/13 endpoints pass (CRUD reads/writes/joins/
      aggregates/date-bucketing/filters), create→read→delete round-trip clean, boolean write
      cycles correct, dates serialize as ISO strings, agent answers finance Q&A against shared
      DB (spend summary + recurring list both correct). Phase 1 COMPLETE.
- [~] Auth decision (magic-link vs app-PIN JWT) still open — needed before Flutter login wiring.

### Phase 2 — Flutter scaffold (android + linux targets)  · DONE
- [x] flutter create app --org com.thaura --platforms android,linux --project-name agentx_app (42 files)
- [x] pubspec deps: supabase_flutter ^2.9.0, intl ^0.20.2, http ^1.2.2 (pub get resolves 53 pkgs)
- [x] lib/config.dart — supabaseUrl + anonKey + AGENT_BASE_URL (--dart-define override, default :3999)
- [x] lib/models/models.dart — typed row models for all 6 tables, schema-aligned w/ live Postgres
- [x] lib/utils/format.dart (money/date), lib/utils/recurring.dart (Dart port of next_occurrence/days_until)
- [x] lib/data/repo.dart — FinanceRepo wrapping Supabase queries (categories/transactions/budgets/
      recurring/shopping/totals + insert/delete/toggle). Conditional filters via .or() string form.
- [x] lib/widgets/state_views.dart — LoadingView / EmptyView / ErrorView
- [x] lib/main.dart — Supabase.initialize, Material 3 light+dark themes, Shell w/ 7-tab BottomNav
- [x] Screens built: Dashboard, Transactions (search/filter/swipe-delete/add sheet), Budgets,
      Recurring (next-due calc), Shopping (master-detail checklist), Categories, Assistant
      (HTTP chat → FastAPI /api/agent/chat, suggestion chips, typing bubble, clear)
- [x] flutter analyze clean (0 errors, 2 pre-existing info lints re: deprecated anonKey param name)
- [x] Anon RLS grant applied (supabase/migrations/0005_anon_access.sql, plain-DDL form after the
      SQL editor mangled the PL/pgSQL do-block). VERIFIED via PostgREST with anon key: 14 categories,
      transactions w/ category join, insert→delete probe (id 26, http 204). Zero-login data access works.
- [x] Milestone gate: "CRUD anywhere, same data, agent works" — VERIFIED on Android emulator (emulator-5554):
      - Dashboard: live Supabase data (Income $50, Spent $577.03, Net -$527.03, daily chart, category pie)
      - Activity: all transactions with search, filter chips, category icons, amounts, dates
      - Budgets: empty state + "+ New" FAB (no budgets set yet)
      - Recurring: Rent ($200/Monthly/Housing/Due in 18d) + Internet ($60/Monthly/Utilities/Due in 14d)
      - Shopping: lists (ssfj, jj, gvw2, Errands) with item counts, add-item field, edit/delete, "New list" FAB
      - Categories: all 10+ categories with type labels, colored dots, All/Expense/Income filter tabs, "+ New" FAB
      - Agent backend: two consecutive /api/agent/chat requests succeed (recurring list + monthly spend $577.03)
      - Fixed: "Event loop is closed" bug (fresh Agent per request in agent.py), recreated missing dates.py module

### Phase 3 — Offline sync  · DONE
- [x] Offline cache + mutation queue + conflict reconciliation (last-write-wins by updated_at)
      - lib/data/local_store.dart — SQLite mirror of all 4 tables + outbox + sync_watermarks
      - lib/data/sync_engine.dart — push outbox → pull remote (incremental via watermark)
      - lib/data/sync_merge.dart — last-write-wins merge on updated_at
      - lib/data/sync_plan.dart — pull filter logic (full vs incremental)
      - lib/data/repo.dart — all writes stamp updated_at + append to outbox
      - main.dart — connectivity watcher re-triggers sync on reconnect
      - VERIFIED on Android device: data syncs from Supabase, offline-capable

### Phase 4 — Agent tool layer in Dart
- [ ] Port agent_tools.py (~19 tools) → Dart, operating on local cache
- [ ] Decompose deterministic logic (recurring-date math, budget rollups, receipt mapping)
      into non-LLM Dart functions to lower the viable on-device model size

### Phase 5 — On-device LLM (phone, offline)
- [ ] Spike feasibility on target phone hardware FIRST (RAM/speed/reliability)
- [ ] Integrate MediaPipe LLM Inference API or llama.cpp via FFI
- [ ] Tool protocol + constrained decoding / retries for reliable function calls
