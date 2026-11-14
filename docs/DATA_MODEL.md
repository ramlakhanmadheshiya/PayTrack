# Data model (schema 1)

Single versioned JSON document: persons, mills, rates, salaries, attendance, ledger,
settlements, families, audit; settings and monotonic next_id.
IDs use permanent prefixed sequence keys (P-, M-, R-, S-, A-, L-, PAY-, FAM-); never recycled.
Amounts are whole INR integers. JSON numbers are coerced to int before calculations.
Attendance half_units and minutes avoid floating-point wages. Rate snapshots live on each row.
Ledger uses immutable issue amounts plus recorded recovery/settlement allocations.
Payment slips freeze person name, periods, attendance/rates, BM calculation and totals.
Family payment has one cash value and multiple member slips.
Cancellation preserves a cancelled receipt and restored allocations; monotonic IDs retained.

Saves: validate, temp write, flush/close, copy prior save to .bak, rename temp.
Backups: JSON envelope containing schema_version, created_at, string payload, SHA-256.
SHA-256 detects accidental corruption; it is not authentication or encryption.
Restore validates the envelope and document before replacing and retains prior save as .bak.
Only schema 1 supported; later versions must add migrations before version bump.
