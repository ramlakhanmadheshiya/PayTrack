# PayTrack

Labour payroll for mill contractors: daily kharchi, advances, jama, family khatas, and
monthly payments with work periods. It replaces the diary + Excel mill sheets.
Built with **Godot 4.7.2** (GDScript, Compatibility renderer), like Single Shot.

- **Web app**: https://theramlakhan.com/paytrack/ — rebuilt and published by GitHub Actions on every push.
  Installable and offline (service worker). **iPad: Safari › Share › Add to Home Screen** (free, no App Store).
- **Android APK download page**: https://theramlakhan.com/testsapp/ — the APK there is updated when a
  commit message contains `[release]` (or Actions › Build PayTrack › Run workflow). Every push also attaches
  the APK to this repo's private [`latest` release](../../releases/tag/latest).
  All APKs are signed with the same key, so a new one installs over the old app and keeps the data.

The full plan agreed with the owner is in [PLAN.md](PLAN.md).

## How the money works (short)

- Every person has a **khata**. A family shares one, paid to its head.
  Balance **+** = jama (we owe them), **−** = advance left (they owe us).
- Kharchi / advance / jama-paid / received entries stay **open** until the person's next payment settles them.
- A payment has a **payment date** and a **work period** (From = day after the last paid day,
  Up to = end of last month by default, editable).
- F/H row = `round(rate × att + rate × hr ÷ 12)`. Master (BM) row = `round(salary × att ÷ days)`,
  days = days of the work period's first month (**Normal**), or each month separately (**Split**).
  Every row is rounded half-up, then added.
- Due = previous balance + earnings − kharchi − advance − jama paid + received.
  Pay full / pay part / keep as jama; what is left becomes the new balance.
- Rates and salaries are effective-dated; saved payments keep their own numbers forever.

## Code map

| Path | What |
|---|---|
| `scripts/core/calc.gd` | Pure payroll maths (tested) |
| `scripts/core/store.gd` | Data, balances, payments, export/import (autoload `DB`) |
| `scripts/core/dates.gd`, `money.gd` | Date strings `YYYY-MM-DD`, rupees, Indian grouping |
| `scripts/core/lang.gd`, `strings.gd` | English / Hindi (autoload `Lang`) |
| `scripts/ui/*` | Design system: `UI`, `Tap` (scroll-safe taps), `Page`, `Sheet`, `NumPad`, `NumField`, `DateSheet`, icons, app shell |
| `scripts/screens/*` | Home, Mills, People, Balances, More, Pay flow, Bill, sheets |
| `scripts/platform/*` | Share / export / import per platform, tiny PDF writer |
| `plugins_src/paytrack_share` | Android plugin: share sheet + file picker (built in CI) |
| `tests/test_core.gd` | Engine tests incl. every F/H row of the owner's sheet (numbers only) |
| `tests/screenshots.tscn` | Walks every main screen with made-up data and saves PNGs |

## Commands

```sh
G=/Applications/Godot.app/Contents/MacOS/Godot
$G --headless --path . --script tests/test_core.gd                        # tests
$G --path . tests/screenshots.tscn -- /tmp/shots phone en                # screenshots (phone|ipad, en|hi)
$G --headless --path . --script tools/make_icons.gd                      # icons from SVG
python3 tools/fetch_web_templates.py                                     # web templates (once)
$G --headless --path . --export-release Web build/web/index.html && python3 tools/prepare_web.py
python3 tools/serve.py                                                   # http://127.0.0.1:8766/
python3 tools/deploy.py                                                  # publish to theramlakhan.com/paytrack
```

## Data and privacy

Data lives only on the device (`user://paytrack.json`, IndexedDB on the web), with an automatic
previous copy. More → Export makes one `.paytrack` file; Import on another device replaces its data
(the old data is kept for Undo import). No real names or amounts go into this repo or the public site.

## Signing

The Android release key is `~/.android-keys/PayTrack-release.*`, backed up in
`~/Desktop/Apps/Games/Backup Game/PayTrack/`, and stored as the repo secrets `ANDROID_KEYSTORE_*`.
Never replace it: updates only install over the old app when signed with the same key.

## Publishing

CI pushes `build/web` to `public/paytrack` and `web/testsapp/` to `public/testsapp` of the portfolio repo
(`tools/deploy.py`, deploy key secret `PORTFOLIO_DEPLOY_KEY`, backed up with the signing key). Nothing else
in the portfolio is touched; its own Pages workflow then publishes the site.

## iPad as a native app (optional, later)

Add an iOS export preset in the Godot editor (bundle id `com.theramlakhan.paytrack`, your Apple team,
icon `assets/icon/ios-1024.png`, "Files app access" on so exports appear in Files › PayTrack),
export the Xcode project and run it on the iPad from Xcode.

Fonts: Inter and Noto Sans Devanagari, SIL Open Font License (`assets/fonts/OFL-*.txt`).
