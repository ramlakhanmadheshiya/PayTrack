# PayTrack

Local-first labour payroll / hisab-kitab, built in **Godot 4.7.2 stable** (`ed1daf0bf`) using GDScript and Compatibility rendering. Source repository is private. The public test app starts empty and offers optional fictional sample data.

## Run

Open `project.godot` in Godot 4.7.2, press F6/F5, or:

```sh
godot --path .
godot --headless --path . --script tests/run_tests.gd
```

## Web

```sh
python3 tools/fetch_web_templates.py
godot --headless --path . --export-release Web build/web/index.html
python3 -m http.server 8765 --directory build
```

Open http://localhost:8765/web/ over HTTP. Single threaded, no PWA or special isolation headers. Templates are downloaded only from the pinned official Godot release and stored in ignored `.tools/`.

Records stay in Godot `user://`, using browser IndexedDB in Web exports. They do **not** sync across devices/profiles, and browser clearing may remove them. Settings provides JSON backup/restore with integrity checking and a replacement preview; CSV exports and printable HTML receipts are available. Use only fictional records in the public demo.

Money uses integer INR; attendance uses half-units; extra time uses minutes in quarter-hour increments. Domain and services are separate from UI/storage. Rates and salaries are effective-dated, saved payments are snapshots.

See PROGRESS.md for verified results and unfinished acceptance criteria. Do not use this development build for actual payroll yet.

Future Android export will reuse this project, but no Android workflow or signing setup is included now.
