# Labour Payroll / Hisab-Kitab — Godot Web Test App

**Agent-ready implementation plan | Revision 2 | 14 November 2026**

> **IMPORTANT — THIS DOCUMENT OVERRIDES THE EARLIER PLAN.** The old plan's React/TypeScript, Cloudflare Pages, Cloudflare Functions, D1, extra subdomain, and production cloud-account setup are **cancelled**. Build a **Godot Engine app using GDScript**, test it as a **web export on the existing portfolio domain `theramlakhan.com`**, keep the **source repository private on GitHub**, and reuse the owner's existing **Build Studio-style publishing workflow** where accessible. **No Android APK now**; structure the Godot project so an APK can be exported through GitHub Actions later when requested.

## 0. Operating instructions for the AI coding agent

You are the **implementer**, not just a planner. Read this entire file before editing code, then begin work independently. Do not stop after writing a design document.

1. Inspect the **current workspace** and the user's existing **Build Studio** repository/deployment configuration **if access is available**. Observe how `theramlakhan.com` currently publishes projects. Never claim to have inspected a repo you cannot access.
2. Keep all existing website, portfolio, games, live builds, DNS settings, and other repositories **unchanged** except for a clearly isolated payroll integration approved by the existing deployment arrangement.
3. **Implement locally first.** A lack of GitHub credentials, website access, or permission to inspect Build Studio is **not** a blocker for Godot development, tests, or a local Web export. Record the blocked deployment step and continue building.
4. Choose a **pinned stable Godot 4.x version** that supports the target platforms; record the exact version. Use **GDScript only**, **Compatibility renderer**, **Control-based UI**, and a **single-threaded Web export**. Avoid C#, GDExtension, paid plugins, and unnecessary dependencies.
5. All payroll calculation logic must be isolated, deterministic, and tested **before** payment UI is considered done.
6. Create functional screens, persistence, backup/restore, tests, and a runnable Web export. Commit incrementally in the **private** app repository if GitHub is connected. Never commit real payroll records, passwords, tokens, signing keys, or exported private backups.
7. After every milestone: run the test suite, fix failures, and update `PROGRESS.md` (done / in progress / blockers / next action). Do not claim something works without running it.
8. Where the business rules are explicitly supplied below, **do not improvise**. Where an unresolved decision is identified, use the stated provisional default, mark it in `DECISIONS.md`, and make it configurable if reasonable. Ask only if absolutely blocking.
9. **Do not add Cloudflare, Supabase, Firebase, paid services, a new domain, a new subdomain, or new DNS setup by default.** Do not redesign the portfolio deployment unnecessarily.
10. **Do not build Android yet.** Keep platform-neutral logic and storage boundaries; defer the actual APK workflow until the owner asks for it.

### Non-negotiable scope

| Requirement | Decision |
|---|---|
| Product | Labour contractor payroll / hisab-kitab |
| Engine | **Godot 4.x + GDScript** |
| First deliverable | Functional **Web/HTML5 test app** |
| Public website | **Existing portfolio domain `theramlakhan.com`** only |
| Suggested isolated route | `https://theramlakhan.com/payroll/` **only if existing deployment supports it** |
| Deployment process | Reuse the **Build Studio** integration/pattern if the agent can inspect it |
| Source control | **Private GitHub repository** |
| Database for initial demo | **Local Godot `user://` JSON storage** in browser, with mandatory backup/restore |
| Operating cost | No new paid services or accounts |
| Initial language | English (Indian English); design for Hindi later |
| UI | Clean, light, Apple-inspired, readable on desktop and phone browsers |
| Future only | Android APK/AAB export from the **same Godot project**, potentially via GitHub Actions |

### Important security/storage boundary

A **private GitHub source repository does not make the deployed website private**. A static Godot Web app served at a public URL does **not** have a secure server-side login or shared database by itself. This first phase is a **test/demo**:

- The deployed app must use **synthetic/sample people and payment data** for testing. Do **not** publish or import identifiable actual workers' payroll information into a publicly accessible demo without implementing suitable security and data protection first.
- Local Web saves stay in the **same browser / origin / browser profile** via Godot's `user://` / IndexedDB, subject to browser clearing, private browsing, storage restrictions, and eviction. They do **not** automatically appear on another computer or Android phone.
- Provide **Download JSON Backup**, **Restore JSON Backup**, and a prominent warning about local-only storage. Backups are the portability method in this phase. Export **CSV** for human-readable records as well.
- **No fake security**: a client-side PIN/password embedded in Web files does not protect confidential salary data. Do not present it as secure authentication. If genuine shared access, multi-device sync, or real-payroll use is needed, that will require a **separately approved secure backend or an access-controlled environment**.
- Never save payroll data or backups into a Git repository, GitHub Actions artifact, deployed `/payroll/` folder, browser logs, or URL parameters.

---

## 1. The real-world problem

One labour contractor supplies **boiler masters (BM), firemen (F), and helpers (H)** to mills. He currently uses an Excel Main Sheet and handwritten paper records to handle attendance, wages, **jama**, **kharchi**, and **advance**. The app should make it simple for one contractor to enter **batch attendance**, see accurate pay to **any chosen date**, and settle individual workers or **whole families**.

Existing mills: **Sagar, Best, Shree Ji, Shreenath, Pigeon**. More mills may be added, and mill rates/master salaries must be editable with history.

This is **not** a daily time clock. Do not force attendance entry for every calendar day. The contractor periodically receives each person's attendance for a **date range** and records the batch.

A shift (**one attendance**) is **12 hours** whether it is day or night. Working both day and night can count as **two attendances on one date**. Attendance can exceed the number of calendar days in the period.

