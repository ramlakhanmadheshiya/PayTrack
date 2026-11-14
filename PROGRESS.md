# PayTrack progress — 14 November 2026

## UI redesign update
- Replaced the crowded form-based interface with focused contractor flows, desktop sidebar, phone bottom navigation and calendar dates.
- Removed technical fields and ID entry from everyday tasks; corrections/settings open only when needed.
- **98/98 payroll assertions + 51/51 UI workflow checks passed.**
- Actual desktop/phone browser workflow verified: ₹7,058 wages − ₹500 kharchi = ₹6,558 payable; ₹6,000 cash leaves ₹558 jama. Reload and downloaded-backup contents verified.
- See docs/UI_REDESIGN.md for the complete matrix and remaining physical-device coverage.
- The UI update keeps schema 1 and existing browser records. Public runtime packs are versioned to avoid stale UI caches.
- Published and visually verified at https://theramlakhan.com/paytrack/; build b9f4f55fca04, zero live browser errors. Private source CI 43598394380 and Pages CI 43598403856 both passed. Existing portfolio page checks matched.

## Current result
Functional English Godot Web demo published and verified at **https://theramlakhan.com/paytrack/**.
Private source: **https://github.com/ramlakhanmadheshiya/PayTrack** (visibility checked PRIVATE).
Engine: **4.7.2.stable.official.ed1daf0bf**. GDScript, Compatibility, single-threaded Web, no PWA.
No new hosting account, Cloudflare integration, DNS change, backend, or Android build.

## M0 — complete
- Read AGENT_START.md and PLAN.md entirely, inspected initially empty workspace.
- Read bill-studio/tools/deploy.sh and ghtrack/deploy.sh without changing those projects.
- Inspected portfolio's Astro public-directory model and existing GitHub Pages workflow.
- Created private source repository and committed/pushed incrementally.
- Owner clarified source privacy and requested `/paytrack`; approved visible split adjustments.
- Original spreadsheet supplied later was downloaded read-only into ignored .tools and reviewed; no workforce imported or source sheet edited.

## M1–M2 — complete, verified
- Runnable Godot project, Control UI, theme, app navigation and export configuration.
- Pure integer money/half-shift/minute calculations and anchored calendar month cycles.
- **94/94 automated assertions passed** using:
  `godot --headless --path . --script tests/run_tests.gd`
- All supplied numerical acceptance vectors included; additional leap/end-of-month/zero-shift tests.
- Read-only reconciliation against all populated F/H rows in the original workbook: **58/58** attendance/hour components matched after required rounding.
- Headless UI startup passed. Actual HTTP Web export loads from subdirectory.

## M3–M6 — implemented, domain regression coverage passed
- Permanent IDs, normalized unique names, search, rename/inactive, configurable payroll start.
- Mills and both F/H rates, rename/inactive, effective-dated history; BM salaries/eligibility.
- Unpaid repricing comparison/confirmation and individual audited rate correction.
- Multi-person batch attendance, per-start-date rate snapshots, duplicate/overlap checks.
- Manual split conserves half units, minutes and original rounded wage total via explicit adjustment.
- Audited unpaid attendance and ledger corrections.
- Jama, dated kharchi, daily bulk kharchi, advance installments and explicit recovery overrides.
- Pay to any date, per-person paid-up-to boundaries, straddle refusal, component previews.
- Atomic saved payment, frozen names/mill names/rates/calculations, partial jama, negative advance.
- Conservative latest cancellation with audit and dependency checks.
- Family creation/membership edits/dissolution with aligned dates, no pending balances/earnings.
- Family one cash payment, member allocations and overrides, aggregate net cash cap.
- On-screen receipt, printable HTML download, payment history and CSV exports.
- Actual browser test recorded a fictional BM payment, then reloaded and saw retained payment.

## M7 — functional Web build verified; browser matrix still partial
- Versioned JSON local repository: validate/temp-write/backup/rename; invalid local saves protected.
- JSON integrity envelope, schema/reference/amount/payment-total validation and restore preview.
- Actual browser: seed → reload → saved data retained.
- Actual browser: download JSON → add temporary third person → choose downloaded backup → confirm two-person preview → restore → two people retained.
- Browser export path: `build/web/index.html`. Local server: `python3 tools/serve.py`, then http://127.0.0.1:8766/web/.
- Noto Sans (SIL OFL license included) fixes rupee glyphs; 44+ pixel controls, rounded white cards, light palette, compact responsive navigation.
- Phone-width 390×844 in-app browser layout and payment confirmation manually checked.
- 100 fictional workers across five mills: exact domain previews and backup round trip passed (automated, not a full manual 100-person interaction test).
- Runtime PCK verified: **19 allowlisted resources**, no workbook/plans/tests/backups/reference workforce.
- Native desktop Chrome/Firefox and actual Android-device browser matrix **not completed**. Native app automation timed out; no Android device connected.

## M8 — published, verified
- Existing gh-track publishing model reused; only `public/paytrack/` changed in portfolio.
- Portfolio commits: `35b2b2e`, final runtime `9a725eb2ef68019dcb9df50c84b5e38e6f79f19d`.
- Existing Pages workflow passed: https://github.com/ramlakhanmadheshiya/ramlakhanmadheshiya.github.io/actions/runs/43585762615.
- Private source CI passed: https://github.com/ramlakhanmadheshiya/PayTrack/actions/runs/43585758283.
- Live HTTPS app visually loaded with zero new warning/error logs on its URL.
- Homepage, gh-track, Bill Studio, games and CV: HTTP 200; semantic hashes unchanged after decoding per-request email-protection encoding. Raw hashes differ because that encoding changes between requests, including before publishing.
- Portfolio Git diff from inspected baseline contains only files beneath public/paytrack. No workflow, DNS, homepage or unrelated source edits.
- Live screenshot: ignored `.tools/paytrack-live.jpg`.

## M9 / remaining review
- Shared labels/buttons use `tr()` boundary. Complete Hindi resources/switch remain to implement after English acceptance review.
- Manual end-to-end review of every advanced edit/cancellation/family flow across Chrome, Firefox and an Android browser remains; do not call this production-ready real payroll software.
- No schema 2 exists, so v1→v2 migration testing is not applicable yet.
- Local browser records are not synced, secured by a login, or automatically shared with future Android. Export a fresh JSON backup after payments.

## Next action
Owner review of the English demo, complete the remaining real-browser/device matrix, then Hindi localisation. No further deployment integration access is missing.

### Phone input and simpler setup (14 Nov 2026)
Implemented Android Chrome-targeted virtual keyboard/inputmode fixes, numeric-only monetary fields, gesture scrolling through nested controls, scroll-versus-tap handling, keyboard-height and orientation-aware dialogs. Removed dates/BM option from Add person and date/note from Add mill. Existing accounting records and calculation rules preserved. 98/98 domain assertions and 70/70 UI checks pass; Web pack allowlist 57 resources passes. In-app browser digits/letter rejection and simplified forms verified. Physical Android device validation remains with owner. Publishing through the existing isolated PayTrack route.
