# Changelog

All notable changes to Notchest are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added (toward 0.6)

- Community and safety files: `SECURITY.md` (private vulnerability
  reporting), `CONTRIBUTING.md`, pull-request and feature-request templates.
- Automated releases: pushing a `v*` tag builds, tests, checks, and publishes
  the DMG/ZIP release with checksums from CI.
- `Scripts/measure.sh` and `PERFORMANCE.md`: repeatable performance sampling
  with the recorded idle baseline (≈1% CPU, 99 MB peak on Apple Silicon).

### Changed (toward 0.6)

- Every service message now resolves to exactly one interface language —
  downloads and drive notifications, weather, stocks, translation, developer
  tool errors, GitHub CLI guidance, and common network failures follow the
  in-app language choice instead of showing both languages concatenated
  (NT-007). Checks grow from 34 to 36 to keep it that way.
- `main` is branch-protected: changes require a green CI.

### Added

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
