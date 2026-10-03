# MclarionWow

MclarionWow is a Forever-only, read-only character and inventory snapshot addon. Out of combat, it stores deduplicated character and own-bag snapshots in account-wide `MclarionWowData` SavedVariables, keeping at most 20 of each per character. Character capture runs on login, equipment/zone changes, after combat and every five minutes. Bag capture runs on login, coalesced bag updates, after combat and every five minutes. `/mhwow` and `/mhwowbagsexport` show selectable exports for review **after** local capture; reviewing is not a prerequisite for local storage. `/mhwowbags` and `/mhwowbankprobe` are **count-only diagnostics** and change no saved data. `/mhwowbanksexport` is a separate, manual-only export of item totals from the logged-in character's own purchased, currently viewable bank tabs. `/mhwowbankitemsexport [page]` manually exports `MHWOWI1` names and icon file IDs for those bank-only item IDs in bounded pages. Neither bank command writes bank data to SavedVariables or runs through automatic capture. Bag snapshots are item-ID/count totals, not proven loot. The addon never automatically copies or sends data, inspects other players, or performs gameplay actions. Exports are copied only by the player to a destination they choose.

## Use

1. Install the `MclarionWow` directory under the Forever client's `Interface/AddOns` directory for a supervised in-game test. A filesystem installation alone does not prove in-game compatibility.
2. Enable **MclarionWow** at character selection.
3. Log into a character and remain out of combat.
4. Type `/mhwow`.
5. Press **Ctrl+C** in the already-selected text box, then paste the export where you choose.
   For a separate inventory export, use `/mhwowbagsexport` out of combat. Review it before copying; the local bag snapshot is already recorded when the text appears. Paste it only into your own `/wow` bag inventory field after importing the matching character; never share exports in chat.
   `/mhwowitemsexport` is a **new, separate manual export** of metadata for item IDs currently observed in your own bags and equipment. It does not alter or automatically upload either inventory or SavedVariables. Paste it only into the separate item-metadata field on your signed-in `/wow` page after importing the matching character; never use the bag field.
   At your own character bank, keep the bank window open, remain out of combat, and use `/mhwowbanksexport` for a separate manual export. Review the selected `MHWOWK1` text before copying it. The command reads only purchased character-bank tab IDs 6–14, refuses account-bank tabs 15–23, writes no bank data to SavedVariables, and has no automatic event or timer path. Paste it only into an importer that explicitly documents the `MHWOWK1` contract; never paste exports into chat.
   To resolve names and art for IDs found only in that bank, run `/mhwowbankitemsexport` while the same bank remains open. If the title reports more than one page, repeat with `/mhwowbankitemsexport 2`, then page 3, and so on. Each page is an ordinary `MHWOWI1` export suitable for the same item-metadata importer as `/mhwowitemsexport`; it does not include bag/equipment IDs unless they are also present in the bank.
6. Log out or run `/reload` to let the game persist SavedVariables; the addon cannot force disk writes. The saved data is not read automatically by the website.

No export is produced during combat. The addon also refuses to export if the client marks any snapshot value—including an inventory item ID—as secret.

For each character, character and bag histories independently retain at most 20 distinct consecutive states, dropping the oldest when full. A new timestamp alone does not create an entry; pre-existing histories over the limit are left untouched and new captures are refused. Existing schema-1 SavedVariables gain an optional `bags` table without replacing character history. Automatic capture is local only and skips combat and protected values. The site still needs a player-reviewed manual import; refreshing the page does not read game files. WoW flushes SavedVariables on its own save/reload/logout lifecycle, not at each timer tick. Do not edit or remove the SavedVariables file while WoW is running; character restoration across a relaunch was observed on build 70170, and bag snapshots survived `/reload` and logout on the tested client. A full-restart bag-persistence check remains outstanding.

## Export format

Exactly 12 pipe-separated fields:

`MHWOW1|forever|serverEpoch|playerGuid|name|realm|classFile|level|mapId|zone|gearCsv|build`

- `gearCsv` contains 19 nonnegative item IDs for inventory slots 1 through 19; an empty slot is `0`.
- Text bytes are escaped in this order: `%` → `%25`, `|` → `%7C`. Control characters are rejected.
- A missing best map is exported as `0`.
- The level and client build number (the second result of `GetBuildInfo`, not the interface number) must be positive integers in the website parser's range; the GUID and text fields must also fit the parser's limits. Character exports over 4,096 bytes are refused.

