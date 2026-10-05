# Draft schema 3 progression contract — 5 October 2026

**Status: test-only, provisional contract. Not emitted by the addon, not accepted by either deployed importer, and not present in real SavedVariables.** Installed 0.11.11 remains schema 2 and only exposes non-persisting diagnostics. Its read-only skeleton dry run checked cloned item records in game on 5 October 2026 and reported **301400/3000000 projected bytes (not actual file bytes); other legacy histories not validated; no data saved**, with no refusal. It did not assign schema 3 or write progression. A read-only independent addon review using `gpt-6-sol` identified unresolved scan-consistency, reputation-provenance, whole-file-size and legacy-preservation gates; the observed dry run does not close them. The player reported a Forever update with unchanged displayed version 1.60.1.70205 and no outdated-addon flag; the screenshot itself does not show update details.

## Purpose and semantics

Schema 3 would preserve every schema-2 root and add two independent first-run-off settings plus one bounded progression root:

```text
settings.autoQuestCapture       boolean, default false
settings.autoReputationCapture  boolean, default false
progression[characterGuid].quests[]
progression[characterGuid].reputation[]
```

Quest observations represent **active quest-log leaves visible in one stable scan**. Absence never proves completion, abandonment, or failure. Reputation observations represent **validated visible faction leaves in one stable scan made while the keyed character was logged in**. The character GUID identifies the observer, not necessarily the owner of an account-wide standing. Hidden or collapsed rows are not zero-valued factions, and visible rows are not a complete reputation ledger.

The two settings are independent. Enabling character, bag, bank, item, or combat-log capture must not enable either progression source. A category scan must fail closed as a whole on protected, malformed, throwing, over-limit, or incomplete input; never persist a truncated scan. Installed `/mhwowprogresssafety` performs two guarded UI-index passes and the player reported matching aggregates for one visible view on 5 October 2026; even matching passes are **not an atomic snapshot** or proof for other UI states. A future writer must repeat complete guarded count, row-classification, header-identity, ID and value comparisons before committing; a changed/reordered view refuses the entire category without replacing its previous history. Mock count, header and leaf reorders/value mutations mid-scan.

## Wire records

All fields are ASCII. Decimal integers use canonical base-10 notation: no leading zeroes except `0`, no plus sign, and no `-0`. Identifiers are never escaped because permitted values are bounded integers or the validated `Player-...` owner key.

### Active quest log: `MHWOWQ1`

```text
MHWOWQ1|forever|timestamp|guid|build|active-log|visibleRows|leafCount|questIds
```

- `timestamp`: server-time integer `1..253402300799`.
- `guid`: `Player-[A-Za-z0-9-]+`, at most 77 bytes, and exactly equal to the enclosing character key.
- `build`: integer `1..2147483647`.
- Scope is the literal `active-log`.
- `visibleRows`: `0..128`, including headers.
- `leafCount`: `0..100` and no greater than `visibleRows`.
- `questIds`: exactly `leafCount` strictly ascending unique integers `1..2147483647`, comma separated; empty only when `leafCount` is zero.
- Maximum record size: 4096 bytes.

Example using fabricated identifiers:

```text
MHWOWQ1|forever|1720000000|Player-1234-ABCDEF12|70205|active-log|12|2|42,84
```

### Visible reputation rows: `MHWOWR1`

```text
MHWOWR1|forever|timestamp|guid|build|visible-ui|visibleRows|leafCount|headerRepCount|collapsedHeaderCount|entries
```

- Common timestamp, owner, and build bounds are identical to `MHWOWQ1`.
- Scope is the literal `visible-ui`.
- `visibleRows`: `0..256`.
- `leafCount`: `0..200`, no greater than `visibleRows`.
- `headerRepCount` and `collapsedHeaderCount`: each `0..visibleRows`. Either can overlap the other; each plus `leafCount` must not exceed `visibleRows`.
- `entries`: exactly `leafCount` semicolon-separated records sorted by strictly ascending faction ID.
- Entry fields are `factionId:reaction:minimum:maximum:value`.
- `factionId`: integer `1..2147483647`.
- `reaction`: integer `1..16`.
- `minimum`, `maximum`, `value`: canonical signed integers `-2147483647..2147483647`; `minimum < maximum` and `minimum <= value <= maximum`.
- Empty only when `leafCount` is zero.
- Maximum record size: 32768 bytes.

**Character-only R1 policy, still without a writer:** The build-70205 extracted `FactionData` declares `isAccountWide`; installed `/mhwowprogresssafety` read safe boolean classifications for seven visible leaves in the player's current view, all false. That does **not** establish other views or the absence of account-wide standing. `MHWOWR1` has no account-wide marker: a future writer may emit its five-field entry only when *every* visible leaf is confirmed `isAccountWide == false` during stable scans and its faction ID is bound to the matching wire entry. Any `true`, missing, protected, mismatched or unclassifiable flag refuses the **whole reputation category**, preserves prior data, and cannot be silently dropped from `visibleRows`. Account-wide observations need a separately versioned, explicitly scoped wire (not R1). `tests/progression_contract.lua` now models this ID-bound category precondition; it is test-only and does not guard live secret values.

