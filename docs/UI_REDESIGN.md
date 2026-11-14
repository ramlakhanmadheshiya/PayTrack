# Contractor UI redesign — 14 November 2026

## Changes
- Three daily actions on Home: Add attendance, Make a payment, Record money.
- Desktop sidebar and phone bottom navigation; readable rupee amounts and 44+ pixel controls.
- First-use setup explains adding people and mills instead of showing empty statistics/forms.
- Names in selections; no typing permanent IDs, comma-separated family members or ISO dates.
- Real calendar controls storing unchanged ISO calendar values behind readable dates.
- People are listed first; add/edit forms open only on request. Families use name checkboxes.
- Attendance is a compact worker table on desktop, stacked fields on phones. Corrections/splits are contextual entry actions.
- Kharchi/advance/jama tabs share one focused form; installments appear only for advances.
- Payment is choose → review → confirm → receipt. Ordinary cash payment is separate from optional advance/date adjustments.
- Review clearly shows earned wages, jama, kharchi, recovered advance, cash given and remaining jama.
- Early-date attendance straddles open a guided manual split and return to the payment review.
- Settings offers mills/rates, salaries and backups; history, repricing and CSV tools open separately.
- Invalid inputs stay in the form, with the error beside the form; corrections remain audited.
- Public runtime packs use a content hash filename so a reload retrieves the updated UI. Two previous versioned packs are retained for cached HTML. Local records and schema stay unchanged.

## Verification
- `godot --headless --path . --script tests/run_tests.gd`: **98/98** assertions passed.
- `godot --headless --path . --script tests/run_ui_tests.gd`: **51/51** interface/workflow checks passed.
- UI checks drive buttons/fields through person creation, duplicate rejection, attendance save/error preservation, money entries, advance installment, part-payment, receipt, reload, cancellation, family creation/membership selection, bulk kharchi, salary comparison, mill edits, repricing, single-rate correction, attendance correction, guided split, family payment and valid/corrupt restore.
- Fixed two bugs found during this work: oversized/empty bulk kharchi must fail, and correcting a split row retains its existing rounding adjustment.
- Actual browser at desktop 1440×1000 and phone 390×844: reviewed Home, attendance, money entry, payment, confirmation, receipt and calendar.
- Actual browser workflow: fictional Meera, 20 shifts at ₹350 + 2 extra hours = ₹7,058. Kharchi ₹500 gives payable ₹6,558. Cash ₹6,000 creates exactly ₹558 jama. Saved payment survives reload and versioned-pack update.
- Actual phone calendar: selected 7 Nov 2026; BM salary preview correctly shows ₹5,600 for 1–7 Nov at fictional ₹24,000/month, with no attendance.
- Actual new backup button downloaded a JSON file; its checksum, 2 people, 1 attendance, 1 payment, ₹6,000 cash and ₹558 jama were verified from the downloaded file.
- Runtime PCK allowlist: **53 resources**, no test fixtures/workbook/local data packaged.

The in-app browser is verified. Physical Android-device and native Firefox testing remain outside this check; no Android device is connected. Native browser/file-event automation can stall independently of the application.

## Published verification
- Private source commit: `b067eb0`. CI passed: https://github.com/ramlakhanmadheshiya/PayTrack/actions/runs/43598394380.
- Portfolio runtime commit: `561f6f8069af8620fde00f65dc29f4148e235e5c`. Existing Pages CI passed: https://github.com/ramlakhanmadheshiya/ramlakhanmadheshiya.github.io/actions/runs/43598403856.
- Live URL: https://theramlakhan.com/paytrack/. Actual browser rendered the redesign and reported build `b9f4f55fca04`, matching the verified local runtime pack. Zero warning/error entries for this live app URL.
- Existing live browser records were retained. No test records were imported into that existing live browser store.
- Homepage, gh-track, Bill Studio, games and CV returned 200 with unchanged normalized content hashes. Only public/paytrack runtime files changed in the portfolio.
- Screenshots retained locally in ignored .tools/: paytrack-live-redesign.jpg, paytrack-desktop-redesign.jpg, paytrack-phone-redesign.jpg.

## Phone interaction fixes — 14 November 2026
- Owner reported Android Chrome scrolling and delayed number entry. Reproduced failed touch-scroll tests before changing gesture handling.
- Shared touch scrolling handles finger drags before nested cards/buttons consume them, includes a 12 px threshold and bounded momentum, cancels button activation during swipes, and preserves normal taps afterwards. Calendars block underlying page gestures.
- Enabled Godot's direct HTML virtual-keyboard input path. Reflected the pinned engine's lowercase `inputmode` property into the real HTML attribute so Android Chrome requests its numeric keypad. Input-event changes also trigger validation and dependent calculations when Godot does not emit `text_changed`.
- All money/rate/salary fields reject letters. Decimal or signed pastes are rejected rather than silently turning ₹12.50 into ₹1,250. Fields can still be cleared and edited.
- Add person now asks for name only. Boiler-master salary remains in Settings; the first pay period defaults to the current month's first day. Before any settlement, older work can be enabled through person details → More options → Change first pay period. Existing people retain their dates and salaries.
- Add mill now asks for name and F/H rates only, defaulting initial rate history to the current month's first day. Effective dates and notes remain in the existing-mill rate-change flow.
- Dialogs resize with the phone keyboard/viewport, focused fields stay in view, and dialog margins update across desktop/phone sizes.
- Verification: 98 domain assertions and 70 UI/workflow checks pass. New checks cover real Godot touch events plus Android-style emulated mouse events, page and modal swipes, accidental button activation, normal tapping after scrolling, direct text updates, numeric filtering, signed/decimal paste safety, name-only person and date-free mill forms, keyboard-height resizing and desktop-to-phone modal bounds.
- In-app browser review at 390×844 and 1200×1000: name-only form, scroll access to Settings actions, numeric entry (`1234abc` visibly becomes `1234`), and browser build/config flags verified. Browser records retained; no test payment was saved during this review. No physical Android device is connected, so Gboard/device-specific behaviour still needs owner confirmation after reload.