## Separate bag export format

`MHWOWB1|forever|serverEpoch|playerGuid|itemId:totalCount,...|build`

This six-field export lists only sorted, numeric item IDs and aggregated stack counts for the player's backpack and equipped bags 1–4. It contains no item names, links, slot positions, chat text, or acquisition source. Empty bags have an empty fifth field. A capture fails rather than truncating if the export exceeds 16,000 bytes, if any bag has more than 120 slots, or if an item value is protected or invalid. The `/wow` page has separate character (`MHWOW1`) and bag (`MHWOWB1`) import fields; it does not read game files automatically.

## Manual character-bank item export (0.7.0)

`MHWOWK1|forever|serverEpoch|playerGuid|tabId:itemId:totalCount,...|build`

This six-field export is produced only when the player explicitly runs `/mhwowbanksexport` while their own character bank is viewable and they are out of combat. Entries aggregate stacks by item ID **within each tab** and are sorted first by numeric tab ID, then by numeric item ID. Empty bank contents leave the fifth field empty. Only purchased character-bank tab IDs 6–14 are accepted; account-bank tab IDs 15–23, duplicate IDs, sparse/malformed tab lists, protected values, unavailable APIs, invalid metadata, more than 120 slots per tab, per-item total overflow, more than 1,080 entries, or output over 32,768 bytes cause the complete export to be refused rather than partially returned.

The command opens selected text for manual review and copying. It does not save bank items or the export in `MclarionWowData`, does not add any bank event or timer capture, does not read account-bank tabs, and does not transfer anything automatically. The existing `/mhwowbankprobe` remains a separate count-only diagnostic with unchanged behavior.

## Separate item metadata export (0.6.0)

`MHWOWI1|forever|serverEpoch|playerGuid|build|locale|entries`

Each `;`-separated entry has 19 colon-separated fields: item ID, name, link, quality, item level, minimum level, type, subtype, maximum stack, equip location, icon file ID, sell price (copper), class ID, subclass ID, bind type, expansion ID, nullable set ID, crafting-reagent flag (`0`/`1`), and description. Text fields are hex-encoded UTF-8 bytes, so copied links are **data**, never executable UI markup. Entries are for distinct IDs observed in this character's own bags 0–4 or equipped slots 1–19, sorted numerically. Cache misses are omitted rather than given made-up names. Up to 128 distinct observed IDs and 32,768 bytes are allowed; if limits, protection checks, or field validation fail, the entire export is refused. No item names or other metadata are persisted by this command. Icons are exported only as game file IDs, **not** assumed website image URLs. An item ID identifies a base item, not how it was acquired or necessarily its specific enchant/variant. The website importer accepts this format in its separate item-metadata field; both capture and transfer remain manual.

### Manual character-bank metadata pages (0.7.0)

`/mhwowbankitemsexport [page]` uses the same `MHWOWI1` serialization and validation as `/mhwowitemsexport`, but its ID source is only the explicitly scanned, currently viewable own character bank. The command accepts page numbers 1–9 and defaults to page 1. Distinct bank item IDs are sorted numerically and split into pages of at most 128 IDs, so all 1,080 possible occupied bank slots remain addressable without changing the `MHWOWI1` contract. The popup title reports the selected page and total page count. Import each available page separately; a page with only uncached names or an encoded result over 32,768 bytes is refused rather than truncated.

The bank must remain open for every page. Combat, a closed bank, account-bank or malformed tabs, protected values, invalid page text, and invalid item metadata fail closed and replace any stale popup contents with a refusal. The command has no event/timer path and never writes names, icons, bank IDs, or exports to SavedVariables.

## Local tests

The test uses mocked WoW APIs but executes the actual addon Lua file:

```sh
lua5.4 tests/test_mclarion_wow.lua MclarionWow.lua
```

It covers the four wire formats and five export commands, including paged bank-only `MHWOWI1` metadata, combat and secret-value refusal, manual UI, stale-popup replacement, automatic local capture, deduplication, bounded character/bag histories, the count-only probes, character-bank tab/entry/length bounds, no bank SavedVariables writes, and confirmation that automatic capture never invokes bank scanning. Mock secret sentinels trap premature field access; a full-client-relaunch check of bag persistence remains outstanding.

## Manual client test checklist

Use only a compatible Forever client whose interface number is `16001`:

