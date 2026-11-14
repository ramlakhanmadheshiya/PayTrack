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
