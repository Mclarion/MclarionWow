# MclarionWow: how data is produced and stored

**Status: 3 October 2026.** This describes the published **0.9.0** addon source and live behavior verified so far. The installed Lua and TOC matched public source hashes. In Forever Beta, the player obtained a complete `MHWOW2` manual export (`Alliance|Dwarf|Male`, build `70205`) and a backward-compatible `MHWOW1` export. After the first game session closed, a read-only, redacted inspection confirmed WoW wrote schema 1, four `true` settings, and `MHWOW1`, `MHWOW2`, and `MHWOWB1` markers. No `bank` key or `MHWOWK1` marker was found. In a subsequent live session the player confirmed addon 0.9.0 loaded, `/mhwowui` opened without errors, all four switches and Debugging remained on after a **full game restart and `/reload`**. This verifies UI/settings persistence as reported by the player, not another on-disk history inspection, bank capture, or a website import. Keep this document current with changes to formats, triggers, storage, importers, or deployment. The matching handoff copy is `B:\MclarionWow-Data-README.md` on Mclarion-Main. Do not insert actual exports, GUIDs, names, account directories, SavedVariables contents, or combat-log lines here.

## The three separate data paths

1. **Addon SavedVariables (local snapshots/settings).** The TOC declares `## SavedVariables: MclarionWowData`. The addon assigns a Lua table in memory. **World of Warcraft**, not addon Lua, serializes it to a file on its own `/reload` / logout / exit save cycle. The addon cannot force an immediate disk write when a bag/bank opens and cannot create arbitrary TXT/JSON/CSV files.
2. **Manual copy/paste exports.** A slash command can show a validated, selected text string for the player to inspect and copy with Ctrl+C. Showing an export is not an upload; only the player can paste it into a separately authorized importer. Some manual commands also store a local snapshot; see the table below. No website or desktop app is wired to read `MclarionWowData` automatically.
3. **WoW native combat log.** If the first-run-off combat logging option is explicitly enabled, the addon calls WoW's `LoggingCombat` API on the next world entry. WoW writes its own `Logs\WoWCombatLog-*.txt` file. That file is not an addon export and is **not** saved inside `MclarionWowData`. Turning off auto-start does not stop a log already running. The separate **Stop logging now** button can stop logging even if the player or another addon started it; its UI warns about this.

## Files on Mclarion-Main

- Installed addon code: `B:\Blizzard\World of Warcraft\_classic_beta_\Interface\AddOns\MclarionWow\MclarionWow.lua` and `MclarionWow.toc`. These are **code**, not character data. The TOC targets interface `16001`, game type `camelot`, version `0.9.0`.
- Addon-owned SavedVariables: `B:\Blizzard\World of Warcraft\_classic_beta_\WTF\Account\<account>\SavedVariables\MclarionWow.lua`. `<account>` is a private directory component. After the 0.9.0 session, the file had a fresh write time of **2026-10-03 19:20:10 UTC** and contained schema 1, all four enabled settings, and character/bag format markers. This does not prove a `/reload` round trip or that every capture type survived a restart.
- Game-owned combat logs: `B:\Blizzard\World of Warcraft\_classic_beta_\Logs\WoWCombatLog-*.txt` when native logging is active. The newest matching file had a write time of **2026-10-03 19:20:10 UTC** after the game closed; no log lines were inspected, so its contents and the logger's start/stop behavior remain unverified. `QuestCache.log` and `Professions.log`, if present, are also game files, **not** produced by this addon.
- This documentation: `B:\MclarionWow-Data-README.md` (outside the WoW installation). It records non-identifying verification results, not player exports or raw observations.

Do not open, parse, edit, or replace the live SavedVariables file while WoW is running. When auditing after a clean exit, first check only the addon file's presence, size, modification time, schema, and expected top-level keys; avoid displaying player payloads or other account data. Back it up before any migration. WoW's serialization format is Lua, not the pipe-separated manual-export format.

## In-memory schema (schema 1)

`MclarionWowData` is one **account-wide** SavedVariables table, indexed by the character's `Player-...` GUID for histories:

