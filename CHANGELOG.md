# Changelog

All notable changes to Notchest are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [0.7.1] — 2026-11-03

### Added

- `Packaging/READ-ME-FIRST.txt`: a bilingual (Arabic/English) three-step
  first-open guide shipped **inside every ZIP release** beside the app —
  covering extraction, the one-time Open Anyway approval, an optional
  `xattr` Terminal alternative, and why the warning appears. `release.sh`
  verifies the guide ships inside each ZIP before publication.

## [0.7.0] — 2026-11-03

### Added

- Opt-in system notifications via UNUserNotificationCenter for the app's own events: focus completion, new files in Downloads, connected drives, and stock alerts. Opt-in from Settings; authorization is requested only when enabled; wording follows the interface language.
- First-run connection checks and Developer/Focus/Everyday presets, with
  persistent, reorderable home cards and a background-transparency control.
- Native clear `NSGlassEffectView` on macOS 26+, preserving the notch outline
  and providing a behind-window material fallback on older macOS versions.
- Side-by-side local Codex/Claude summaries and optional 80%/95% usage alerts.
- Opt-in native agent hooks for task states, with private configuration
  backups and removal, metadata-only local delivery and no approval decisions.
- Opt-in GitHub Actions tracking for the selected project, plus local command
  start/exit activities that preserve the active tab.
- Manual and opt-in six-hour stable-release checks with official download-page
  links. Developer ID, notarization and unattended installation are deferred
  until the owner prepares Apple Developer membership.
- Integration instructions and a validation matrix distinguishing automated,
  native UI, real-account and pending hardware coverage.

### Changed

- The collapsed island now shares the same transparent-glass surface as the
  expanded island instead of rendering as a solid black block, with a
  slightly stronger top scrim so status text stays readable; the
  reduce-transparency and increased-contrast fallbacks are unchanged.

### Fixed

- Bound temporary Foundation log-read buffers between chunks; a local large-log
  sample reduced peak sampled RSS from 535.92 to 103.28 MiB after warm-up.

- Refresh local AI usage every five seconds in common run-loop modes, on
  returning to the usage view, and after wake. Cancel outdated provider/folder
  reads so their results cannot overwrite the current selection.
- Add opt-in automatic Codex account-limit refresh every minute, independently
  of local tracking. Retry failed connections with bounded backoff and keep
  the last successful snapshot visibly marked as stale.
- Read appended JSONL records incrementally, retry unfinished records, and
  rebuild the baseline after log truncation, replacement, or a day change.
  Keep cached numeric data during transient read failures; bound individual
  records to 8 MiB and disclose skipped data as a partial scan.
- Show the last local scan and recorded activity separately from the account
  fetch time. Keep connection errors in the current interface language.
- Update the compact island from fresh live limits and hide expired or stale
  percentages instead of continuing to show an old local snapshot.

### Documentation

- Add prominent bilingual first-launch guidance beside download links, in the
  setup guides and README, and in release notes for the current ad-hoc build.

## [0.6.0] — 2026-10-28

### Changed

- Replace the pale app icon with the original Aurora Orbit identity: vivid
  turquoise, blue, violet and pink glass around a warm coral nucleus on navy.
- Update all ten macOS icon representations, the in-app mark, editable SVGs,
  website icon, repository banner and social preview. Small icon sizes use a
  heavier silhouette and simpler shading for legibility.
- Read the website version and download URLs from the app bundle metadata, so
  the app, site and release assets stay aligned.

### Development and release tooling


- Community and safety files: `SECURITY.md` (private vulnerability
  reporting), `CONTRIBUTING.md`, pull-request and feature-request templates.
- Automated releases: pushing a `v*` tag builds, tests, checks, and publishes
  the DMG/ZIP release with checksums from CI.
- `Scripts/measure.sh` and `PERFORMANCE.md`: repeatable performance sampling
  with the recorded idle baseline (≈1% CPU, 99 MB peak on Apple Silicon).

### Fixed before release

- Find GitHub CLI in `~/.local/bin` when Finder launches the app with a minimal
  PATH; keep explicit PATH entries first. Support user-local Codex CLI too.
- Resolve Regex match totals and text-count labels in the selected language.
- Report the actual bundle version to Codex instead of the old 0.3 identifier.
- Add two regression checks for CLI discovery and developer-tool summaries.

### Language and reliability

- Every service message now resolves to exactly one interface language —
  downloads and drive notifications, weather, stocks, translation, developer
  tool errors, GitHub CLI guidance, and common network failures follow the
  in-app language choice instead of showing both languages concatenated
  (NT-007). Checks grow from 34 to 36 to keep it that way.
- `main` is branch-protected: changes require a green CI.

### Added

- A branded drag-to-Applications DMG with Aurora Orbit artwork, Retina assets,
  fixed Finder layout, a volume icon, and English/Arabic installation guidance.
- Release-package verification covering the mounted app signature, executable
  permissions, Applications destination, Finder layout and unchanged app files.
  Release tooling uses isolated, pinned Python dependencies; existing artifacts
  are replaced only after both the ZIP and DMG pass their checks.

- Redesigned English and Arabic landing pages with a searchable, filterable
  39-feature gallery: 25 captures of the running app with disclosed sample
  data, full-resolution viewing, and per-feature setup notes. Detailed setup
  guides remain at `guide.html` and `guide-ar.html`.
- A real screen recording of the running app in the README and site hero.
- Continuous integration via GitHub Actions: a debug build, the XCTest unit
  tests, and the project checks run on every push and pull request, with no
  signing secrets (NT-003). Generated pages, gallery completeness, and links
  are validated before Pages deployment and in CI.
- `release.sh`: builds the app and packages a DMG with the standard
  drag-to-Applications layout plus a portable zip; both artifacts are
  verified end-to-end, signature included.
- This changelog and a bug report template covering macOS version, screen
  setup, and reproduction steps (NT-004).

### Fixed

- Live Codex account limits now render in their own panel and stay visible
  when local usage reading is paused or when no local logs exist (NT-008).
