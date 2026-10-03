# MclarionWow: how data is produced and stored

**Status: 3 October 2026.** This describes the published **0.9.0** addon source, not a promise that every API has passed a live Forever-client test. The installed Lua and TOC matched the public source by SHA-256; `/mhwowidentity`, bank capture, and a full-restart SavedVariables round trip still need in-game verification. Keep this document in sync with changes to data formats, capture triggers, storage, importers, or deployment. The matching handoff copy is `B:\MclarionWow-Data-README.md` on Mclarion-Main. Do not insert actual character exports, GUIDs, account folder names, SavedVariables contents, or combat-log lines here.

## The three separate data paths

1. **Addon SavedVariables (local snapshots/settings).** The TOC declares `## SavedVariables: MclarionWowData`. The addon assigns a Lua table in memory. **World of Warcraft**, not addon Lua, serializes it to a file on its own `/reload` / logout / exit save cycle. The addon cannot force an immediate disk write when a bag/bank opens and cannot create arbitrary TXT/JSON/CSV files.
2. **Manual copy/paste exports.** A slash command can show a validated, selected text string for the player to inspect and copy with Ctrl+C. Showing an export is not an upload; only the player can paste it into a separately authorized importer. Some manual commands also store a local snapshot; see the table below. No website or desktop app is wired to read `MclarionWowData` automatically.
3. **WoW native combat log.** If the first-run-off combat logging option is explicitly enabled, the addon calls WoW's `LoggingCombat` API on the next world entry. WoW writes its own `Logs\WoWCombatLog-*.txt` file. That file is not an addon export and is **not** saved inside `MclarionWowData`. Turning off auto-start does not stop a log already running. The separate **Stop logging now** button can stop logging even if the player or another addon started it; its UI warns about this.

## Files on Mclarion-Main

- Installed addon code: `B:\Blizzard\World of Warcraft\_classic_beta_\Interface\AddOns\MclarionWow\MclarionWow.lua` and `MclarionWow.toc`. These are **code**, not character data. The TOC targets interface `16001`, game type `camelot`, version `0.9.0`.
- Addon-owned SavedVariables: `B:\Blizzard\World of Warcraft\_classic_beta_\WTF\Account\<account>\SavedVariables\MclarionWow.lua`. `<account>` is a private directory component. The file was observed after a prior `/reload` and clean exit; its presence does not prove that every capture type survived a full restart.
- Game-owned combat logs: `B:\Blizzard\World of Warcraft\_classic_beta_\Logs\WoWCombatLog-*.txt` when native logging is active. `QuestCache.log` and `Professions.log`, if present, are also game files, **not** produced by this addon.
- This documentation: `B:\MclarionWow-Data-README.md` (outside the WoW installation). It contains no player observations.

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

The addon has **no HTTP client, automatic upload, external filesystem reader, quest/reputation/profession recorder, or combat parser**. The signed-in Vaultkeeper website and Windows client have separate import/storage code. A manual export needs a matching deployed importer; do not assume a locally tested `MHWOW2` parser is already deployed. Likewise, refreshing a website view does not ingest new game data. An external reader of SavedVariables or logs is a separate design requiring policy/privacy review; the existence of game-written files alone is not authorization.

Mock Lua tests exercise the source, and one earlier SavedVariables write was observed after `/reload`/exit. **Still to verify in-game for 0.9.0:** loading without errors, `/mhwowidentity`, opted-in own-bank capture/refusal, logging controls, settings/histories after a full restart, and the manual import round trip. See `TODO.md`; do not convert a source-code feature into a live-verified claim.

## Maintenance rule for future threads

**This file is a maintained handoff, not a self-updating file.** After any addon change to storage keys, settings, wire formats, command behavior, limits, trigger events, combat logging, installation path, or verification status: update the source `DATA_STORAGE.md` in `Mclarion/MclarionWow`, publish it with the audited addon code/docs, then refresh `B:\MclarionWow-Data-README.md` and verify the two documents' SHA-256 hashes match. Do the same if the website/client import deployment status in this handoff changes. Keep private observations out of both copies. Future threads should read the B: copy first, then confirm its version against the current public source and installed TOC before relying on it.