**Size calibration is incomplete:** One consented, stopped-game, aggregate-only check found 67,294 serialized bytes versus 300,632 projected for the current schema-2 file; four synthetic serialized fixtures matched the Lua estimator. This sample does not establish a worst-case Forever serializer bound for a future schema-3 root or close the 4 MB upload gate. The 3,000,000-byte envelope remains provisional; no progression writer or migration has been installed.

Example using fabricated identifiers:

```text
MHWOWR1|forever|1720000001|Player-1234-ABCDEF12|70205|visible-ui|9|2|0|0|100:4:0:3000:1200;200:5:3000:9000:4200
```

## Root and history limits

- `schema` must equal `3`; existing schema-2 roots and wire formats remain unchanged.
- Maximum 256 character GUIDs under `progression`.
- Per character, `quests` and `reputation` are optional independently, but an owner record cannot be empty and no unknown category key is accepted.
- Each category history is a contiguous numeric array of 1–20 records ordered by strictly increasing timestamp.
- Adjacent observations with identical state after removing only the timestamp are forbidden; the addon must deduplicate them before storage.
- Aggregate progression wire bytes across all owners and both categories must not exceed 2 MiB.
- This 2 MiB limit covers **only progression wire strings**, not schema-2 histories, keys, Lua serialization overhead, or the whole game-written file. The existing manual file upload limit is 4 MB. `tests/save_size_projection.lua` is a **synthetic-only experiment**: it counts every node/key and up to four escaped bytes per string byte, adds structural overhead, rejects unsupported/cyclic/deep roots, and refuses proposals above a provisional 3,000,000-byte envelope. Both populated schema-2 bank-array spellings and composed schema-3 test roots pass; an oversized escaped-string root fails. A read-only parser checked one stopped-game schema-2 file against this model, but **one match is not a worst-case serializer bound** and does not prove uploadability or close the writer gate. The 0.11.9 `/mhwowsizeprobe` candidate projects the current *in-memory* schema-1/2 root, reports aggregate numbers only, and writes nothing; its mock pass is not a live-client result. A writer needs a justified whole-file bound for preserved roots plus new state; inspect game-written files only while WoW is closed, with bounded aggregate-only output.
- A rejected scan leaves the prior valid history unchanged. Schema migration must be atomic: schema 2 remains untouched unless the new root/settings pass this progression validator **and** all preserved character, bag, bank and item roots pass the existing schema-2 reader unchanged.
- `tests/schema3_preflight.lua` models only a test-side clone/validate/size-refuse path on fabricated populated roots, including both bank-page array encodings. It cannot prove the installed addon migrates atomically or that the full legacy reader accepts those values; no writer is present.

## Importer acceptance and idempotence

Both website and desktop importers must independently pass the same fabricated fixtures before an addon writer is enabled:

1. Accept canonical quest and reputation records and preserve their partial-observation scopes.
2. Reject bad owner binding, malformed delimiters, noncanonical integers, duplicate/unsorted IDs, count mismatches, invalid intervals, oversized records, sparse histories, unknown keys, excess owners/history/bytes, and unsupported schema.
3. Importing the same file twice produces zero additional observations on the second import.
4. Timestamp differences alone do not create a new state. Adjacent records whose non-timestamp fields are identical are invalid at the source boundary; exact record reimports must also be idempotent.
5. Category failure is isolated: a rejected quest record must not erase valid legacy or reputation data, and vice versa.
6. UI labels must say **active quest-log observation** and **visible reputation observation**, never completed quests or complete reputation history.

## Populated legacy fixture scaffold (not a migration)

`tests/test_schema3_populated_legacy.lua` composes a proposed schema-3 **test root** from each builder-generated, populated schema-2 fixture (`tests/schema2-synthetic.lua` and `tests/schema2-synthetic-explicit.lua`). It verifies unchanged character, bag, bank and item roots, semantically equivalent two-page implicit/explicit bank arrays, reference progression validation, and a negative control that detects a missing second bank metadata page. This does **not** exercise a future addon migration or prove its atomicity; the migration-preservation release gate remains open. The fixture is synthetic and was never read from a game save.

## Current executable evidence

The 0.11.10 read-only in-client dry run reported **301400/3000000 projected bytes (not actual file bytes); no data saved** on 5 October 2026. This observed empty-progression skeleton projection does not close semantic legacy validation, migration atomicity, worst-case serializer size or consumer/importer gates; no writer is installed. No unchanged repeat is needed.

`tests/progression_contract.lua` is a test-only parser and **progression-extension** root validator; it checks allowed schema-3 root/settings keys and the new progression data but intentionally delegates validation of preserved schema-2 payloads to the existing readers. `tests/test_progression_contract.lua` covers canonical and malformed wires, owner binding, ordering, bounds, opt-in types, deduplication, history/owner/byte limits, and unknown keys. `tests/schema3-progression-synthetic.lua` remains the fabricated progression-only fixture with empty legacy histories. `tests/test_schema3_populated_legacy.lua` separately composes schema-3 roots from populated builder-generated schema-2 fixtures, verifies character/bag/bank/item equality for implicit and explicit two-page bank arrays, and proves a dropped page fails. Installed addon 0.11.10 adds a runtime read-only skeleton clone/projection path with strict root/settings shape; the Lua 5.1/5.4 mock suite passes 384 assertions. It does **not** assign migration or write progression. Actual atomic migration, semantic validation of every preserved wire, worst-case whole-file calibration and writer authorization remain open.