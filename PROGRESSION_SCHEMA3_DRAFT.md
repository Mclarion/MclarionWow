# Draft schema 3 progression contract — 5 October 2026

**Status: test-only contract. Not emitted by the addon, not accepted by either deployed importer, and not present in real SavedVariables.** A private, uninstalled desktop source candidate independently accepts this fabricated shape in typed parser/transaction self-tests. The installed addon remains schema 2 and only exposes non-persisting diagnostics.

## Purpose and semantics

Schema 3 would preserve every schema-2 root and add two independent first-run-off settings plus one bounded progression root:

```text
settings.autoQuestCapture       boolean, default false
settings.autoReputationCapture  boolean, default false
progression[characterGuid].quests[]
progression[characterGuid].reputation[]
```

Quest observations represent **active quest-log leaves visible at one instant**. Absence never proves completion, abandonment, or failure. Reputation observations represent **validated visible faction leaves at one instant**. Hidden or collapsed rows are not zero-valued factions, and visible rows are not a complete reputation ledger.

The two settings are independent. Enabling character, bag, bank, item, or combat-log capture must not enable either progression source. A category scan must fail closed as a whole on protected, malformed, throwing, over-limit, or incomplete input; never persist a truncated scan.

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
- A rejected scan leaves the prior valid history unchanged. Schema migration must be atomic: schema 2 remains untouched unless the new root/settings pass this progression validator **and** all preserved character, bag, bank and item roots pass the existing schema-2 reader unchanged.

## Importer acceptance and idempotence

Both website and desktop importers must independently pass the same fabricated fixtures before an addon writer is enabled:

1. Accept canonical quest and reputation records and preserve their partial-observation scopes.
2. Reject bad owner binding, malformed delimiters, noncanonical integers, duplicate/unsorted IDs, count mismatches, invalid intervals, oversized records, sparse histories, unknown keys, excess owners/history/bytes, and unsupported schema.
3. Importing the same file twice produces zero additional observations on the second import.
4. Timestamp differences alone do not create a new state. Adjacent records whose non-timestamp fields are identical are invalid at the source boundary; exact record reimports must also be idempotent.
5. Category failure is isolated: a rejected quest record must not erase valid legacy or reputation data, and vice versa.
6. UI labels must say **active quest-log observation** and **visible reputation observation**, never completed quests or complete reputation history.

## Current executable evidence

`tests/progression_contract.lua` is a test-only parser and **progression-extension** root validator; it checks allowed schema-3 root/settings keys and the new progression data but intentionally delegates validation of preserved schema-2 payloads to the existing readers. `tests/test_progression_contract.lua` covers canonical and malformed wires, owner binding, ordering, bounds, opt-in types, deduplication, history/owner/byte limits, and unknown keys. `tests/schema3-progression-synthetic.lua` is fabricated and keeps both new opt-ins off. Independent website and desktop source candidates now pass parser/storage/idempotence/presentation tests against these artifacts, including progression-only owner handling and required partial-observation labels/disclaimers. The website candidate also passes 20-state durable-retention tests and an isolated SQL Server migration/import/readback test; its transaction is compatible with the production retry strategy. Six pre-existing Identity model/snapshot differences unrelated to WoW still block a normal production migration. Deployment, private release and independent review remain open. These artifacts and source tests do not authorize an addon writer or production import.