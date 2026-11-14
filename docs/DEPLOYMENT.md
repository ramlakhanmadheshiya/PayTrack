# Deployment discovery

Read locally, without modification:
- ../bill-studio/tools/deploy.sh: clones ramlakhanmadheshiya/ramlakhanmadheshiya.github.io and copies only runtime files into projects/bill-studio.
- ../ghtrack/deploy.sh: same portfolio repo, copies runtime files into public/ghtrack and pushes a path-scoped commit.

The requested destination is now **https://theramlakhan.com/paytrack/**.
Source stays private in ramlakhanmadheshiya/PayTrack. Only exported fictional-demo runtime assets may be published.
No DNS/Cloudflare/new host/new accounts. No real workers or private test fixtures in export.

Current portfolio source/CI is being inspected in .tools/portfolio (ignored) before a deployment script is finalized.
The website root, existing apps and workflows must remain unchanged. Deployment must copy only public/paytrack if the current site confirms the public-directory model.
