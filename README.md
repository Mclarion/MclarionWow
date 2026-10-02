# MclarionWow

MclarionWow is a Forever-only, read-only character snapshot addon. On explicit `/mhwow`, it saves a snapshot in account-wide `MclarionWowData` SavedVariables and shows the same export in a selectable box. It does not copy automatically, send data, inspect other players, or perform gameplay actions.

## Use

1. Install the `MclarionWow` directory under the Forever client's `Interface/AddOns` directory for a supervised in-game test. A filesystem installation alone does not prove in-game compatibility.
2. Enable **MclarionWow** at character selection.
3. Log into a character and remain out of combat.
4. Type `/mhwow`.
5. Press **Ctrl+C** in the already-selected text box, then paste the export where you choose.
6. Log out or run `/reload` to let the game persist SavedVariables; the addon cannot force disk writes. The saved data is not read automatically by the website.

No export is produced during combat. The addon also refuses to export if the client marks any snapshot value—including an inventory item ID—as secret.

For each character, local history retains at most 20 distinct consecutive snapshots, dropping the oldest when full. Repeated copies of an unchanged export do not add another entry. No capture happens in the background: `/mhwow` explicitly collects and stores the current character. Do not edit or remove the SavedVariables file while WoW is running; in-client persistence on the Forever beta build still needs testing.

## Export format

Exactly 12 pipe-separated fields:

`MHWOW1|forever|serverEpoch|playerGuid|name|realm|classFile|level|mapId|zone|gearCsv|build`

- `gearCsv` contains 19 nonnegative item IDs for inventory slots 1 through 19; an empty slot is `0`.
- Text bytes are escaped in this order: `%` → `%25`, `|` → `%7C`. Control characters are rejected.
- A missing best map is exported as `0`.
- The level and client build number (the second result of `GetBuildInfo`, not the interface number) must be positive integers, and the GUID must begin with `Player-`.

## Local tests

The test uses mocked WoW APIs but executes the actual addon Lua file:

```sh
lua5.4 tests/test_mclarion_wow.lua MclarionWow.lua
```

It covers the export contract, validation, combat and secret-value refusal, manual UI, deduplication, and the bounded local history.

## Manual client test checklist

Use only a compatible Forever client whose interface number is `16001`:

1. Confirm the addon appears without enabling “Load out of date AddOns.”
2. Out of combat, run `/mhwow`; verify the window opens with selected text.
3. Press Ctrl+C and paste into a plain-text editor; verify there are exactly 11 pipe delimiters and 19 comma-separated gear IDs.
4. Equip and unequip an item, rerun `/mhwow`, and verify only the expected gear slot changes (an empty slot should be `0`).
5. Enter combat and run `/mhwow`; verify the box reports that export is unavailable and contains no snapshot.
6. Leave combat and rerun `/mhwow`; verify a fresh snapshot is shown.
7. Verify Escape closes the export window.
8. Run `/reload`, reopen `/mhwow`, and confirm the prior character history remains in `MclarionWowData` after a clean logout; inspect only this addon's SavedVariables entry, not account credentials or other addon data.

## Safety and policy caveats

- This addon only reads the logged-in player's own public UI data on explicit `/mhwow` use.
- It has no events that capture other players, no protected actions, no combat automation, no clipboard API, no arbitrary filesystem access, and no outbound traffic. WoW manages the account-wide SavedVariables file.
- Copying and transmitting the export is a manual user action. Review the destination's privacy and data-handling terms before sharing it.
- A matching TOC interface number does not replace an in-client compatibility test. Blizzard can change API behavior or secret-value restrictions; if the client refuses a value, the addon fails closed rather than attempting a workaround.