Nobody else needs an app login or a mill-specific account in this phase. The contractor enters the information himself.

### Key terms

- **BM / Boiler master**: fixed **monthly salary**, even on leave. Extra BM shifts above the number of days in the paid period are paid additionally.
- **F / Fireman**: mill-specific rate per attendance, plus payment for extra hours.
- **H / Helper**: mill-specific rate per attendance, plus payment for extra hours.
- **Jama**: money belonging to a person but currently held by the contractor; added into the next settlement.
- **Kharchi**: money already given, often for food/water; deducted in the appropriate settlement.
- **Advance**: recoverable loan already given; recover a chosen amount per settlement, possibly in installments.
- **Pagar / settlement**: calculation and recording of what the contractor pays up to a chosen date.
- **Family**: several people with **one combined payment**, but a detailed breakdown by person.

---

## 2. Exact business rules — authoritative for implementation

### 2.1 Permanent people IDs and roles

- Assign the next permanent ID, e.g. `P-0001`, `P-0002` ...; never recycle one. Use an internal stable UUID or sequence key if needed, but show the permanent human-friendly ID in the UI, exports, and slips.
- The contractor enters names. **Block duplicate names case-insensitively**. The contractor distinguishes people with a suffix if necessary, e.g. `Munna` and `Munna Best`. Trim and normalize whitespace for duplicate detection.
- Search people by `12`, `P-0012`, or any part of their name. Show ID, name, and family (if any) in selections.
- Do not hard-delete people with history; mark them **inactive**. Keep all historical names/IDs on saved payment snapshots.
- A person may work at **more than one mill** and in **more than one role**. All earnings for the same person are combined on **one slip**.
- **Sunil** is the known person who currently works as **BM + F + H**; calculate his BM fixed pay and F/H earnings independently and add them. Do not accidentally exclude his F/H work or pay the BM base multiple times.
- Only people with an effective BM salary may have BM attendance entered. Allow enabling/disabling BM eligibility through salary history rather than deleting prior assignments.

### 2.2 Editable mill rates and BM salaries

- Each mill has separate **F** and **H** rates, measured in **whole rupees per 12-hour attendance**.
- Every BM has a personal **fixed monthly salary**, also in whole rupees.
- Both can be edited from **Settings**, not hard-coded forever. Initial values are in section 7.
- Store every rate/salary update as an **effective-dated history entry**, including timestamp, old value, new value, and user-visible reason/note (optional).
- Worker attendance entries hold a **rate snapshot**; already recorded/paid slips always retain the original calculated amount.
- For new attendance, select the rate effective for the **entry's start date** and snapshot it. **Provisional interpretation**: if a newly entered date range crosses a rate-change boundary, prompt to split the range; do not silently apply mixed rates or recalculate the past. Log this default in `DECISIONS.md`.
- Optional action **“Also update unpaid entries from this date”**: preview the exact affected entries and old/new total rupees, then require confirmation. Change only **unsettled**, applicable entries, preserving an audit of changed snapshot rates. Where an entry crosses the effective date, require explicit split/selection.
- On a single unsettled F/H attendance row, allow manual rate correction with an edit reason.
- BM salary effective on the **slip up-to date** is used for that slip, per the original plan. Historical slips stay frozen. Clearly show the chosen salary and period on the preview. Changes affecting earlier unsettled periods should produce an explicit comparison preview.
- Add/rename/deactivate mills. Never delete a mill referenced by history. The new mill must have F and H rate settings before work can be entered.

### 2.3 Batch attendance

Each entry includes:

`id, person_id, mill_id, post (BM|F|H), from_date, to_date, attendance_count, extra_hours (F/H only), rate_snapshot (F/H only), settlement_id (optional), created_at`

Rules:

- `from_date <= to_date`, dates are calendar dates (`YYYY-MM-DD`), not timestamps.
- Attendance is **non-negative** and can be whole or **half** attendances. Store internally as **integer half-units**, e.g. `3.5` attendances = `7` half-units; **no binary floating-point money calculations**.
- Extra hours are non-negative and only allowed for F/H. Capture whole/half/quarter hours as integer **minutes** if the UI accepts decimals; never calculate money with floats.
- Multiple entries for the same person across different mills, posts, and ranges are valid. Warn about overlap of **same person + mill + post**, and block exact duplicates. Overlap across different shifts or mills may be legitimate, so do not globally prohibit it.
- No entry may retroactively include a date **already covered by an active recorded settlement** for that person. All editing of an unsettled entry must be traced.
- BM entries have no extra hours and no per-shift rate. They **only contribute attendance to the BM extra-shift calculation**. Fixed BM salary is added once per pay period, not once per BM attendance row.
- The batch screen selects **mill, start date, end date** once, then adds rows of people, roles, attendances, and extra hours. Auto-fill worker rate from Settings. The contractor supplies the attendance counts; do not infer them from date length.

### 2.4 Fireman/helper wages

For **every F or H attendance row**, use its saved rate `R`:

```text
attendance_rupees = ROUND_HALF_UP(attendance_count × R)
hour_rupees       = ROUND_HALF_UP(extra_minutes × R / 720)
row_earnings      = attendance_rupees + hour_rupees
```

`720 = 12 hours × 60 minutes`. Display each component separately. **Never cap attendance at 28/30/31**; 32, 60, or 68 attendances can be valid.

### 2.5 Boiler master wages

**A BM's base salary is fixed:** no deduction for taking leave. For one chosen settlement period `[start, end]`:

