# Decisions

- Godot pinned to installed official 4.7.2; GDScript, Compatibility, single-thread Web.
- Source private; owner explicitly clarified public /paytrack route is intended. Static hosted demo uses only fictional data; private source is not authentication.
- No new hosting, DNS, Cloudflare, backend or Android exports.
- Rates snapshot on attendance start; crossing ranges require manual splits.
- BM salary effective at slip end; anchored calendar cycles, fixed base even with no shifts. Payroll start is explicit; BM start is no earlier than first positive salary history.
- Integer whole rupees, half-unit attendances, quarter-hour minutes. Numeric inputs bounded to 1 billion; int64 intermediates.
- Unpaid net carries as jama; negative net becomes auditable advance after explicit confirmation.
- Daily bulk kharchi prevents including future dates; advance recovery follows installments unless overridden.
- Families require aligned boundaries and no pending earnings or balances. Member accounts remain separate.
- Cancellation conservatively limited to last payment with no subsequent edits.
- Local user:// JSON only; backups are portability. Reminder after 7 days and payments.
- No source reference worker names/rates packaged as demo data; export scene allowlist excludes tests/plans/docs.
- Initial data empty; optional fictional sample records with five fictional mills.
- Family preview supports per-member cash/recovery overrides. Combined cash cannot exceed the combined net; defaults allocate cash in member order, displaying each member's jama/advance separately.
- Owner explicitly approved original rounded total preservation on splits. Store and visibly display an audited split_rounding adjustment on a split row; component formulas remain unchanged. Repeated splitting preserves the original total.

- 14 Nov phone simplification: owner requested no date/BM checkbox when adding people, and no date when adding mills. These forms now use current-month-first-day defaults; existing data stays unchanged. A person's initial period is editable separately before their first settlement. BM salary and later mill-rate changes retain explicit effective dates to preserve correct pay calculations.
