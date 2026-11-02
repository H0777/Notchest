# Development validation matrix — 2026-11-02

Scope: workspace/onboarding, transparent native glass, agent activity,
project tracking, AI summaries and release checks after 0.6.0. This is a
record of evidence, not a claim that every supported Mac has been tested.

| Scenario | Evidence/status |
| --- | --- |
| Core correctness | 52 project checks passed locally |
| Preference migration | Setup completion, home order, transparency and dimensions survive model relaunch |
| AI lifecycle | Append/incomplete records, log replacement/day rollover, provider/folder races, retry backoff, cancellation and stale compact limits covered |
| AI alerts | Once per 80%/95% threshold and reset window; expired data ignored |
| Hooks/configuration | Metadata filtering, private backups, existing settings preservation, idempotent install, removal and invalid-file rejection covered in temporary directories |
| Project results | Queued/running/null conclusion and failed runs decoded; unsafe links excluded; actual GitHub runs displayed in the native UI |
| Release metadata | Numeric versions, stable-only results, official repository URLs covered |
| Website | Existing 39-feature gallery remains the released UI baseline; new screenshots are development previews |
| Native UI English/Arabic, glass and preference controls | Passed on the local Mac: English/Arabic setup, presets, card reordering, both provider summaries, glass slider and live release checks |
| Native helper to loopback API | Passed: synthetic PermissionRequest → working → Stop through the packaged helper; empty JSON replies; runtime token removed on disable |
| Whole-app performance | 60-second warm/collapsed sample: 0.12% CPU, 103.28 MiB peak RSS after bounding temporary scan buffers; see PERFORMANCE.md |
| Multiple physical displays, hot-plug and mixed scaling | Pending access to additional displays; sizing geometry has automated coverage |
| Intel and macOS 13–25 material fallback | Pending hardware/OS testing; build targets macOS 13 and guards newer APIs |
| macOS 26 native glass | API is availability-guarded; CI builds against the macOS 26 SDK |
| Real sleep/wake, prolonged battery use and full-screen combinations | Pending device soak testing; wake handling and window policy remain in source |
| Apple Developer ID/notarization and unattended installation | Deferred by owner |

Before a broad release, exercise the pending hardware cases and repeat the
performance measurement with real provider logs. No claim of zero CPU,
zero battery impact, full device coverage or Apple approval is made.
