# Changelog

All notable changes to Notchest are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

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
