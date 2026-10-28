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