- `S` = the person's fixed monthly salary (effective on the slip's end date).
- `D` = number of **inclusive calendar days** in this settlement period.
- `A` = sum of **BM attendance across all mills** for this period. Day and night shifts each count as one attendance.
- Count **full month cycles** anchored on the settlement start date. Example: **21 Oct → 20 Nov** is one full month, paid exactly `S`.
- A remaining partial cycle earns `S × partial_days / days_in_that_cycle`. Count its full calendar-cycle length, **not always 30**.
- Extra BM shifts: `max(0, A − D)`; pay `ROUND_HALF_UP(S × extra_shifts / last_cycle_length)`.
- `BM total = ROUND_HALF_UP(base salary over period) + ROUND_HALF_UP(extra BM pay)`.
- Even if a BM has **zero BM attendance** in the interval, he gets the fixed base salary for an active, payable BM period. **Do not infer employment/start dates from attendance alone.** Add a clearly editable `payroll_start_date` / BM active-from setting and show it in the slip.
- If a person also has F/H work (Sunil), calculate those rows normally, then add them to the **one** BM total.

**Important:** This is the agreed **current calculation convention**, not a general labour-law rule. The following Python reference is included so the Godot implementation can be tested identically. Do not use Python at runtime:

```python
from datetime import date, timedelta
import calendar

def add_months(d, k):
    m = d.month - 1 + k
    y = d.year + m // 12
    m = m % 12 + 1
    return date(y, m, min(d.day, calendar.monthrange(y, m)[1]))

def rnd(n, d=1):
    return (2 * n + d) // (2 * d)  # half up, nonnegative numbers

def master_pay(S, start, end, A):
    D = (end - start).days + 1
    base_num, base_den = 0, 1
    k = 0
    while True:
        bs, nxt = add_months(start, k), add_months(start, k + 1)
        L = (nxt - bs).days
        if nxt - timedelta(days=1) <= end:
            base_num += S * base_den
            if nxt - timedelta(days=1) == end:
                break
            k += 1
        else:
            n = (end - bs).days + 1
            base_num = base_num * L + S * n * base_den
            base_den *= L
            break
    base = rnd(base_num, base_den)
    extra = rnd(S * max(0, A - D), L)
    return base + extra
```

Implement Godot calculations using **integer arithmetic / exact rational intermediates** and check for overflow. Do not round each day first. This reference uses `add_months` anchoring, including end-of-month dates; cover the 28/29/30/31 edge cases in tests.

### 2.6 Round and display money

- All saved money is **integer INR**, **no paise**; never use `float` to compute wages or net payment.
- Round **half up**: `3.333→3`, `3.5→4`, `3.8→4`.
- Round **each displayed wage component** (`attendance`, `hours`, `BM base`, `BM extra`) separately, then add the integers. No hidden fractions in totals.
- Display Indian grouped amounts: `₹1,23,456`; display date as `14 Nov 2026` while storing `YYYY-MM-DD`.

### 2.7 Person ledger: jama, kharchi, advance

All monetary activity is attached to a **person**, even if that person is presently a family member.

- **Jama:** money owed to the person but held by the contractor. Add existing jama when preparing the next slip. The contractor may enter a manual jama opening/correction entry. Underpayment on a recorded settlement creates new jama.
- **Kharchi:** money already given. It reduces what remains payable. The contractor may enter one amount or a **bulk** kharchi (selected people × amount/day × inclusive date range). For a date-range entry, represent daily postings or require exact splits on an early settlement so values after the pay date aren't included prematurely.
- **Advance:** recoverable loan with dated issue, remaining outstanding, and optional recommended **per-settlement/monthly installment**. It reduces net payment only by the explicit recovery amount accepted on that settlement. The contractor can edit that amount (bounded by outstanding). Remaining advance can carry across multiple payments.
- Use **immutable or auditable ledger events / allocations** to avoid charging the same kharchi, jama, or advance installment twice. A prior settled debit must not silently reappear next month.
- The original phrasing **“after payment balance is zero” means the settled period's earnings/kharchi are cleared**. It does **not** mean an outstanding advance loan disappears or leftover jama is lost.

### 2.8 Salary slip calculation / settlement

```text
EARNINGS             = sum(F/H wage rows) + BM base + BM extra
JAMA AVAILABLE       = previous unsettled jama balance eligible by up-to date
KHARCHI TO DEDUCT    = eligible unsettled kharchi up to selected date
ADVANCE RECOVERY     = explicitly chosen recovery, default min(installment, outstanding)
NET PAYABLE          = EARNINGS + JAMA AVAILABLE − KHARCHI TO DEDUCT − ADVANCE RECOVERY
```

- Preview includes each underlying attendance row, mill, post, date range, attendance, rate, extra hours, BM base/extra calculation, jama, kharchi, advance, `net`, `cash_paid`, and `new_jama / remaining_advance`.
- `cash_paid` defaults to max(`NET PAYABLE`, 0). Allow paying **less**, but never above a positive `NET PAYABLE` from this screen (a separate advance transaction would represent money lent).
- If `NET PAYABLE > 0` and `cash_paid < net`, create jama of `net − cash_paid` for next time. The **jama used in this settlement is consumed**; it may not be reused a second time.
- If net is negative, `cash_paid=0`; convert the shortfall into a **clearly identified carry-forward advance**, following the original plan. Ensure the recovery ledger does not double-count the outstanding amount. Show a warning and require confirmation.
- **Atomic record**: freeze a full snapshot of the slip, link/consume its attendance and dated ledger rows, create recovery/jama/shortfall ledger events, and advance `paid_up_to`. Either **everything saves** or **nothing saves**.
- `paid_up_to` is **per person for accounting**, including family members paid together; never assume a single family date means unsettled members have all been settled unless the snapshot covers them.
- A **recorded slip is immutable**. Later rate, name, or attendance changes do not alter paid amounts. To fix a paid error, cancel the **latest eligible settlement** with an audit trail and explicit confirmation, then create a new settlement. Block cancellation if later payments, family changes, or dependent ledger actions make reversal unsafe.
- Every settlement can be printed or exported (screenshot/image or a simple printable HTML/PDF path if supported). **Do not depend on a paid PDF service**. At minimum, provide a readable on-screen/printable receipt and JSON/CSV payment export.

