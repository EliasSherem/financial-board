# Explicit legacy investment-account repair

## Evidence and behavior

`server/routes.ts::ensureInvestmentAccountSchema` combined DDL and account backfill on first accounts/investments/contribution request. The production `LEGACY_SCHEMA_BOOTSTRAP` guard now stops both. Migration 000 supplies columns/constraints, but does not create financial records. Legacy investments with `account_id IS NULL` remain visible in GET investments; GET accounts excludes their investment join, and the contribution endpoint writes a contribution without updating an account balance. The explicit repair is therefore a backend rollout prerequisite before financial writes resume.

`scripts/backfill-investment-accounts.ts` never runs at boot, loads `.env`, adds schema, publishes, or contacts providers. CLI targets must be loopback and database `_test`, `_local` or `_staging`; `MYSQL_URL` and `NODE_ENV=production` are rejected. Default mode makes a read-only preflight transaction. Output is aggregate counts/reason codes and a plan SHA-256, without names, emails or amounts.

Apply creates an account only for a still-NULL investment link. Balance preserves the legacy rule **principal + all recorded contributions**, calculated with integer cents without floating-point rounding. It retains investment ID, principal, rate, start date and `updated_at`, every contribution ID/amount/date, existing linked account balances, transactions and balance history. It does not invent historical snapshots or transactions. Creating the account and setting its link share one transaction, with rollback on any failure and idempotent repeat runs.

Repair refuses ambiguity: an unlinked Investment account already exists for that user; contribution ownership differs; a name exceeds the account column's real limit; balance overflows DECIMAL(15,2); or an existing link has missing/wrong-owner/wrong-type account. It never guesses associations from names/balances, truncates names, resets a linked balance, or deletes a record. Blocked cases require an independent reviewed mapping. `--user-id=N` can scope an unambiguous user; batch limit is 1,000 missing links.

An account-insert outbox event is marked `source=migration,status=processed` in the repair transaction. It is provenance for backfill, not user activity/DAU. Momentum can subsequently recognize actual finite configuration facts; no evaluator runs during repair.

## Operator procedure

1. Back up a local/staging copy and apply reviewed baseline/platform migrations. Stop API financial writers, salary jobs and Momentum workers, and drain in-flight requests. This is required: the audited legacy contribution handler read the link before its write, so an older in-flight request could already have cached NULL. The upgraded route uses a transaction with a row lock; the maintenance requirement still covers older API instances and in-flight work during rollout.
2. Set explicit `MYSQL_HOST=127.0.0.1`, target port/user/password/database ending `_staging` (or `_test`/`_local`), and unset `MYSQL_URL`. Use secret management, not credentials in shell history. `node --import tsx scripts/backfill-investment-accounts.ts --help` does not connect.
3. From `financial-dashboard`, run `node --import tsx scripts/backfill-investment-accounts.ts`, optionally `--user-id=N`. Review candidate, blocked and invalid-link counts. Resolve ambiguous cases separately; there is no automatic reassociation.
4. With writers stopped, set `INVESTMENT_BACKFILL_MAINTENANCE_CONFIRMED=true`. Run `node --import tsx scripts/backfill-investment-accounts.ts --apply --expect-plan=THE_REVIEWED_64_CHARACTER_HASH` with the same scope. Any changed plan or blocked case aborts the full batch. Maintenance is an explicit operator assertion: the script cannot prove every external writer is paused.
5. Repeat preflight: repaired candidates are zero. Through an authorized reviewer, compare repaired raw account balances to exact principal+contributions and confirm existing balances/records unchanged. Exercise GET accounts/investments, one direct contribution and one transaction-linked contribution on synthetic staging data. Resume writers only after validation.

Production is deliberately unsupported by this CLI. Production rollout requires a separately approved maintenance operation adapting the reviewed algorithm to the actual operator-controlled migration channel. Do not bypass guards with a tunnel or rename production to impersonate staging. No actual user investment data or production database was repaired during implementation.

Rollback before commit is automatic. After commit, do not blindly delete a created account: user transactions/history may depend on it once writers resume. Use a reviewed backup/compensating operation preserving records and repair provenance.

## Validation

`investment_backfill.test.ts`: target guards, negatives, exact 10.10+0.20 and maximum decimal precision. `investment_backfill_sql.test.ts`: isolated synthetic MySQL fixtures, read-only default, injected failure after INSERT rolls back account and outbox, exact 10.30 balance, preserved investment/contribution fields, migration provenance without artificial activity, idempotent second run, changed-plan and orphan-account rejection. Commands/results are included in the main implementation record.

Verified 2026-09-24: `NODE_ENV=test node --import tsx --test server/platform/investment_backfill.test.ts` **2 passed**; `npm run test:db -- server/platform/investment_backfill_sql.test.ts` **2 passed** against isolated MySQL 8.4.11, with synthetic user cleanup. Scoped TypeScript check and CLI `--help` passed. No existing financial record was repaired.
