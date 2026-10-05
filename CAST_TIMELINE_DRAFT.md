# Timed-cast timeline draft — 5 October 2026

**Status:** requested presentation scope, not an installed addon feature or a verified parser. MclarionWow currently only opts into WoW's native combat logging; that log is separate from `MclarionWowData`. No cast records are written to SavedVariables, and no combat-log event pairing has been validated against the exact Forever client. This document specifies the intended display and the evidence needed before implementation; it does not direct other application threads.

## Intended display

For each **timed cast supported by observed start/end events**, show two clearly linked marks. Example (illustrative labels, not a parsed real event):

```text
Fireball (Cast start)
    │  faction-colored line for this caster and cast interval
Fireball (Hit / Miss / Dodge, only if that result is observed and unambiguously matched)
```

The line begins at the cast-start timestamp and reaches the cast-end mark; its color reflects the **caster's verified faction** (Alliance/Horde, with a neutral or unknown fallback). Never infer a faction from spell, class, name, or target. Every timed cast that can be represented has a visible start and an end state; if the log does not establish an end, show **end unknown**, not an inferred interruption or completion. Label a cast **interrupted** only when a matching interruption event is observed. A cast-complete event and its later impact/result can be different events: display both when available; label the terminal mark Hit, Miss, or Dodge only when a matching outcome is actually observed. Never turn a successful cast into a claimed hit merely because no miss was seen.

## Addon/API boundary and feasibility gates

- The addon does not currently capture combat events into SavedVariables; its `LoggingCombat` switch starts WoW's **native** combat log only. Keep that log and the inventory/progression schemas separate.
- Inspect a bounded, privacy-preserving copy of a stopped-game, game-written log (with player consent) to establish which cast-start, cast-success/interruption, impact, and miss-reason events the exact Forever build emits. Public API/source descriptions are hypotheses until matched to this client. Do not publish the player's raw combat log.
- Correlate by verified caster identity, spell identifier, ordered timestamps and any actual event correlation identifier. Multiple concurrent casts, repeated Fireballs, multiple targets, channels, projectiles, missing events, and log rotation can make an outcome ambiguous. Do not connect two events merely because their spell names match; render unpaired/unknown when safe matching is impossible.
- Resolve caster faction from a trustworthy, contemporaneous source; when absent or protected, use the unknown/neutral line color. Define accessible colors and a non-color cue (the labeled endpoint marks) so the connection remains clear without relying on hue alone.
- Prove mock cases for Hit, Miss, Dodge, interrupted/unknown, repeated casts, late impact, ambiguous multi-target results, missing timestamps, protected values and faction unknown before claiming a working timeline. The addon should not silently enable new logging, upload, or progression capture to support this display.

**Next:** validate the exact client log event shapes privately, then propose a bounded, versioned cast-event contract and renderer tests. No timeline implementation or release is claimed here.
