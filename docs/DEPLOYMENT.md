# Deployment — existing portfolio only

Verified live URL: **https://theramlakhan.com/paytrack/**.
Source repository: **ramlakhanmadheshiya/PayTrack**, PRIVATE.

## Inspected publication pattern
- Read-only `../bill-studio/tools/deploy.sh`: runtime copy into projects/bill-studio in the portfolio repository.
- Read-only `../ghtrack/deploy.sh`: runtime copy into public/ghtrack in the same portfolio repository.
- Portfolio is `ramlakhanmadheshiya/ramlakhanmadheshiya.github.io`.
- Astro build copies public/ to dist; existing GitHub Actions builds Astro/pagefind and deploys dist with GitHub Pages.
- No app iframe, backend, new host, account, DNS, domain or subdomain is necessary.

## Reproduce

From PayTrack:

```sh
python3 tools/fetch_web_templates.py
godot --headless --path . --script tests/run_tests.gd
godot --headless --path . --export-release Web build/web/index.html
python3 tools/prepare_web.py
python3 tools/verify_export.py
python3 tools/deploy.py
```

`deploy.py` uses existing gh credentials, pulls an ignored portfolio copy, refuses dirty state, copies only runtime files to **public/paytrack**, checks staged paths, commits and pushes to the existing main branch. It never copies source plans, workbook, tests, backups or local records. It does not alter workflows, root routing, existing apps, DNS, TLS or homepage. No credentials in source and no new cross-repository secrets created.

Source CI in PayTrack runs pinned Godot tests, Web export and PCK allowlist checks, retaining only static runtime artifacts for seven days. It does not automatically publish the portfolio.

## Verification
- Final portfolio runtime commit: `9a725eb2ef68019dcb9df50c84b5e38e6f79f19d`.
- Pages run succeeded: https://github.com/ramlakhanmadheshiya/ramlakhanmadheshiya.github.io/actions/runs/43585762615.
- Actual browser loaded WebAssembly/WebGL2 at the live /paytrack/ path; no new warning/error logs on that URL.
- `tools/check_site.py` checks homepage, gh-track, Bill Studio, games and CV. Their email-protection hex encoding varies per request; the checker decodes it before hashing semantic content. All five return 200 and match.
- Git comparison against the inspected portfolio baseline contains only public/paytrack files.

The public demo starts empty, with optional fictional samples. A private source repository does not restrict access to the runtime. Data stays in each browser profile/origin; JSON backups provide portability. No real source-workbook workforce is included.

## UI update caching

`prepare_web.py` gives the main PCK a content-based filename and sets Godot mainPack to that relative file. Deployment retains two previous versioned packs for clients with cached HTML. The engine runtime stays pinned; browser local storage is unchanged.
