# Consolidated offline addon delivery

## User direction

Continue substantial addon development while the player cannot log in. Minimize interruptions: complete implementation, integration, automated testing, review and packaging before requesting one consolidated live session. Do not turn each safety check into a separate diagnostic release. This workflow is not evidence that any queued feature is complete.

## Scope and acceptance

- Preserve the installed addon and existing legacy import file throughout offline work.
- Keep the tested quest/reputation candidate as a baseline; extend only the separate progression companion.
- Money: character balance in integer copper, bounded observations, not a transaction ledger.
- Currencies: exact-client supported balances with explicit ownership and partial-list scope. Unknown is not zero; account-wide balances are not character-owned.
- Honor/PvP: only source-supported counters and ranks with Forever semantics, not assumed retail equivalents.
- Titles: selected title, with explicit no-title versus unavailable states. Include unlocked titles only with verified enumeration support; observation time is not acquisition time.
- Existing reputation: visible character-only observations, not comprehensive faction coverage; preserve whole-scan refusal for unsafe provenance.
- No website/desktop changes, local GitLab access, raw player-save reads or live-game interaction during this offline phase.

## Execution sequence

1. **Evidence and modules.** Match API signatures, fields and events to the documented Forever source/build. Implement independent gold/currency and honor/title modules using failing tests first. If a capability lacks evidence, isolate it as unavailable and continue supported work rather than blocking every category or inventing data.
2. **Shared integration.** Add manual actions and separate default-off automatic options. Keep legacy SavedVariables ownership unchanged. Include every companion root in combined budget checks. Missing modules and refused scans must preserve old values and settings. UI must distinguish saved-in-memory, unchanged and unavailable states.
3. **Automated verification.** Run Lua 5.1 and 5.4 module and integration tests, package tests and applicable contracts. Cover protected/missing/throwing APIs, zero/empty versus unavailable, unstable scans, owner changes, deduplication, same-second events, bounded histories, cumulative size limits and sibling/legacy preservation. Exercise fabricated save/load reconstruction; label it synthetic, never live persistence.
4. **Review and correction.** Review completed paths for concrete correctness/security defects. Fix root causes and rerun affected tests; broader suite once after integration settles. Do not repeat already-settled checks without a relevant source change. No arbitrary extra feature scope during review.
5. **Artifact and handoff.** Build a deterministic allowlisted two-addon ZIP; verify archive inventory, dependencies, runtime load order, source bytes and repeated-build hash. Store final artifact at a stable workspace path. Update README, DATA_STORAGE and TODO with implemented/tested/unsupported/live-unverified distinctions. Publication, remote handoff and client installation are separate actions, not implied by a local build.
6. **One consolidated live session when available.** After release/install prerequisites and stopped-client backup/hash verification, ask the player once to log in, perform the combined capture checks, and exit normally. With WoW confirmed closed and within existing consent, inspect only bounded aggregate save results. Never request raw payloads or repeated preflight screenshots. Report remaining category-specific issues together.

## Interruptions and stopping rules

- No player login, screenshots or diagnostic commands during offline development.
- Do not stop after every module or send each subagent report as a new user task. Continue dependent integration work when results arrive.
- Ask only for missing authorization, an irreversible scope decision, credentials through approved tools, or an unavoidable real-client observation after offline work is complete.
- If a tool reports an interrupted delegation with an unknown outcome, check actual liveness/state once before retrying side effects. Never spawn duplicate writers merely because a stale completion message arrived.
- Parallel workers own disjoint files. The parent integrates, reviews and verifies artifacts before reporting completion.
- Background work depends on the current session; do not promise survival across session exit or notifications this interface cannot deliver.
- Completion means a verified offline artifact with an honest live-test checklist, not an installed or in-game-verified feature.
