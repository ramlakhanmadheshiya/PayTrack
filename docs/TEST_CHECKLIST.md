# Verification evidence

## Automated
- `godot --headless --path . --script tests/run_tests.gd`: 94/94 assertions at this revision (rerun after changes).
- All supplied BM and F/H numeric vectors; leap/end-of-month cycles and zero-attendance BM.
- BM+F+H, duplicate names, search, uncapped counts, rate boundaries/overlap, manual splits.
- Jama consumption, daily kharchi, advances, underpayment, negative carry-forward, latest cancellation.
- Family period alignment, debt join guard, one combined payment, member allocation, mixed net cash.
- Corrupt/malformed/tampered backup rejection and local save/reload; 100 fictional workers / five mills round trip.
- Private source workbook reconciliation: 58/58 F/H rows agree after integer component rounding.
- Private repository CI first run passed: https://github.com/ramlakhanmadheshiya/PayTrack/actions/runs/43583887828.
- `python3 tools/verify_export.py`: runtime-only PCK resource allowlist; excludes plans, tests, workbook, local saves.

## Actual browser (Codex in-app browser, macOS)
- HTTP WebAssembly/WebGL2 export loads at a non-root path.
- Initial blank dashboard and optional fictional seed.
- Seed two people → reload → two people retained.
- JSON backup downloads to browser's Downloads location.
- Add temporary third person → choose downloaded backup → preview shows two people → confirm → two people restored.
- Large browser pixel ratio initially shrank text; corrected using devicePixelRatio and rechecked visually.
- Initial selected-scene export missed preloaded scripts; corrected to all runtime resources with exclusions, rechecked actual loading.

## Remaining manual matrix
- Actual desktop Chrome and Firefox native app interactions (native automation connection timed out).
- Actual Android device browser test; no Android device connected to this task.
- Full graphical 100-person workflow is not manually exercised; domain/backup stress is automated.
- Hindi translation is deferred until English workflow review. `tr()` boundary exists for shared UI labels/buttons.
