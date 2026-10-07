# Capture dashboard redesign — accepted scope

## Player evidence and target

Player reports Forever 1.60.1.70245. Screenshot shows loaded Main UI, crowded title/header, close button overlapping navigation, clipped action/text space, and only partial status detail. This establishes a layout defect, not compatibility of every API on the new build. Installed version remains 0.12.1-candidate until a separately verified stopped-client update. The player was told they can exit normally immediately; no further capture or reload is required for this UI request.

## Acceptance criteria

- Every existing checkbox/category has its own visibly separated section: Character, Bags, Character bank, Item details, Combat log, Quests, Reputation, Gold, Currencies, Honor, Titles.
- Every section owns its control and appropriate action, concise explanation of captured fields and limitations, exact automatic/manual scan triggers traced from source, current result, last attempt/trigger/time and last successful changed capture when known.
- Explain that enabled automated scanning works with the window closed; opening or navigating the dashboard must not initiate captures.
- Display useful, bounded counts from the current character's latest captured observations. Clearly label stored observations versus a new scan, history length versus latest tracked objects, partial visible lists, and account-wide versus character scope. Unknown/unavailable is not zero.
- Combat logging remains WoW-owned and has no invented addon-record count. Bank status must clearly describe the requirement for a visible own-character-bank view. Item metadata must distinguish bag/equipment and bank sources.
- All sections/statuses are discoverable in one dashboard via clear scrolling/navigation, rather than undiscoverable separate pages. Reserve title/close-button/footer space; wrap text at explicit widths, size sections for long statuses, and accommodate smaller viewports/UI scales.
- Preserve opt-in settings, manual semantics, storage formats and all current retry/queue behavior. Do not add gameplay automation, new scan categories, or consumer changes.
- Use mocked layout/geometry and behavioral tests on Lua 5.1/5.4; do not equate these with actual in-game font rendering. Independently review summary protections/ownership and UI scheduling before release.
- Update README, DATA_STORAGE and TODO in place, build a source-matched reproducible candidate, publish audited source and install only with WoW stopped and paired rollback/readback. Preserve player saves.

## Deferred validation

A later normal-play view verifies live rendering and scan statuses on 70245. It should not require repeated preflight commands or engineered PvP/title/currency activity. Existing source evidence (70205) and observed persistence (70235) remain separately labeled.