### 2.9 Pay up to *any date*, not only a fixed pay day

The real use case is irregular payments around Diwali:

- A worker can be paid **through 7 Nov 2026**, then again **8–17 Nov 2026**, then through a later chosen date, without double-paying past days.
- Someone who was **not** paid on 7 Nov can have a larger slip, e.g. **21 Oct–17 Nov**.
- A new payee's start date is the person's configured **payroll_start_date** (or a confirmed initial period start), not an accidental minimum attendance date for a BM. For existing payees, it starts the day **after the previous paid-up-to date**.
- Include only attendance ending on/before the target date. Exclude entries starting after it.
- If an attendance row **straddles** the date, stop: ask the contractor to enter attendance/hours for each part **manually**, verify that the parts sum to the original totals, then split it. **Never allocate shifts automatically by number of calendar days**.
- Same principle for date-range kharchi: exclude after-date amounts until their next settlement, using exact dated allocations.
- Distinguish **period covered** from **actual calendar date cash was handed out**; record both.

### 2.10 Families / group payment

- A family is a named group of **two or more** people paid together as **one payee**. Each person belongs to **at most one** family at a time.
- A family slip must show **each member's name + permanent ID, attendance rows, BM/F/H earnings, kharchi, jama, advance**, and an individual subtotal; then show the combined totals.
- Only **one combined cash payment** is recorded for the family. Store **per-member settlement allocations** under that combined payment, so no later individual or family payment can double-count an entry.
- A person belonging to a family cannot be paid separately. Selecting that person opens the family settlement flow.
- Create/edit/dissolve families. Joining or leaving is permitted only when the person's and family's unsettled items and balances are resolved and the **paid-up-to periods align**. Otherwise show precisely what must be settled first. Do not lose historical family membership on old slips.
- Reconcile each member's `paid_up_to` and loan/jama ledger separately even though the family receives one cash amount. Family changes must never transfer another person's debt silently.

---

## 3. Data architecture (local-first, Web now / Android later)

### 3.1 One authoritative model and a replaceable persistence layer

Use a single **versioned JSON document** in `user://` for this single-user testing phase. Keep the data model, calculations, and storage code **independent of the UI and export target**.

Suggested top-level document:

```json
{
  "schema_version": 1,
  "settings": {"currency": "INR", "last_backup_at": null},
  "next_ids": {"person": 1, "family": 1, "mill": 1, "attendance": 1, "ledger": 1, "payment": 1},
  "persons": [],
  "families": [],
  "mills": [],
  "mill_rate_history": [],
  "bm_salary_history": [],
  "attendance_entries": [],
  "ledger_events": [],
  "settlements": [],
  "audit_events": []
}
```

This is a **shape example**, not the only acceptable implementation. Define and validate all required fields and document the final schema in `docs/DATA_MODEL.md`. Core requirements:

- Use **stable IDs**, never array indexes as identities.
- Each person has `id`, `name`, normalized name, `active`, `payroll_start_date`, optional phone/notes, and family membership information.
- Rates have `effective_from`; attendance stores the **snapshot rate**, `attendance_half_units` and `extra_minutes`, settlement reference, and edit history.
- Ledger events have `person_id`, type, whole-rupee amount, effective date, and optional `settlement_id` / correction reference.
- Settlements have a **unique ID**, person/family payee, period, actual paid date, frozen `slip_snapshot`, exact **member/attendance/ledger allocations**, total earnings, jama, kharchi, advance recovered, net, cash paid, and cancellation/reversal metadata.
- Do not store only derived balances. Compute from the **events and recorded settlements**, and test reconciliation after each action.
- Write using temporary file + validation/rename/backup where supported; never overwrite the only good save after a parse/validation failure. Use a robust Web-compatible save strategy, including browser persistence checks.
- Schema must support future migrations. Backups include `schema_version`, creation timestamp, and integrity checks. Restoring a backup previews counts, validates references and totals, asks before replacement, and makes a local safety copy of current data.
- A temporary interrupted save or malformed JSON must not silently destroy the previous dataset.

### 3.2 Web local storage and backups — required, not optional

- Godot's `user://` maps to Web browser persistent storage (IndexedDB when allowed). Check `OS.is_userfs_persistent()` and display a warning when storage is unreliable, noting the API can yield false positives.
- Use **Download Backup (.json)** via Godot's `JavaScriptBridge.download_buffer()` on Web; provide a browser-compatible **Import/Restore** path. On native Godot, use file pickers/FileAccess equivalents. Test both Web flows **in an actual browser**.
- Exports must be a deliberate **user gesture**, never hidden automatic uploads. Allow CSV export of people, attendance, ledger, and settlements as separately named files.
- Show `Last backup: ...`; if more than 7 days, remind visibly. After each settlement, encourage exporting a fresh backup.
- Inform the owner that **browser clearing/incognito/another browser = no shared data**; export/import is needed. Future Android data will be a **separate local store** until import/sync is implemented.
- Use the supplied October rate/salary values as **private development/test fixtures** and as editable owner-entered starting values, **not publicly packaged demo data**. A public Web export should start empty or with fully fictional rates, master names, and workers. Never silently seed real worker attendance, transactions, or family relations.

