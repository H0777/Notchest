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

## Workspace build — 2026-11-02

Local Apple Silicon Mac (`Mac16,12`), macOS 27.2, release build. One
60-second sample per build, island collapsed after the initial real Codex
log scan. Local usage polling every five seconds; live account polling,
GitHub Actions and update checks off. Claude logs were absent. The runtime
used real logs with partial-scan limits disclosed in the UI.

| Build | Average sampled CPU | Peak sampled RSS |
| --- | --- | --- |
| Workspace draft before bounding Foundation temporary objects | 0.11% | 535.92 MiB |
| Same workload with a per-chunk autorelease pool (`be574bb`) | 0.12% | 103.28 MiB |

The pool bounds temporary Foundation objects on the Swift concurrency worker
between 256 KiB read chunks. This removes the elevated retained RSS observed
after large scans. The CPU difference is sampling noise; no speed or battery
improvement is inferred from it. These are local samples, not guarantees for
all hardware or log sizes, and the historical integer-rounded 0.6 baseline
uses a different reporting precision.

`Scripts/measure.sh` now preserves fractional CPU values and accepts
`NOTCHEST_PID` to distinguish multiple running app instances. RSS is the
process's resident set, not an allocation-leak measurement. Prolonged battery,
multiple-display and older-system scenarios remain pending in
[the validation matrix](Docs/VALIDATION.md).