| Key | Contents | How it is populated |
| --- | --- | --- |
| `schema` | Integer `1` | Created with the root table. Unsupported pre-existing schemas are rejected, not silently replaced. |
| `settings` | Four booleans: `autoCombatLog`, `autoCharacterCapture`, `autoBagCapture`, `autoBankCapture` | `/mhwowui`; **all default to `false`** on first use. A combat-log preference is not the combat-log contents. |
| `characters[guid]` | Up to **20** character export strings, `MHWOW1` or `MHWOW2` | Manual `/mhwow` or `/mhwowidentity`, or opted-in character capture. |
| `bags[guid]` | Up to **20** `MHWOWB1` strings | Manual `/mhwowbagsexport` or opted-in bag capture. |
| `bank[guid]` | Up to **20** `MHWOWK1` strings of numeric character-bank totals | **Only** opted-in automatic capture while the own character-bank view is available. The manual bank commands do not populate it. |

The `bags` and `bank` maps may be absent until their first successful capture. Consecutive snapshots whose meaningful fields did not change are deduplicated **ignoring the capture timestamp**; a changed state appends a new string and, when full, removes the oldest. It is not a complete chronological event log: intermediate changes can be missed, earlier observations age out, and bag-count increases do not identify loot. Malformed/protected/over-limit existing histories are refused instead of repaired or overwritten. Names and item metadata are **not** automatically stored separately in SavedVariables.

## Capture triggers and opt-in

- **Character:** when enabled, attempts an out-of-combat capture at world entry, equipment or zone change, post-combat, and a five-minute timer. It tries `MHWOW2` identity fields and falls back to `MHWOW1` if those APIs cannot provide them; it does not scan other players.
- **Bags:** when enabled, scans the player's bag IDs **0–4** on world entry, delayed bag update, a valid own-bag open, post-combat, and the five-minute timer. Totals aggregate stacks by numeric item ID across these bags; no slot layout or acquisition source is stored.
- **Bank:** when enabled, scans only currently viewable, purchased **character-bank** tab IDs **6–14** on bank opening, bank-slot/tab changes, and player-selected bank pages. It does not navigate tabs or accept account/Warband-bank IDs. It records per-tab numeric item totals, not labels, links, or precise slot positions.
- **Combat log:** when enabled, asks the client to start its native logger on world entry. The addon does **not** parse combat events or save combat lines in SavedVariables.

Each collection path skips combat and fails closed on unavailable APIs, protected/secret values, bad metadata, or invalid pre-existing storage. Automatic capture does not upload data. A timer/event attempt is not evidence of a successful capture or disk flush; inspect the in-game status/refusal message and validate persistence only after WoW saves and exits.

## Manual commands and wire strings

| Command | Result | SavedVariables effect |
| --- | --- | --- |
| `/mhwowui` | Settings, status, export buttons and explicit log-stop control | Settings changes persist on WoW's next save. |
| `/mhwow` | 12-field `MHWOW1`: character, class, level, zone/map, build, 19 equipped item IDs | Saves in `characters[guid]` if valid. |
| `/mhwowidentity` | 15-field `MHWOW2`: MHWOW1 fields plus faction, locale-independent race token and `Male`/`Female`/`Unknown` | Saves in the **same** character history if valid; fails rather than guessing unavailable identity. |
| `/mhwowbagsexport` | `MHWOWB1`: own bags' item ID -> total count | Saves in `bags[guid]` if valid. |
| `/mhwowbags` | Count-only chat diagnostic | None. |
| `/mhwowbankprobe` | Count-only selected bank diagnostic | None. |
| `/mhwowbanksexport` | `MHWOWK1`: own-bank `tabId:itemId:totalCount` entries | **None for this manual command.** Automatic bank capture is separate. |
| `/mhwowitemsexport` | `MHWOWI1`: cached metadata for observed own-bag/equipped IDs | None. |
| `/mhwowbankitemsexport [page]` | `MHWOWI1`: cached metadata for the visible own bank, at most 128 IDs per page (pages 1–9) | None. |

