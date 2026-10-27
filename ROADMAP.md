# Notchest delivery roadmap

Based on Notchest 0.5 and the source review on October 27, 2026. The last saved validation run passed 34 checks. This document proposes future work; the backlog is not implemented by this planning update.

[الخطة العربية التفصيلية — assessment, 31 task IDs, acceptance criteria, first five days, and research backlog](ROADMAP.ar.md)

## Product target

Ship a reliable 1.0 focused on the Mac island, developer tools, and AI usage visibility. English remains the default interface; Arabic remains optional. Advanced audio, hardware, and system integrations follow separate feasibility gates.

## Current gaps

- Visual polish has been implemented, but screen configurations, sleep/wake, older systems, and hardware combinations still need validation.
- Localization is incomplete in service-generated events and errors. Some download and drive events are hard-coded in Arabic.
- Live Codex limits are rendered inside a local-log-dependent branch in `DeveloperView.swift`; they need an independent presentation when tracking is disabled or logs are absent.
- Cursor/Copilot, trustworthy cost reporting, and native agent-hook/approval flows are incomplete or unimplemented.
- Daily integrations need account, permission, offline, and unsupported-device testing.
- Audio FFT, a per-app mixer, accessory batteries, brightness/DDC, multiple islands, gestures, and Lottie are future additions.
- Notification mirroring, messages/calls, system HUD replacement, and lock-screen features need source-by-source feasibility work.
- The local repository has no initial commit or remote. CI, an original-source license, public signing/notarization, and automatic updates are not configured.

## Milestones

Estimates assume one full-time macOS developer and sequential work.

| Milestone | Deliverable | Working days | Exit criterion |
| --- | --- | --- | --- |
| M0 — Repository foundation | License decision, initial history, repository setup, CI and issue/release conventions | 1–2 | A clean checkout builds and runs checks from the documented instructions |
| M1 — 0.6 Reliability | Window clipping and display validation, complete language handling, independent live limits, performance baseline | 5–7 | Core UI cases pass in both languages and live limits work without local logs |
| M2 — 0.7 Developer workspace | Provider data states, GitHub setup, documented activity sender, eligible integrations and hook events | 8–12 | Each supported connector handles successful, unavailable, unauthorized, and stale-data states |
| M3 — 0.8 Daily tools | Real music/lyrics, weather/stocks, translation, permission and file/device integration tests | 5–8 | Every supported tool has recorded real integration evidence and actionable errors |
| M4 — 0.9 Beta | Screen/system matrix, optional Intel validation, regression/soak tests, tester feedback | 4–6 | No known crash or data-loss blocker; published support claims match the tested matrix |
| M5 — 1.0 Distribution | Developer ID, notarization, installation/upgrade validation, signed update feed and release documentation | 4–6 | An independent test Mac can install, verify, run, and upgrade the release while preserving data |

Base effort: **27–41 working days**. With a 20% contingency, plan for approximately **33–50 working days, or 7–10 full working weeks**. External waits and post-1.0 research are excluded. Re-estimate after M1.

## Important dependencies

Developer ID signing and notarization follow [Apple's distribution workflow](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution). The update milestone needs hosted release files/appcast and update signing; [Sparkle's documentation](https://sparkle-project.org/documentation/) describes HTTPS and EdDSA signatures.

[Cursor's Admin API](https://docs.cursor.com/en/account/teams/admin-api) and the documented [Copilot organization usage reports](https://docs.github.com/en/rest/copilot/copilot-usage-metrics) have account/permission requirements. Confirm eligibility before committing to a connector; these APIs do not establish universal live personal-account support. Conditional connectors must not block otherwise complete milestones.

Separate local usage, account limits, and money. Actual cost needs a provider-supported cost/billing source. Any optional estimate must be labeled with its source and date.

## Post-1.0 feasibility gates

The detailed Arabic plan includes bounded studies for FFT, per-app mixing, accessory battery reporting, brightness/DDC, menu-bar/keyboard controls, notification and message sources, system HUDs, lock-screen integrations, and capture exclusion. Multiple islands, app-local gestures, and optional Lottie are separately estimated extensions.

[Core Audio taps](https://developer.apple.com/documentation/coreaudio/capturing-system-audio-with-core-audio-taps) provide process-audio capture and require permission; a robust mixer requires additional routing and recovery work. Do not equate an audio capture prototype with a finished mixer.

[UNUserNotificationCenter](https://developer.apple.com/documentation/usernotifications/unusernotificationcenter) covers the app's notification behavior; it does not establish a general cross-app mirror. [NSWindow.SharingType.none](https://developer.apple.com/documentation/appkit/nswindow/sharingtype-swift.enum) is documented as a legacy constant, so universal screenshot invisibility is not a release promise. System face unlock is outside the committed 1.0 scope pending a verified supported path.

## First five working days

1. Confirm scope/license and prepare the GitHub work list and repository conventions.
2. Add reproducible CI checks and fix the live-limits/local-log UI dependency.
3. Localize service events and errors consistently in both interface languages.
4. Validate island clipping, dimensions, and screen transitions with reproducible cases.
5. Record performance baselines, close priority reliability issues, and re-estimate 0.6.

Hardware checks and repairs may continue beyond day five within the milestone estimate.

## Tracking and completion

Use the NT-001–NT-031 task IDs in [ROADMAP.ar.md](ROADMAP.ar.md). Each task has an owner, priority, dependencies, acceptance criterion, validation evidence, and a state: planned, ready, in progress, in review, done, or externally blocked. For each milestone, update `FEATURES.md`, record changes and check results, and build a clearly versioned test artifact. Never mark a connector complete solely because its UI exists.
