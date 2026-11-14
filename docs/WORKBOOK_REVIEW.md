# Original workbook review — 14 November 2026

User supplied the original Google Sheets link during implementation. Read-only XLSX export downloaded to ignored `.tools/payroll-reference.xlsx`; the workbook itself is unchanged and never packaged/pushed.

Inspected all six worksheets: Main Sheet and five mill sheets. Main Sheet salaries and F/H rates match PLAN.md section 6. Formula patterns:

- Mill rate: look up BM salary by name; otherwise select the mill's F/H rate from Main Sheet.
- Attendance amount = saved rate × supplied attendance count.
- Extra-hours amount = rate × supplied hours ÷ 12.
- Gross = attendance amount + hours amount + jama.
- Earning = gross − kharchi − advance.

Relevant examples: Sagar F4/G4/I4/L4 and Pigeon F4/G4/I4/L4; Main Sheet A3:B7 and D2:F6. Best rows 3–5 confirm one name appears in BM, F and H roles; no auto-merging of unknown workforce identities is performed.

BM wage cells return literal “BM”, not a fixed-salary/extra-shift calculation. Therefore PLAN.md's explicit BM algorithm remains authoritative. Original formulas keep fractional rupees; the app follows the separately required integer half-up rounding. Existing sheet has blank gross formulas on some unused rows; no workbook edits made.

The source workbook has no settlement dates, durable person IDs, loan-allocation history, family membership model or posted payment snapshots; those app rules remain defined by PLAN.md and owner clarifications.

Owner clarified split rounding: preserve the original row's rounded total and display an explicit adjustment on the split rows. Example ₹285 → ₹143 and ₹143 − ₹1; original total remains ₹285. This is audited and shown on receipts.

Executed private local GDScript reconciliation of every nonempty F/H input row: **58/58** attendance and hours components matched the workbook's cached values after required half-up integer rounding. Generated reference vectors and the source workbook remain only in ignored `.tools/`; no workforce import or identity assumptions made.