### 3.3 Suggested Godot folder layout

```text
/
├── project.godot
├── export_presets.cfg                 # safe configuration only; no secrets
├── PLAN.md
├── README.md
├── PROGRESS.md
├── DECISIONS.md
├── .gitignore
├── scenes/
│   ├── app_root.tscn
│   ├── home.tscn
│   ├── people.tscn
│   ├── person_detail.tscn
│   ├── attendance_batch.tscn
│   ├── money_entries.tscn
│   ├── pay_slip.tscn
│   ├── families.tscn
│   └── settings.tscn
├── scripts/
│   ├── domain/                         # pure calculations, dates, IDs, validation
│   │   ├── payroll_calculator.gd
│   │   ├── money_math.gd
│   │   ├── date_cycles.gd
│   │   └── ledger_service.gd
│   ├── services/                       # app use cases, settlement, family/rates
│   │   ├── attendance_service.gd
│   │   ├── settlement_service.gd
│   │   └── family_service.gd
│   ├── storage/
│   │   ├── repository.gd
│   │   ├── json_repository.gd
│   │   ├── backup_service.gd
│   │   └── migrations.gd
│   └── ui/                             # UI/controller scripts
├── assets/                             # icons, theme resources only
├── locales/                            # English first, Hindi later
├── tests/
│   ├── run_tests.gd
│   ├── test_payroll.gd
│   ├── test_settlements.gd
│   ├── test_families.gd
│   └── test_storage.gd
├── docs/
│   ├── DATA_MODEL.md
│   ├── DEPLOYMENT.md
│   └── TEST_CHECKLIST.md
└── .github/workflows/                  # add only once existing workflow is understood
```

Keep nodes/scenes presentational. Do **not** scatter wage formulas through buttons or scene scripts. Separate model from storage and file-export details for easy eventual Android export.

---

## 4. Screens and UX — implement all, in this order

1. **Home / Dashboard** — large buttons: `Add Attendance`, `Pay Someone`, `Money Entry`, `People`. Secondary summaries of unpaid people and recently recorded payments. Clearly label the project as a **test / local-data app**.
2. **People** — search permanent ID/name, create/edit, mark inactive, view role eligibility, family, unsettled rows, jama, advance, and recorded settlements.
3. **Settings / Main Sheet** — view every mill's F/H rates and each master's monthly salary; edit with effective date, history, repricing preview, individual row correction, add/deactivate mills, manage BM salary eligibility, backup/restore.
4. **Batch Attendance** — select one mill/date range, add multiple people in a table, post dropdown BM/F/H, attendance, optional extra hours; auto-display rate; validate before batch save.
5. **Jama / Kharchi / Advance** — add individual money entry, bulk kharchi by inclusive dates, monthly advance-recovery preference, editable only while not settled.
6. **Salary Slip / Pay** — select person/family by ID or name and up-to date, preview detailed earnings and deductions, adjust recovery and cash paid, confirm, freeze, display printable/shareable slip, show history/cancel latest action.
7. **Families** — create/edit, add/remove members if eligible, combined slip and payment with per-member breakdown.
8. **Backup/Restore** — prominently accessible, with restore preview and tests.
9. **Polish** — English strings in a translation layer now, Hindi switch only in the final phase after tests pass.

### Visual design requirements

- **Godot Control nodes**, responsive anchors/containers, no fixed-size game-like UI. Desktop and phone **browser** are the targets.
- **Light mode only** for the first version. White/off-white backgrounds, iOS-like blue `#007AFF`, subtle separators, gently rounded cards, high-contrast labels, generous whitespace.
- Use Godot's appropriate licensed/default UI fonts; do not bundle proprietary Apple font files. Numerical columns should be easily readable and aligned.
- A **sidebar on large screens** and **bottom navigation / compact layout on mobile** if feasible. Buttons and row targets at least roughly **44 px** high. Keep the most important action prominent.
- Currency `₹1,23,456`, dates `14 Nov 2026`, simple wording understandable to the contractor.
- English first, with an i18n abstraction to add Hindi later. Do not add a complex login, multi-user administration, analytics, or GST/PF/ESI screens.

---

## 5. Godot Web build and existing-domain deployment

### 5.1 Build constraints

- Export **Web/HTML5** in **single-threaded** mode with **Compatibility** renderer. Prefer Godot **4.3 or newer stable** supporting the setting; pin the actual version in README/CI. No C# (Godot 4 C# Web export is not supported in the documented flow).
- Keep export files together; normally Web export entry is `index.html`. Test WebAssembly and WebGL2 loading in real browsers. Serve via **HTTP(S)**, not by opening `index.html` as `file://`.
- **Do not enable threads** merely for speed: threaded builds can require `SharedArrayBuffer` and special HTTP headers. **Do not enable PWA**; it is out of scope.
- Use relative paths and a deploy structure that works under an **existing subdirectory** such as `/payroll/` when supported by the hosting/build pipeline.
- Validate desktop Chrome/Chromium and Firefox, plus at least one Android mobile browser. If a mobile browser is incompatible, note the device/browser and continue improving desktop Web first; the eventual native Android build is planned separately.

### 5.2 Deployment discovery (do this before editing the portfolio)

Investigate the existing **Build Studio** project, if readable, and answer in `docs/DEPLOYMENT.md`:

