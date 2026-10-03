# MclarionWow handoff TODO — 2026-10-03

**Status:** The audited 0.8.0 runtime (`MclarionWow.lua` and `.toc`) was published and installed in the stopped Forever Beta client. Its installed hashes were read back and matched the tested source; the previous version was backed up outside `AddOns`. The Lua mock suite passed **263 assertions** and the follow-up release review found no remaining code blocker. **The game was not launched**, so in-client behavior and disk persistence remain unverified. Documentation/test-only commits do not require a client reinstall.

## Remaining verification (no new feature development)

- [ ] Ask the user before launching WoW. Never install, update, or inspect its SavedVariables while the game is running. Confirm 0.8.0 loads without “Load out of date AddOns” and `/mhwowui` opens; report any Lua errors or protected-value refusals without copying player exports or account data.
- [ ] Verify all four automatic switches default off, then opt in only as desired. Confirm `/mhwow` and `/mhwowbagsexport` still work manually with automatic capture off and that the UI distinguishes in-memory SavedVariables from an immediate disk file.
- [ ] With the character-bank page **actively visible**, verify automatic numeric totals on bank opening, item changes, and player-selected pages, plus manual `/mhwowbankprobe`, `/mhwowbanksexport`, and paged `/mhwowbankitemsexport`. Confirm no account/Warband-bank scan or automatic tab switching. If the client denies an API or reports a secret value, stop that path; do not work around protection.
- [ ] After explicit opt-in, verify native combat logging begins at the next world entry. After `/reload`, turning off **auto-start** must leave a running log untouched; the separate player-clicked **Stop logging now** must stop it and disable restart. Check the actual game-generated log file separately; do not claim an addon-written TXT file.
- [ ] After capturing non-sensitive test changes, use `/reload`, then a clean logout and full client restart to confirm the addon's own settings and bounded character/bag/bank histories survive. Inspect only `MclarionWowData` while the client is closed. WoW controls the disk flush; opening a bag or bank page is **not** an immediate TXT commit.

## Deferred addon-only decisions

- [ ] Consider a new, backward-compatible **manual character export version** for race/faction/gender only after checking the exact Forever client APIs and secret-value behavior. Do not infer missing identity values or modify the existing `MHWOW1` contract in place.
- [ ] Do not implement arbitrary addon file writes or promise that an external unattended file reader is policy-approved. Seek authoritative policy clarification before claiming such an integration is safe; it is not part of the installed addon.

If a live check fails, keep the current backup, reproduce with a non-secret mock, review and test a narrow addon fix, publish the exact audited source, and install only after the game is closed. Do not use player payloads as test fixtures.
