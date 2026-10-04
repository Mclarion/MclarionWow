# MclarionWow

MclarionWow is a Forever-only, read-only addon for the logged-in character's non-secret data. `/mhwowui` opens its settings and status window. **All automatic features start off on first use**: character, own-bag and own-character-bank snapshots, cached item details, and native combat logging. Enable only the ones you want. Automatic captures use validated in-game APIs, run out of combat, and never switch bank pages or read account/Warband bank tabs. Bag and bank totals are not proof of an item's acquisition source.

Character snapshots run on login, equipment/zone changes, after combat, and every five minutes once opted in. Version 0.9.0 tries to include the logged-in player's faction, race and gender in a `MHWOW2` snapshot; when the identity APIs are unavailable, automatic capture falls back to the existing gear-only `MHWOW1` format. Bag snapshots run on login, bag opening/changes, after combat, and every five minutes once opted in. When the character-bank view is open, its opening, item changes, and player-selected bank pages check character-bank item-ID/count totals once opted in. Manual commands work independently of these switches: `/mhwow`, `/mhwowidentity` and `/mhwowbagsexport` also save their results to local histories when explicitly invoked; manual bank and metadata exports do not save a history. The addon does not upload data or write arbitrary TXT files; exports are copied only by the player to a destination they choose.

For the exact storage lifecycle, `MclarionWowData` keys, capture triggers, manual-export effects, and Mclarion-Main disk paths, see [DATA_STORAGE.md](DATA_STORAGE.md). Keep its `B:\MclarionWow-Data-README.md` handoff copy synchronized after changes.

