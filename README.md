# MclarionWow

MclarionWow is a Forever-only, read-only character and inventory snapshot addon. Out of combat, it stores deduplicated character and own-bag snapshots in account-wide `MclarionWowData` SavedVariables, keeping at most 20 of each per character. Character capture runs on login, equipment/zone changes, after combat and every five minutes. Bag capture runs on login, coalesced bag updates, after combat and every five minutes. `/mhwow` and `/mhwowbagsexport` show selectable exports for review **after** local capture; reviewing is not a prerequisite for local storage. `/mhwowbags` remains a **count-only diagnostic** and changes no saved data. Bag snapshots are item-ID/count totals, not proven loot. The addon never automatically copies or sends data, inspects other players, or performs gameplay actions. The website does not yet accept bag exports.

## Use

1. Install the `MclarionWow` directory under the Forever client's `Interface/AddOns` directory for a supervised in-game test. A filesystem installation alone does not prove in-game compatibility.
2. Enable **MclarionWow** at character selection.
3. Log into a character and remain out of combat.
4. Type `/mhwow`.
5. Press **Ctrl+C** in the already-selected text box, then paste the export where you choose.
   For a separate inventory export, use `/mhwowbagsexport` out of combat. Review it before copying; the local bag snapshot is already recorded when the text appears. Do not paste it into the current website importer.
6. Log out or run `/reload` to let the game persist SavedVariables; the addon cannot force disk writes. The saved data is not read automatically by the website.

No export is produced during combat. The addon also refuses to export if the client marks any snapshot value—including an inventory item ID—as secret.

For each character, character and bag histories independently retain at most 20 distinct consecutive states, dropping the oldest when full. A new timestamp alone does not create an entry; pre-existing histories over the limit are left untouched and new captures are refused. Existing schema-1 SavedVariables gain an optional `bags` table without replacing character history. Automatic capture is local only and skips combat and protected values. The site still needs a player-reviewed manual import; refreshing the page does not read game files. WoW flushes SavedVariables on its own save/reload/logout lifecycle, not at each timer tick. Do not edit or remove the SavedVariables file while WoW is running; character restoration across a relaunch was observed on build 70170, but bag persistence still needs an in-client round trip.

## Export format

Exactly 12 pipe-separated fields:

`MHWOW1|forever|serverEpoch|playerGuid|name|realm|classFile|level|mapId|zone|gearCsv|build`

- `gearCsv` contains 19 nonnegative item IDs for inventory slots 1 through 19; an empty slot is `0`.
- Text bytes are escaped in this order: `%` → `%25`, `|` → `%7C`. Control characters are rejected.
- A missing best map is exported as `0`.
- The level and client build number (the second result of `GetBuildInfo`, not the interface number) must be positive integers in the website parser's range; the GUID and text fields must also fit the parser's limits. Character exports over 4,096 bytes are refused.

## Separate bag export format

`MHWOWB1|forever|serverEpoch|playerGuid|itemId:totalCount,...|build`

This six-field export lists only sorted, numeric item IDs and aggregated stack counts for the player's backpack and equipped bags 1–4. It contains no item names, links, slot positions, chat text, or acquisition source. Empty bags have an empty fifth field. A capture fails rather than truncating if the export exceeds 16,000 bytes, if any bag has more than 120 slots, or if an item value is protected or invalid. The existing `/wow` importer accepts only `MHWOW1` character exports, **not** this format.

## Local tests

The test uses mocked WoW APIs but executes the actual addon Lua file:

```sh
lua5.4 tests/test_mclarion_wow.lua MclarionWow.lua
```

It covers both export formats, combat and secret-value refusal, manual UI, automatic local capture, deduplication, bounded character/bag histories, and the count-only bag probe. Mock secret sentinels trap premature field access; the new bag storage still requires an in-client save/relaunch test.

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
10. Out of combat, run `/mhwowbagsexport`; confirm a selectable `MHWOWB1` text appears. Move an item between your own bags and repeat: aggregate totals should stay the same. If an item's total in your bags changes through normal play, only that item's total should change; `serverEpoch` may also advance. Do not paste the contents into chat or the website.
11. Log out cleanly, then verify the addon's own SavedVariables contains a bounded `bags` history; relaunch and confirm it survives. Do not inspect or edit the file while the client runs. If the addon shows a protection or storage error, stop and report only that message.

## Safety and policy caveats

- This addon reads only the logged-in player's non-secret UI data, out of combat, on supported local events, a five-minute interval, and explicit export commands. Bag capture records inventory totals, never a claim about how an item was acquired.
- It has no events that capture other players, no protected actions, no combat automation, no clipboard API, no arbitrary filesystem access, and no outbound traffic. WoW manages the account-wide SavedVariables file.
- Copying and transmitting the export is a manual user action. Review the destination's privacy and data-handling terms before sharing it.
- A matching TOC interface number does not replace an in-client compatibility test. Blizzard can change API behavior or secret-value restrictions; if the client refuses a value, the addon fails closed rather than attempting a workaround.