1. Which repo owns `theramlakhan.com`, and how is the site deployed now?
2. Is Build Studio added via a path, iframe, subproject, publish directory, separate repo/workflow, or custom action?
3. Can a **private payroll repo** publish **only static Godot export assets** into a dedicated directory without overwriting other site files?
4. Does the existing CI/CD use deploy keys, repository secrets, GitHub Actions, or another already-configured method? Reuse only permissions actually available; **never print secrets**.
5. What exact non-destructive steps are needed to integrate `/payroll/` without changing portfolio routing, DNS, TLS, homepage, or other apps?

**Preferred**: same pattern as Build Studio, on **the current domain**. `https://theramlakhan.com/payroll/` is an example route, **not permission to change DNS or to invent a new hosting service**.

**If the deployment configuration is unavailable:** finish the Godot project and `build/web/` export locally; provide `docs/DEPLOYMENT.md` with integration instructions and **stop only the deployment action**. Do not guess GitHub credentials or damage the live portfolio. Do not ask the user to create a new service account as a workaround.

**GitHub Pages caveat:** GitHub Free normally supports Pages from **public** repositories, not private source repositories. If the portfolio uses Pages, the existing publishing mechanism must be checked; using a private source repo to produce a **public static build** can be feasible through an existing deployment pipeline, but a private repo alone is **not** access control. Never switch the private source repo public just to make deployment work.

### 5.3 GitHub and CI

- Keep app **source** in its own private repository, if one is not already supplied. Do not auto-create a repo or push unless the AI agent has explicit authorized access to the correct GitHub account/workspace.
- Add `README.md` covering Godot version, local launch, headless tests, Web export, backup restore, demo limitation, and future Android workflow.
- Add `.gitignore` for `.godot/`, temporary builds, local data, backed-up JSON/CSV and secrets; keep needed project assets and text configuration.
- CI (if available) should run **headless Godot tests**, **Web export**, and store/copy only **static build artifacts** through the existing approved deployment workflow.
- Keep deployment to its **own directory only**. Use preview/build verification to ensure the current portfolio still loads. Never run a workflow that wipes an entire publish branch or site root without verifying that this is the existing intended integration method.
- **No Android GitHub Action now.** The app must remain suitable for a later workflow that exports APK, with release keystore managed as **GitHub secrets**, not in source control.

### 5.4 Security for initial test

- Do not treat `noindex` or a private source repo as authentication.
- Do not bundle passwords, private keys, or employee payroll records into the Web export.
- Display `Local testing data — not synced between devices` in Settings and on first use.
- Prefer synthetic demo data throughout. Do not enable features that transmit personal payroll data off-device without a separate approved backend/security plan.

---

## 6. Initial seed data — October 2026 Main Sheet values

These came from the previous PLAN.md; they are **initial defaults**, not permanent hard-coded values. The original Excel file was **not included in this handoff**, so do not claim they were independently rechecked against the source workbook.

### Boiler master salaries (whole rupees per month)

| Master | Salary |
|---|---:|
| Laxman | ₹32,000 |
| Pradhan | ₹22,000 |
| Vinod | ₹22,000 |
| Rishikesh | ₹41,000 |
| Sunil | ₹20,000 |

### Mill rates (rupees per attendance)

| Mill | Fireman (F) | Helper (H) |
|---|---:|---:|
| Sagar | ₹285 | ₹420 |
| Best | ₹300 | ₹400 |
| Shree Ji | ₹270 | ₹380 |
| Shreenath | ₹270 | ₹380 |
| Pigeon | ₹300 | ₹380 |

Treat these names/values as **private owner reference data and test vectors**, never as defaults embedded in a publicly downloadable Web export. If the owner chooses to use real records on a trusted device later, they must enter or import them separately under an appropriate security plan. **Do not create or invent the rest of the actual workforce**; the contractor will add names and specify which duplicate names refer to different people. A public demo must have empty or fictional records and fictional starting rates/salaries.

---

## 7. Acceptance tests — must pass before calling the app ready

### 7.1 Fixed BM monthly tests

**Period: 1–31 Oct 2026 (31 days).**

| Master | Monthly S | BM attendance | Base | Extra | Total |
|---|---:|---:|---:|---:|---:|
| Laxman | 32,000 | 32 | 32,000 | 1,032 | **33,032** |
| Pradhan | 22,000 | 37 | 22,000 | 4,258 | **26,258** |
| Vinod | 22,000 | 32 | 22,000 | 710 | **22,710** |
| Rishikesh | 41,000 | 60 | 41,000 | 38,355 | **79,355** |
| Sunil (BM portion only) | 20,000 | 31 | 20,000 | 0 | **20,000** |

### 7.2 Partial and full BM cycles — Pradhan at ₹22,000

| Period | BM attendance | Expected |
|---|---:|---:|
| 8–17 Nov 2026 | 10 | **₹7,333** |
| 21 Oct–7 Nov 2026 | 18 | **₹12,774** |
| 21 Oct–20 Nov 2026 | 31 | **₹22,000** |
| 18 Nov–17 Dec 2026 | 30 | **₹22,000** |
| 21 Feb–20 Mar 2027 | 28 | **₹22,000** |

Also test leap years, end-of-month cycles, a **BM with zero shifts but active eligibility**, and a long period containing multiple full cycles plus a leftover partial cycle.

### 7.3 Fireman / helper wage tests

| Input | Expected |
|---|---:|
| 68 attendances × ₹285 | **₹19,380** |
| 8 extra hours × ₹380 ÷ 12 | **₹253** |
| 2 extra hours × ₹285 ÷ 12 | **₹48** |
| 6 extra hours × ₹420 ÷ 12 | **₹210** |
| 0.5 attendance × ₹285 | **₹143** |

### 7.4 Integration and regression tests

Automate at least the following:

