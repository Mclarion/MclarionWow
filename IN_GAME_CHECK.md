# Combined 0.12.0 candidate: one in-game check

This one build includes the existing character/bag/bank/item addon and all six new capture categories. Both sibling addons (`MclarionWow` and `MclarionWowProgression`) must be installed and enabled. It is a test candidate, not a claim of live persistence.

## One normal session

1. Log in to Forever and open `/mhwowui` out of combat.
2. On **Main**, use **Quests now** and **Reputation now**. On **More captures**, use **Gold now**, **Currencies now**, **Honor now** and **Titles now**. New manual actions work without enabling automation.
3. For any automatic categories you want, enable their separate checkboxes. Leave unwanted categories off. Their initial state is off; the old capture preferences are retained.
4. Tell the assistant only which category reports an error/refusal/unavailable. No screenshot, raw data, identifiers or diagnostic slash command is needed. Unchanged is a successful deduplication result, not a failed button.
5. Exit WoW normally. The assistant can then confirm the process stopped and run a bounded aggregate-only development check of the two game-written files. Do not select the companion file for website/desktop import: that is not supported yet.

You may close WoW normally immediately after capture. No `/reload` is required for this normal-exit test. Retention across a later full restart remains a separate claim until that restart is observed.

## Expected scope

- Quests: active log observations, not completed-quest history.
- Reputation: visible character-provenance rows; account-wide/unknown rows can refuse the scan.
- Gold: character copper balance, not a transaction ledger.
- Currencies: visible-list balances with character/account scope separated.
- Honor: available kill counters and Forever rank progress, not total honor earned.
- Titles: selected/none and known titles, not acquisition dates.

Missing or protected data must refuse rather than be stored as zero. Offline tests cannot confirm every client API is available in the current view. Existing legacy imports remain separate from the new companion data.