All payloads are versioned, bounded, validated, and player-reviewed. The character formats contain a timestamp, GUID and escaped name/realm/zone text; `MHWOW2` adds explicit identity. An empty equipment slot is `0`. `MHWOWB1` and `MHWOWK1` contain numeric totals, not item names or proof of ownership/acquisition beyond the observation. `MHWOWI1` contains cached names/details as **hex-encoded text** and may omit uncached items; item metadata never creates bag/bank totals by itself. See the public addon `README.md` and `MclarionWow.lua` builders for the exact field contracts and limits. Do not send actual exports in chat or commit them to source control.

## Companion boundary and current verification

Blizzard's [EULA §1.C (“Data Mining”)](https://www.blizzard.com/en-us/legal/simple/08b946df-660a-40e4-a072-1fbde65173b1/blizzard-end-user-license-agreement) restricts unauthorized software reading information generated or stored by the Platform; the stopped-game, user-triggered design alone does not establish permission for an external SavedVariables reader. Keep the staged reader uninstalled and disabled until authorization is established.

The addon has **no HTTP client, automatic upload, external filesystem reader, quest/reputation/profession recorder, or combat parser**. The signed-in Vaultkeeper website and Windows client have separate import/storage code. A synthetic `MHWOW2` fixture matching the reported shape (realm with spaces, Shaman, level/map/build and Alliance Dwarf male identity, but **not** the player's identifiers or equipment) passed the shared parser's focused tests. This is not a live import. As of 3 October, the deployed website assembly contains the `MHWOW1` marker but no `MHWOW2` marker: treat MHWOW2 website import as unavailable until a matching release is deployed and smoke-tested; `/mhwow` remains the compatible manual command. Refreshing a website view does not ingest new game data. A **staged, uninstalled** Windows-client candidate has a default-off, player-triggered closed-game SavedVariables reader and local plaintext archives capped at ten validated versions; this is not an addon feature or an authorized live transfer. External readers of SavedVariables or logs require separate policy/privacy review; the existence of game-written files alone is not authorization.

Mock Lua tests exercise the source. Manual `/mhwowidentity`, `/mhwow`, and the settings UI were reported working on one Alliance Dwarf. **Verified after the first 0.9.0 game session closed:** exactly one addon SavedVariables file, schema 1, four settings stored as `true`, `characters` and `bags` keys, and `MHWOW1`, `MHWOW2`, `MHWOWB1` format markers. The file was 11,356 bytes; these markers were checked without displaying any payload. The `bank` key and `MHWOWK1` marker were absent, consistent with bank capture not yet being demonstrated. The newest native combat-log file was updated near the same time, but its contents were not examined. **Player-confirmed in the next session:** addon 0.9.0 loaded and the settings UI retained all enabled switches, including Debugging, across a full restart and manual `/reload`, with no reported errors. **Still to verify:** automatic character capture rather than manual-history storage, own-bank capture/refusal, combat-log controls, persisted histories after the restart, and a manual importer round trip. The successful manual exports do not prove website or Windows importer deployment. See `TODO.md`.

**Later live own-bank check:** the count-only `/mhwowbankprobe` succeeded (one character-bank tab, 48 slots, two occupied) and explicitly saved nothing, as designed. The player used the manual Bank button and received a versioned `MHWOWK1` export, but the settings UI then reported `Bank: Capture unavailable: client refused the bank scan.` The manual export does **not** establish that automatic bank capture ran or that a bank history was persisted. The bank-status failure needs a separate event-timing/API investigation; no raw export or player/item identifiers are recorded here.

## Maintenance rule for future threads

**This file is a maintained handoff, not a self-updating file.** After any addon change to storage keys, settings, wire formats, command behavior, limits, trigger events, combat logging, installation path, or verification status: update the source `DATA_STORAGE.md` in `Mclarion/MclarionWow`, publish it with the audited addon code/docs, then refresh `B:\MclarionWow-Data-README.md` and verify the two documents' SHA-256 hashes match. Do the same if the website/client import deployment status in this handoff changes. Keep private observations out of both copies. Future threads should read the B: copy first, then confirm its version against the current public source and installed TOC before relying on it.