- A person can earn **BM + F + H** together on one slip without double-counting the BM base.
- Two distinct IDs/names `Munna` and `Munna Best` are searchable; duplicate normalized names rejected.
- In one 30-day period 35 BM shifts cause **5 extra** shifts, not 4. In a 31-day period 32 shifts cause **1 extra**. Never confuse a calendar day with an attendance.
- A worker can have more than 31 attendance; no shift cap.
- **Kharchi + advance recovery + jama** produce the exact net; each is consumed/allocated only once.
- **Part-payment** creates exactly the leftover jama. Next settlement includes it once.
- **Negative net** pays ₹0, records a transparent carry-forward advance, and never double-counts it on the next slip.
- Pay through **7 Nov**, then **17 Nov** covers **8–17 Nov** only. A person not paid on 7 Nov can still get the full earlier-to-17-Nov period.
- A straddling attendance row refuses a premature settlement until manually split, and split totals equal the original row.
- A family settlement equals the sum of member earnings/deductions, but has only **one actual cash payment**. Members cannot be paid twice.
- Family join/leave validates no pending unsettled earnings/balances or mismatched dates.
- Changing a rate shows affected unpaid entries and preserves paid snapshots. Editing a master salary later never rewrites old slips.
- Save → close/reload Web page → load saved data **in the same browser**. Export JSON → remove local test data → restore JSON → validate all IDs, history, totals, and snapshots.
- Malformed/corrupt backup **fails safely** without deleting working data. Test migrations from `schema_version=1` once a second schema is created.
- Headless pure-domain tests run on CI / local Godot without requiring a graphical UI.
- Web export opens via an HTTP server and works at a **non-root path** if the existing portfolio uses one.

**Definition of done:** passing automated tests, manually confirmed workflows, actual Web export tested, no made-up success claims, no new hosting bills/services, no loss of prior portfolio functionality, and all limitations documented.

---

## 8. Milestones — execute sequentially and report evidence

### M0 — Discovery and safety (first action)

- [ ] Read this plan and inspect workspace / `git status`.
- [ ] Check existing **Build Studio** / portfolio publication method **if accessible**, and document facts vs unknowns.
- [ ] Select and pin stable Godot version; confirm Web export compatibility.
- [ ] Set up private source repo if already authorized, or use local directory without blocking work.
- [ ] Create `README.md`, `PROGRESS.md`, `DECISIONS.md`, `docs/DEPLOYMENT.md`.

**Exit:** no destructive actions; documented exact constraints; Godot project can be opened locally.

### M1 — Runnable Godot skeleton

- [ ] Create `project.godot` (GDScript, Compatibility), base theme, app root and navigation.
- [ ] Add simple placeholder Home / People / Attendance / Pay / Settings scenes.
- [ ] Configure Web export and prove **local HTTP-hosted Web build** works.
- [ ] Set up a **headless test runner** and basic CI if available.

**Exit:** app starts in Godot and in a browser; one smoke test passes.

### M2 — Pure payroll engine and test vectors

- [ ] Implement half-up integer rounding, dates/month cycles, worker pay, BM base/extra, and combining BM+F+H.
- [ ] Add every expected number from section 7 as automated assertions.
- [ ] Implement settlement calculation in read-only pure functions, decoupled from UI and storage.

**Exit:** all numeric tests are green and documented.

### M3 — Data, people, mills, rate history

- [ ] Implement versioned local repository, validation and safe saves.
- [ ] Implement permanent person IDs, unique names, active/inactive status, search.
- [ ] Add five mill definitions and test the supplied salary/rate fixtures **privately**; ensure the public export does not contain actual master names and confidential rates. Add effective-dated edits/history.
- [ ] Implement individual unpaid entry repricing preview and confirmation.

**Exit:** edits survive browser reload, paid history cannot mutate.

### M4 — Attendance and ledger

- [ ] Implement batch attendance UI, role/rate autofill, overlap and duplicate validation.
- [ ] Implement manual splitting for date-straddling entries.
- [ ] Implement jama, single/bulk kharchi and advance loans/installment history.
- [ ] Add deterministic allocation and no-double-count tests.

**Exit:** a fictional worker can accrue earnings/deductions with an exact ledger.

### M5 — Pay to any date, settlement and receipts

- [ ] Build person picker / up-to date / preview, advanced amount and cash override fields.
- [ ] Implement atomic settlement, frozen snapshots, paid-up-to progression, underpayment jama, negative-net handling, and safe latest-settlement cancellation.
- [ ] Add printable receipt/history and settlement integration tests.

**Exit:** the 7-Nov / 17-Nov scenarios, all formula tests, and rollback tests pass.

### M6 — Families

- [ ] Implement family creation, membership conditions and combined slip.
- [ ] Implement one payment with per-member allocations and tests for double-pay prevention.

**Exit:** family payment works and membership changes cannot corrupt balances.

### M7 — Backups, UX polish, final Web export

- [ ] Add JSON export/restore (actual browser test), CSV exports, 7-day reminder.
- [ ] Polish light/Apple-inspired UI and test phone-browser layouts.
- [ ] Verify demo-only use and local data warning.
- [ ] Manually exercise ~100 synthetic workers across five mills; fix performance problems.
- [ ] Export final `build/web/` artifact and run actual browser smoke tests.

**Exit:** complete functional Web demo and recoverable local test data.

### M8 — Publish to the existing `theramlakhan.com` setup

- [ ] Re-check the Build Studio-style workflow and precise publish path.
- [ ] Add non-destructive GitHub Actions workflow only if authorized and compatible.
- [ ] Deploy **only** the payroll static files into a dedicated existing-site location (prefer `/payroll/` if confirmed).
- [ ] Verify HTTPS/site routing and **all existing portfolio content** after deployment.
- [ ] If hosting access is missing, supply exact integration instructions and the build instead of inventing a deployment.