**One-file item details (0.10.0):** the same game-written account SavedVariables file retains character, bag-total and own-bank-total histories. A separate **default-off** switch captures complete cached bag/equipment and visible own-character-bank metadata as bounded `MHWOWI1` strings in schema-2 `items[guid]` after opt-in. See [DATA_STORAGE.md](DATA_STORAGE.md#one-file-item-detail-contract-schema-2) for the contract and 4 MB upload constraint. After a live opt-in and clean game exit, a stopped-game, metadata-only check confirmed schema 2, an `items` section, and a bag-item payload marker; no own-bank item payload was present because that capture was not tested. This marker check is **not** parsed-record validation. The player then selected this real game-written file on the website and reported a green acceptance result; category contents and retry behavior remain unverified. Isolated website tests also accepted schemas 1 and 2, both synthetic bank-detail pages, and an idempotent re-import. Keep clipboard commands as fallback until real-save item-category parity is demonstrated; combat logs remain separate. Website import still requires deliberate file selection. A desktop EXE reader is separate policy-gated work.

A **synthetic, test-only** schema-2 file with two own-bank item pages is available at [`tests/schema2-synthetic.lua`](tests/schema2-synthetic.lua), with a fixture check in `tests/test_schema2_fixture.lua`, for parallel reader development. It is not a player save: never upload it to a production account.

**Real-file website check (player-reported, 2026-10-04):** the Add page accepted the game-written schema-2 save. The website showed 20 imported bag snapshots (latest displayed observation 2026-10-04 10:43 UTC) and one older bank snapshot (2026-10-03 20:43 UTC), all at build 70205. Its item table included a 33-distinct-ID/260-total row and a separate 0/0 row; the player reported visible item data and images. The meaning of the 0/0 row, metadata provenance, and category-by-category parity were not independently verified. No own-bank scan occurred during this new test, so no fresh bank details were expected. Unchanged bank totals also deduplicate rather than creating a new timestamp; opening the own-character bank while out of combat is still needed to test bank metadata capture.

**Bank test in progress:** on the next live bank-opening attempt, the UI reported `Bank: Capture unavailable: client refused the bank scan` and `Items: Capture unavailable: no complete cached item scan`. These are generic refusal statuses, not a diagnosed cause or evidence that the already saved bag details were erased. The player had not used **Bank (Manual)**; that command is not required for automatic capture. The next test is to select the **character-bank tab/page in the game's bank UI**, out of combat, then recheck both statuses before saving; the first opening event may precede an active own-bank view.

**Bank follow-up (player-reported):** clicking the bank's bag-icon tab changed **Bank** to `Captured in memory; disk update waits for logout or /reload`. After the player moved one item from a bag into the bank, **Items** also reported capture in memory. These UI statuses establish that the bank and item handlers ran, not which item source most recently set the shared Items status, a disk write, or website parity. Leave the game to save normally before a stopped-game, marker-only check for a bank-source item payload.

## Use

1. Install the `MclarionWow` directory under the Forever client's `Interface/AddOns` directory **while the client is closed**. The TOC targets interface `16001` and game type `camelot`; installation alone does not prove in-game compatibility.
2. Enable **MclarionWow** at character selection.
3. Log into a character, run `/mhwowui`, and explicitly enable your desired automatic captures. The combat-log switch asks WoW's own `LoggingCombat` API to enable its game-managed log at the **next world-entry event**. Switching off **auto-start** never stops logging already running: after a `/reload` the addon cannot reliably know who started it. To end the current log, explicitly click **Stop logging now**, which also turns off auto-start and may stop logging begun by you or another addon. The window reports in-memory capture, refused APIs, and when logging remains active. It does not prove a file exists until checked on the actual client.
4. Remain out of combat for capture. For own-bank totals, open the **character-bank tab** and confirm the UI reports a bank capture in memory; a bank probe or manual export does not save an automatic bank snapshot. If the client refuses, do not assume the bank was captured.
5. Run `/reload`, log out, or exit WoW so the game writes SavedVariables. On your signed-in website's WoW **Add** page, **you** select/drop the game-written `WTF/Account/<account>/SavedVariables/MclarionWow.lua` (not the addon source under `Interface/AddOns`). The remote website cannot read your local disk automatically. Its 4 MB limit applies; check its import result and category cards. Re-uploading the same file is safe, but an error may leave earlier snapshots imported.
6. Schema 1 covers character, bag totals and own-bank totals. In 0.10.0, enable **Capture own item details** in `/mhwowui` to save cached item metadata in schema 2; it does not backfill uncached names. Until an actual saved schema-2 file is imported and its item categories checked, use the temporary clipboard fallback below if needed. Native combat logs remain separate.

### Temporary clipboard fallback (legacy clients or missing item details)

- `/mhwowidentity` selects a versioned character export with faction/race/gender; `/mhwow` retains the original 12-field format. The command refuses unavailable/protected identity APIs instead of guessing. Copy only if your importer needs a manual character record.
- `/mhwowbagsexport` selects bag totals; `/mhwowitemsexport` selects bag/equipment item names/details (`MHWOWI1`). Review and paste each into its matching field on your own signed-in `/wow` page, never into chat.
- With your **own character bank** open and out of combat, `/mhwowbanksexport` selects totals (`MHWOWK1`); `/mhwowbankitemsexport` selects bank-only item metadata (`MHWOWI1`). If it reports additional pages, request `/mhwowbankitemsexport 2`, then later page numbers. The manual bank commands do not save bank history; the separate opted-in capture does. Never treat account/Warband-bank data as character-bank data.
- Press **Ctrl+C** only when you intentionally need a fallback. These commands remain for old importers and diagnostics; they are **not** the recommended normal import route once one-file item-detail parity is verified. No website or companion automatically receives clipboard text.

No export is produced during combat. The addon also refuses to export if the client marks any snapshot value—including an inventory item ID—as secret.

For each character, character, bag and bank histories independently retain at most 20 distinct consecutive states, dropping the oldest when full. A new timestamp alone does not create an entry; pre-existing malformed or over-limit histories remain untouched and new captures are refused. Automatic capture is local only, opt-in, and skips combat/protected values. The site still needs a player-reviewed manual import. WoW flushes SavedVariables on its own save/reload/logout lifecycle, not on each event; do not edit the file while WoW runs. The player confirmed settings persisted across `/reload` and restart; the post-exit bank marker establishes disk presence, not complete bank-history values or website category readback.

## Export format

The original `/mhwow` format has exactly 12 pipe-separated fields:

`MHWOW1|forever|serverEpoch|playerGuid|name|realm|classFile|level|mapId|zone|gearCsv|build`

The new `/mhwowidentity` format has exactly 15 fields; the first 12 have identical meaning:

`MHWOW2|forever|serverEpoch|playerGuid|name|realm|classFile|level|mapId|zone|gearCsv|build|faction|race|gender`

The trailing fields are the logged-in player's non-secret `UnitFactionGroup` result (`Alliance`, `Horde`, or `Neutral`), the locale-independent `UnitRace` token (ASCII letters), and `UnitSex` mapped to `Male`, `Female`, or `Unknown`. Neither command reads a targeted or nearby player. The new format requires an importer that explicitly accepts `MHWOW2`; the old format remains available.

- `gearCsv` contains 19 nonnegative item IDs for inventory slots 1 through 19; an empty slot is `0`.
- Text bytes are escaped in this order: `%` → `%25`, `|` → `%7C`. Control characters are rejected.
- A missing best map is exported as `0`.
- The level and client build number (the second result of `GetBuildInfo`, not the interface number) must be positive integers in the website parser's range; the GUID and text fields must also fit the parser's limits. Character exports over 4,096 bytes are refused.

## Separate bag export format

`MHWOWB1|forever|serverEpoch|playerGuid|itemId:totalCount,...|build`

This six-field export lists only sorted, numeric item IDs and aggregated stack counts for the player's backpack and equipped bags 1–4. It contains no item names, links, slot positions, chat text, or acquisition source. Empty bags have an empty fifth field. A capture fails rather than truncating if the export exceeds 16,000 bytes, if any bag has more than 120 slots, or if an item value is protected or invalid. The `/wow` page has separate character (`MHWOW1` or, after its importer is deployed, `MHWOW2`) and bag (`MHWOWB1`) import fields; it does not read game files automatically.

## Character-bank item totals (0.8.0)

`MHWOWK1|forever|serverEpoch|playerGuid|tabId:itemId:totalCount,...|build`

This six-field format is produced when the player explicitly runs `/mhwowbanksexport` while their own character bank is viewable and out of combat, or stored only in SavedVariables by the opted-in automatic own-bank handler. Entries aggregate stacks by item ID **within each tab** and are sorted first by numeric tab ID, then by numeric item ID. Empty bank contents leave the fifth field empty. Only purchased character-bank tab IDs 6–14 are accepted; account-bank tab IDs 15–23, duplicate IDs, sparse/malformed tab lists, protected values, unavailable APIs, invalid metadata, more than 120 slots per tab, per-item total overflow, more than 1,080 entries, or output over 32,768 bytes cause the complete export/capture to be refused rather than partially returned.

The manual command opens selected text for review and copying; it does not itself save bank data. The separate opted-in event handler stores only bounded character-bank totals in `MclarionWowData.bank`, while the character-bank view is open. No bank data is automatically transferred. `/mhwowbankprobe` remains a separate count-only diagnostic with unchanged behavior.

## Separate item metadata export (0.6.0)

`MHWOWI1|forever|serverEpoch|playerGuid|build|locale|entries`

Each `;`-separated entry has 19 colon-separated fields: item ID, name, link, quality, item level, minimum level, type, subtype, maximum stack, equip location, icon file ID, sell price (copper), class ID, subclass ID, bind type, expansion ID, nullable set ID, crafting-reagent flag (`0`/`1`), and description. Text fields are hex-encoded UTF-8 bytes, so copied links are **data**, never executable UI markup. Entries are for distinct IDs observed in this character's own bags 0–4 or equipped slots 1–19, sorted numerically. Cache misses are omitted rather than given made-up names. Up to 128 distinct observed IDs and 32,768 bytes are allowed; if limits, protection checks, or field validation fail, the entire export is refused. No item names or other metadata are persisted by this command. Icons are exported only as game file IDs, **not** assumed website image URLs. An item ID identifies a base item, not how it was acquired or necessarily its specific enchant/variant. The website importer accepts this format in its separate item-metadata field; both capture and transfer remain manual.

### Manual character-bank metadata pages (0.7.0)

`/mhwowbankitemsexport [page]` uses the same `MHWOWI1` serialization and validation as `/mhwowitemsexport`, but its ID source is only the explicitly scanned, currently viewable own character bank. The command accepts page numbers 1–9 and defaults to page 1. Distinct bank item IDs are sorted numerically and split into pages of at most 128 IDs, so all 1,080 possible occupied bank slots remain addressable without changing the `MHWOWI1` contract. The popup title reports the selected page and total page count. Import each available page separately; a page with only uncached names or an encoded result over 32,768 bytes is refused rather than truncated.

The bank must remain open for every metadata page. Combat, a closed bank, account-bank or malformed tabs, protected values, invalid page text, and invalid item metadata fail closed and replace any stale popup contents with a refusal. This **metadata command** never writes names or icons to SavedVariables; the separate default-off automatic item-details switch can save complete cached metadata when the own bank is viewable.

## Local tests

The test uses mocked WoW APIs but executes the actual addon Lua file:

```sh
(cd tests && lua5.4 test_mclarion_wow.lua)
```

It covers `MHWOW1`, `MHWOW2` and bag/bank/item formats, manual exports, combat/protected-value refusal, first-run opt-in, bounded histories, native logging safeguards, own-bank capture and schema-2 migration, complete metadata pages, cache misses and malformed records (300 assertions). Mock secret sentinels trap premature field access. `tests/test_schema2_fixture.lua` validates the generated synthetic two-page save. A prior 0.9.0 settings/identity/bank-marker round trip was reported in-game; 0.10.0 still needs an actual save/restart and website category check. See [TODO.md](TODO.md).

## Manual client test checklist

Use only a compatible Forever client whose interface number is `16001`:

1. Confirm the addon appears without enabling “Load out of date AddOns.” Run `/mhwowui`, verify all five automatic options start off on a fresh profile (existing settings remain unchanged), and enable only the captures you want. After opting into combat logging, use a new world-entry event and confirm the window reports WoW's logging status; inspect the game-produced log separately. Turn off auto-start and verify an active log remains on, even across `/reload`. Only the separately clicked **Stop logging now** button should stop that log, including a log started outside this addon; it also disables future auto-start.
2. Out of combat, run `/mhwow`; verify the window opens with selected text.
3. Press Ctrl+C and paste into a plain-text editor; verify there are exactly 11 pipe delimiters and 19 comma-separated gear IDs.
4. Equip and unequip an item, rerun `/mhwow`, and verify the expected gear CSV slot changes (an empty slot should be `0`); the `serverEpoch` field may also advance.
5. Enter combat and run `/mhwow`; verify the box reports that export is unavailable and contains no snapshot.
6. Leave combat and rerun `/mhwow`; verify a fresh snapshot is shown.
7. Verify Escape closes the export window.
8. Run `/reload`, reopen `/mhwowui`, and confirm enabled settings and the addon's character history remain in `MclarionWowData` after a clean logout; inspect only this addon's SavedVariables entry, not account credentials or other addon data. Repeat after a full client restart before claiming persistent automatic capture.
9. Out of combat, run `/mhwowbags`. Expect a chat message with counts of bag slots, occupied slots, and distinct item types, **not** item IDs. If it says an API or value is unavailable/protected, stop and report only the message. In combat it should refuse. This probe changes no SavedVariables and does not transfer inventory to the website.
10. Out of combat, run `/mhwowbagsexport`; confirm a selectable `MHWOWB1` text appears. Move an item between your own bags and repeat: aggregate totals should stay the same. If an item's total in your bags changes through normal play, only that item's total should change; `serverEpoch` may also advance. Do not paste the contents into chat; use only your signed-in `/wow` bag importer.
11. Log out cleanly, then verify the addon's own SavedVariables contains a bounded `bags` history; relaunch and confirm it survives. Do not inspect or edit the file while the client runs. If the addon shows a protection or storage error, stop and report only that message.
12. Out of combat, run `/mhwowitemsexport`; confirm the text begins with `MHWOWI1`. If the client cache has no names or a value is protected, report only the refusal message. Review the export and paste it into your own `/wow` item-metadata field, not chat or the bag field. Missing cached items should continue to show numeric IDs on the site.
13. At your **own character bank**, with the bank window open and out of combat, run `/mhwowbankprobe`. It must still open a selected, copyable count-only report of purchased character-bank tabs, slots, occupied slots and distinct item IDs, without exposing item IDs or changing SavedVariables. If it refuses an API, protected value, or tab ID, stop and report only the refusal message; do not attempt a workaround.
14. With the same own character bank open and out of combat, run `/mhwowbanksexport`. Confirm selected text begins with `MHWOWK1|forever|`, contains exactly six pipe-separated fields, and lists `tabId:itemId:totalCount` entries sorted by tab then item ID. Move an item between two character-bank tabs and repeat: the entry must move between tab IDs rather than being merged across tabs. With **automatic bank capture disabled**, the manual command creates no `bank` history; after enabling it, open the own-character-bank view and manually select a page, then verify a bounded `bank` history only after logout or `/reload`. Close the bank or enter combat and verify the manual command refuses without showing stale export text. Do not test account-bank tabs and do not paste the export into chat.
15. With the own character bank open and out of combat, run `/mhwowbankitemsexport`. Confirm selected text begins with `MHWOWI1|forever|` and the title reports page 1 of the available pages. If more pages exist, run `/mhwowbankitemsexport 2` and continue in order. The manual command never stores metadata. With the separate item-details switch enabled and a complete cached scan, schema-2 `items[guid].bank` should hold all pages after a WoW save; verify category parity on a deliberately selected file upload. Close the bank and repeat the command: the prior export must be replaced by a refusal.

## Safety and policy caveats

- This addon reads only the logged-in player's non-secret UI data, out of combat, on supported local events, a five-minute interval, and explicit export commands. Bag capture records inventory totals, never a claim about how an item was acquired.
- It has no events that capture other players, no protected actions, no combat automation, no clipboard API, no arbitrary filesystem access, and no outbound traffic. WoW manages the account-wide SavedVariables file.
- Copying and transmitting the export is a manual user action. Review the destination's privacy and data-handling terms before sharing it.
- A matching TOC interface number does not replace an in-client compatibility test. Blizzard can change API behavior or secret-value restrictions; if the client refuses a value, the addon fails closed rather than attempting a workaround.
- The character-bank probe remains manual and count-only. The separate bank-total and paged bank-metadata *copy commands* are manual-only and never write to SavedVariables themselves. Independently opted-in handlers may retain bounded character-bank **numeric totals** and complete cached item metadata when the player's own character-bank view opens or a page is selected. They do not access account-bank tab IDs.
- `MHWOWK1` is a transfer string, not a claim about item acquisition or ownership beyond what the logged-in client's currently viewable character bank reports. Keep it private, review it before copying, and use only a destination that explicitly supports this versioned contract.
