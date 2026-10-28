# Notchest delivery roadmap

Based on the Notchest 0.5 baseline. This document proposes future work; it is
a plan, not a promise, and items may change as releases validate them.

## Product target

Ship a reliable 1.0 focused on the Mac island, developer tools, and AI usage
visibility. English remains the default interface; Arabic remains optional.
Advanced audio, hardware, and system integrations follow separate feasibility
gates.

## Current gaps

- Visual polish is implemented, but screen configurations, sleep/wake, older
  systems, and hardware combinations still need validation.
- Core service messages now follow the selected language. OS-provided errors
  and already-displayed errors or activity entries still need consistent
  handling when the language changes during a session.
- Cursor/Copilot, trustworthy cost reporting, and native agent-hook and
  approval flows are incomplete or unimplemented.
- Daily integrations need account, permission, offline, and
  unsupported-device testing.
- Developer-ID signing, notarization, and automatic updates are not
  configured yet.

## Milestones

| Milestone | Deliverable | Exit criterion |
| --- | --- | --- |
| M1 — 0.6 Reliability | Window clipping and display validation, complete language handling, independent live limits, performance baseline | Core UI cases pass in both languages and live limits work without local logs |
| M2 — 0.7 Developer workspace | Provider data states, GitHub setup, documented activity sender, eligible integrations and hook events | Each supported connector handles successful, unavailable, unauthorized, and stale-data states |
| M3 — 0.8 Daily tools | Real music and lyrics, weather and stocks, translation, permission and file/device integration tests | Every supported tool has recorded real integration evidence and actionable errors |
| M4 — 0.9 Beta | Screen and system matrix, optional Intel validation, regression and soak tests, tester feedback | No known crash or data-loss blocker; published support claims match the tested matrix |
| M5 — 1.0 Distribution | Developer ID, notarization, installation and upgrade validation, signed update feed and release documentation | An independent test Mac can install, verify, run, and upgrade the release while preserving data |

Repository foundation — license, history, CI, and issue conventions — is
already in place as of 0.5.

## Important dependencies

Developer ID signing and notarization follow
[Apple's distribution workflow](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution).
The update milestone needs hosted release files or an appcast and update
signing; [Sparkle's documentation](https://sparkle-project.org/documentation/)
describes HTTPS and EdDSA signatures.

[Cursor's Admin API](https://docs.cursor.com/en/account/teams/admin-api) and
the documented
[Copilot organization usage reports](https://docs.github.com/en/rest/copilot/copilot-usage-metrics)
have account and permission requirements. Confirm eligibility before
committing to a connector; these APIs do not establish universal live
personal-account support. Conditional connectors must not block otherwise
complete milestones.

Separate local usage, account limits, and money. Actual cost needs a
provider-supported cost or billing source. Any optional estimate must be
labeled with its source and date.

## Post-1.0 feasibility gates

Candidates beyond 1.0 start as bounded feasibility studies rather than
commitments: audio FFT, a per-app mixer, accessory battery reporting,
brightness and DDC control, menu-bar and keyboard-lighting controls,
notification and message sources, system HUD replacement, lock-screen
integrations, capture exclusion, multiple islands, app-local gestures, and
optional Lottie.

[Core Audio taps](https://developer.apple.com/documentation/coreaudio/capturing-system-audio-with-core-audio-taps)
provide process-audio capture and require permission; a robust mixer requires
additional routing and recovery work. Do not equate an audio capture
prototype with a finished mixer.

[UNUserNotificationCenter](https://developer.apple.com/documentation/usernotifications/unusernotificationcenter)
covers the app's notification behavior; it does not establish a general
cross-app mirror.
[NSWindow.SharingType.none](https://developer.apple.com/documentation/appkit/nswindow/sharingtype-swift.enum)
is documented as a legacy constant, so universal screenshot invisibility is
not a release promise. System face unlock is outside the committed 1.0 scope
pending a verified supported path.

## Tracking and completion

Progress is recorded in `FEATURES.md` and this roadmap. A feature is marked
complete only with validation evidence — never merely because its UI exists.