**Exit:** live app at a verified address on the **existing domain**, or a clearly documented deployment blocker with a fully working local Web build.

### M9 — Hindi (after functional tests)

- [ ] Extract complete UI strings into language resources.
- [ ] Add Hindi translations and language switch, rerun full tests.

**Exit:** English remains correct; Hindi can be enabled without changing calculations.

### Deferred milestone — **Android, only after owner requests it**

- Use the **same Godot codebase** and platform-neutral domain/storage layer.
- Add Android export preset, test local storage/backup migration, and optionally a **manual GitHub Actions** workflow that exports a signed APK/AAB.
- Keep keystore, alias, and passwords in protected secrets; never commit credentials. Confirm install package name and signing strategy when Android work actually begins.
- Do **not** build an Android app now and do not promise Web local data will sync automatically with the future APK.

---

## 9. Explicit provisional decisions — log these instead of hiding them

1. **Storage for the testing stage**: Godot `user://` JSON, no central database, no sync; JSON backup/restore is required. This minimizes hosting complexity but cannot securely support real multi-device payroll yet.
2. **Security**: synthetic payroll data only on the public demonstration URL; no misleading client-only password system. A future real-data deployment needs explicit security work.
3. **Website URL**: prefer a `/payroll/` path on the **existing `theramlakhan.com` portfolio** if compatible with current Build Studio publishing, not a new host/subdomain.
4. **Attendance rate**: snapshot the rate effective on the attendance range **start date** and split a rate-crossing range; manual correction for unpaid rows remains available.
5. **BM salary**: fixed base with no leave deduction; partial months follow anchored cycles; rate effective on **slip end** applies to that slip, as stated in the previous plan.
6. **First settlement start**: explicit `payroll_start_date` / owner-confirmed opening period (necessary so zero-attendance BMs still receive the base). Default to the payroll start provided on person creation; do not infer from first attendance if BM.
7. **Advance recovery**: default to `min(preferred installment, outstanding)`, editable in a slip. Carry loans separately from settled period balances.
8. **Underpayment**: unpaid net becomes new jama for next settlement; previous jama is consumed during the settlement.
9. **Negative net**: cash paid ₹0; shortfall is carried forward as an auditable advance entry, without re-deducting a settled ledger row.
10. **Family changes**: only after relevant accounts/periods are settled and member dates align.
11. **Backup cadence**: display warning after 7 days and remind after settlement; never silently upload data to third-party services.
12. **Source seed data**: carried from the uploaded October 2026 PLAN.md; workbook itself was not part of this handoff. The user may edit all seed rates/salaries.

If an actual business assumption causes a conflict during implementation, **log the concrete example and proposed safe behavior**, continue with independent tasks, and surface the question in the final report.

---

## 10. Strictly out of scope for this Web testing phase

- Native Android/iOS binaries, Android CI release, Play Store, PWA/offline install.
- Cloudflare Pages/Functions/D1, Firebase, Supabase, new DNS or hosting platform, new paid accounts.
- A custom server, login backend, cloud-sync, multiple users/roles, boiler-master login.
- Daily time punching, mill-wise management reporting, GST/PF/ESI, banking integrations, notifications, analytics, paid PDFs, AI features.
- Real workforce payroll data on a publicly accessible test demo.
- Modifying/deleting existing live portfolio sites, Build Studio, games, or their workflows except a separately scoped deploy integration.

---

## 11. First commands / immediate execution order for the agent

**Do the work, do not only restate this plan:**

1. `pwd`, `ls -la`, `git status` (where applicable); inspect project files and available Godot command/version.
2. If the current directory is the existing app, preserve it. Otherwise create the **smallest clean Godot project** in the authorized working directory; don't accidentally nest an unrelated repository.
3. Create `PROGRESS.md` and write discoveries; create `DECISIONS.md` with the assumptions above.
4. Create `scripts/domain/` and the headless test runner **before** building complex screens.
5. Implement integer rounding + October BM/worker test vectors; run all tests and fix them.
6. Build the local repository and minimal People/Settings UI, then a batch attendance workflow.
7. Continue through milestones M4–M7. If website GitHub access is unavailable, don't stall: finish and test the local Web app.
8. Attempt website publication only once the deployment pipeline is understood and the non-destructive integration is authorized.
9. After coding, report **what files changed, what tests actually ran, what passed/failed, local launch command, exact live URL if verified, and remaining blockers**.

### Final agent response format

```text
IMPLEMENTATION SUMMARY
- Completed milestones:
- Key files created/changed:
- Godot version used:
- Automated test command and actual result:
- Local Web export path and smoke-test result:
- Deployment method verified from existing Build Studio setup: yes/no
- Live theramlakhan.com path (only if actually deployed and checked):
- Local storage / backup limitations:
- Open decisions or blockers:
- Next recommended development step:
```

## 12. Official documentation to consult when needed

- Godot Web export: https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html
- Godot `user://` paths: https://docs.godotengine.org/en/stable/tutorials/io/data_paths.html
- Godot JavaScriptBridge Web downloads: https://docs.godotengine.org/en/stable/tutorials/platform/web/javascript_bridge.html
- Godot Android export (later): https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html
- GitHub Pages publishing eligibility: https://docs.github.com/en/pages/getting-started-with-github-pages/creating-a-github-pages-site

**Start now with M0 and M1, then proceed automatically into M2 and the remaining milestones. Build the Godot app; do not replace it with a different stack.**
