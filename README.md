# MclarionWow

Forever-only, read-only addon for the logged-in character. **0.11.0 removes manual copy/paste exports** and places a 30px clickable icon at the lower-left edge of the minimap. Click it to open/close the settings/status window; `/mhwowui` remains the keyboard fallback. Published code was installed and its hashes read back while WoW was closed; the player subsequently confirmed the icon is present and works in game. Existing SavedVariables and wire formats are preserved.

## Use the game-written file

1. Install `MclarionWow` under Forever's `Interface/AddOns` **while WoW is closed**. The TOC targets interface `16001` and `camelot`.
2. Click the minimap icon or use `/mhwowui`; explicitly enable the categories you want. All five switches default **off** for a new profile: character, bag, own-character-bank, cached item details, and native combat logging. Existing preferences are preserved. Capture is out of combat and fails closed on secret/protected values. Select the character-bank tab to allow own-bank scans; account/Warband bank tabs are never captured.
3. WoW writes `MclarionWowData` to the account SavedVariables `MclarionWow.lua` only on `/reload`, logout or exit. **The addon cannot upload data or create a TXT file.** Deliberately select the *game-written* file (not the addon source) in the signed-in website's Add page or the client's manual import. The remote website cannot read your disk automatically. Its 4 MB limit and per-category import results still matter.
4. `/mhwowbags` and `/mhwowbankprobe` remain **count-only chat diagnostics**; they do not copy item IDs or store captures. `Stop logging now` is a separate explicit UI action that may also end combat logging started outside this addon. Native combat logs remain separate game-owned files.

**Removed in 0.11.0:** the Character/Bags/Bank copy buttons, selected-text popup, `/mhwow`, `/mhwowidentity`, `/mhwowbagsexport`, `/mhwowitemsexport`, `/mhwowbanksexport` and `/mhwowbankitemsexport`. Their formats are still built internally for the opted-in automatic captures. No database migration or item recapture is required by removing the copy UI. Older website copy fields are not an addon feature.

## Persisted contract

- `characters[guid]`: up to 20 deduplicated `MHWOW2` snapshots (faction, race, gender included when available), falling back to `MHWOW1` on unavailable identity APIs; equipment contains 19 numeric item IDs.
- `bags[guid]`: up to 20 deduplicated `MHWOWB1` own-bag total snapshots; `bank[guid]`: up to 20 deduplicated `MHWOWK1` own-character-bank tab totals. No item slots, acquisition sources or cross-character bank guesses are invented.
- Schema 2 `items[guid] = {bags = <MHWOWI1>, bank = {<MHWOWI1 pages>}}` retains complete, cached bag/equipment and viewable own-bank item details after **separate opt-in**. Each item includes a validated numeric texture file ID, **not icon image bytes**; cache misses are omitted rather than given invented names. A failed/incomplete scan leaves the earlier valid metadata intact. Bank pages are bounded to 128 distinct IDs and nine pages. Both implicit Lua arrays and explicit numeric keys represent the same ordered pages; see paired synthetic fixtures in `tests/`.
- `settings` retains five opt-in booleans; schema-1 history is preserved when migrating to schema 2 after a successful item capture. Automatic character, bag and item capture reacts to own events and a five-minute retry. No automatic external file reader, upload, quest/profession collection or combat-log parser is part of this addon.

The player reported a real schema-2 website round trip with bag and bank metadata/icons and a repeat upload yielding **0 new snapshots, 71 unchanged, no errors**. A later per-character client metadata gap was fixed by the player selecting an updated file. These are player reports, not an independent audit of every record; the website thread owns remaining parser/category checks. `DATA_STORAGE.md` is the maintained storage/import handoff, mirrored to `B:\MclarionWow-Data-README.md` after releases. Never publish actual SavedVariables or player/item identifiers.

## Local validation

Run from this directory: `(cd tests && lua5.4 test_mclarion_wow.lua)`. The Lua mock suite checks automatic capture, bounds, schema-2 preservation, secret-value refusals, removed commands, and minimap toggling (242 assertions). Paired synthetic schema-2 fixture tests cover implicit and explicit bank arrays; fixtures are fake test data, **not** production account uploads. The player confirmed the 0.11.0 minimap icon is present and clickable in game; post-upgrade save/reimport and visual confirmation of all five settings were not separately reported.

## Safety and later work

Blizzard may change Forever APIs or secret-value behavior; an interface number and mock tests do not prove every game behavior. Do not inspect a live SavedVariables payload while WoW is running. Unattended external readers or transmission are **not** authorized simply by this addon design and remain policy-gated. Planned next: independently verified, bounded opt-in progression sources (zone, quest/reputation, talent and profession/recipe observations) and separate native-log validation. See `TODO.md`; none of those sources are currently captured.
