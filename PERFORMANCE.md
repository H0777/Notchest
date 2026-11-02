# Performance baseline

Method and baseline numbers for comparing releases. Reproduce with the
committed script against a freshly built app:

```sh
./build.sh
open dist/Notchest.app
./Scripts/measure.sh 60 idle-collapsed
```

The script samples `ps` once per second and reports average CPU and peak RSS
of the running app.

## Baseline — 2026-10-28 (Apple Silicon, macOS 27)

| Scenario | Average CPU | Peak memory |
| --- | --- | --- |
| Idle, island collapsed, default services on (usage scan every 30 s, system refresh every 4 s, island tick every 1 s) | ≈1% | 99 MB |

Notes:

- The measurement is integer-sampled (`ps` CPU column, floored), so readings
  under 1% are reported as 0–1%.
- Memory includes the linked SwiftTerm terminal library even before a
  terminal session opens.
- The embedded-terminal and large-log-scan scenarios need a real account and
  an opened panel; measure them interactively with the same script and append
  rows here with the app version and date.

### Known follow-ups

- Timers keep running while the island is collapsed. If a future release
  pauses non-essential work when collapsed, idle CPU should drop below this
  baseline — record the improvement here.

## Unreleased AI usage reader — 2026-11-02

Local polling now runs every five seconds; the 0.6.0 idle baseline above is
historical and must not be taken as a measurement of this build. An actual
Codex log scan read about 423 MiB in 13.4 seconds on its initial pass; an
immediate incremental pass read about 64 KiB in 0.0024 seconds while logs were
still growing. These are reader timings, not whole-app CPU or memory figures.
Some records/files exceeded the reader limits and were disclosed as partial.
Live Codex account limits fetched successfully. No Claude logs were present on
the test machine; automated fixtures cover its parsing and growing records.