1. Confirm the addon appears without enabling “Load out of date AddOns.”
2. Out of combat, run `/mhwow`; verify the window opens with selected text.
3. Press Ctrl+C and paste into a plain-text editor; verify there are exactly 11 pipe delimiters and 19 comma-separated gear IDs.
4. Equip and unequip an item, rerun `/mhwow`, and verify the expected gear CSV slot changes (an empty slot should be `0`); the `serverEpoch` field may also advance.
5. Enter combat and run `/mhwow`; verify the box reports that export is unavailable and contains no snapshot.
6. Leave combat and rerun `/mhwow`; verify a fresh snapshot is shown.
7. Verify Escape closes the export window.
8. Run `/reload`, reopen `/mhwow`, and confirm the prior character history remains in `MclarionWowData` after a clean logout; inspect only this addon's SavedVariables entry, not account credentials or other addon data.
9. Out of combat, run `/mhwowbags`. Expect a chat message with counts of bag slots, occupied slots, and distinct item types, **not** item IDs. If it says an API or value is unavailable/protected, stop and report only the message. In combat it should refuse. This probe changes no SavedVariables and does not transfer inventory to the website.
10. Out of combat, run `/mhwowbagsexport`; confirm a selectable `MHWOWB1` text appears. Move an item between your own bags and repeat: aggregate totals should stay the same. If an item's total in your bags changes through normal play, only that item's total should change; `serverEpoch` may also advance. Do not paste the contents into chat; use only your signed-in `/wow` bag importer.
11. Log out cleanly, then verify the addon's own SavedVariables contains a bounded `bags` history; relaunch and confirm it survives. Do not inspect or edit the file while the client runs. If the addon shows a protection or storage error, stop and report only that message.
12. Out of combat, run `/mhwowitemsexport`; confirm the text begins with `MHWOWI1`. If the client cache has no names or a value is protected, report only the refusal message. Review the export and paste it into your own `/wow` item-metadata field, not chat or the bag field. Missing cached items should continue to show numeric IDs on the site.
13. At your **own character bank**, with the bank window open and out of combat, run `/mhwowbankprobe`. It must still open a selected, copyable count-only report of purchased character-bank tabs, slots, occupied slots and distinct item IDs, without exposing item IDs or changing SavedVariables. If it refuses an API, protected value, or tab ID, stop and report only the refusal message; do not attempt a workaround.
14. With the same own character bank open and out of combat, run `/mhwowbanksexport` (0.7.0). Confirm selected text begins with `MHWOWK1|forever|`, contains exactly six pipe-separated fields, and lists `tabId:itemId:totalCount` entries sorted by tab then item ID. Move an item between two character-bank tabs and repeat: the entry must move between tab IDs rather than being merged across tabs. Confirm the command creates no `banks` or equivalent key in `MclarionWowData`. Close the bank or enter combat and verify the command refuses without showing stale export text. Do not test account-bank tabs and do not paste the export into chat.
15. With the own character bank open and out of combat, run `/mhwowbankitemsexport`. Confirm selected text begins with `MHWOWI1|forever|` and the title reports page 1 of the available pages. If more pages exist, run `/mhwowbankitemsexport 2` and continue in order. Import every page through the item-metadata field; verify a bank-only item gains its cached name/icon metadata. Close the bank and repeat: the prior export must be replaced by a refusal. Confirm no bank metadata appears in `MclarionWowData`.

## Safety and policy caveats

- This addon reads only the logged-in player's non-secret UI data, out of combat, on supported local events, a five-minute interval, and explicit export commands. Bag capture records inventory totals, never a claim about how an item was acquired.
- It has no events that capture other players, no protected actions, no combat automation, no clipboard API, no arbitrary filesystem access, and no outbound traffic. WoW manages the account-wide SavedVariables file.
- Copying and transmitting the export is a manual user action. Review the destination's privacy and data-handling terms before sharing it.
- A matching TOC interface number does not replace an in-client compatibility test. Blizzard can change API behavior or secret-value restrictions; if the client refuses a value, the addon fails closed rather than attempting a workaround.
- The character-bank probe remains manual and count-only. The separate bank total and paged bank metadata exports are also manual-only, read only purchased character-bank tabs while the client reports them viewable, reject account-bank tab IDs, and never write bank data to SavedVariables. None of these commands is called by automatic capture.
- `MHWOWK1` is a transfer string, not a claim about item acquisition or ownership beyond what the logged-in client's currently viewable character bank reports. Keep it private, review it before copying, and use only a destination that explicitly supports this versioned contract.
