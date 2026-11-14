# Message to give your coding AI agent

Read the attached `PLAN.md` completely. It supersedes the previous payroll plan and includes my final requirements.

**Start implementing the actual Godot project now; do not just prepare another plan.** Use Godot 4.x with GDScript and its Web export first. Make the labour payroll calculations and the complete contractor workflow work correctly, using the acceptance tests in PLAN.md. Commit the source to my private GitHub repository only if you have authorized access.

The first test deployment must use **my existing portfolio domain `theramlakhan.com`**, following the same publishing method as my **Build Studio** project if you can inspect it. Do not create a Cloudflare account, a new domain/subdomain, or a new paid backend. Never disturb my existing portfolio or other projects. If existing deployment access isn't available, finish the functional local Web build and tell me only what specific integration access is missing.

The deployed website is a **demo/test**. Use synthetic data, local browser storage, and JSON backup/restore. Do not claim client-only storage is a secure, synced database. No Android app now: later I will ask you to set up GitHub Actions to export an Android APK using the same Godot project.

Work milestone by milestone, run the automated tests, and update `PROGRESS.md` with proof of what works. Begin with M0/M1/M2 immediately, then keep implementing without repeatedly asking me to confirm already decided requirements. At the end, report the actual code changes, test results, local-run steps, and verified deployment URL (if published).
