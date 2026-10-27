# Changelog

## Unreleased — visual feature gallery

- Redesign the English and Arabic Pages landing pages with a searchable, filterable 39-feature gallery.
- Add 25 captures of the running app with disclosed documentation sample data, full-resolution viewing, and feature-specific setup notes.
- Preserve the detailed setup guides at `guide.html` and `guide-ar.html`.
- Refresh the repository README, brand banner, social-sharing metadata, sitemap, and crawler hints.
- Validate generated pages, gallery completeness, image files, local links, and anchors before Pages deployment and in CI.


All notable changes to Notchest are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Removed

- The hero "interface" image: it was a composed marketing render, not a real
  screenshot — it does not belong in this repository. Real captures of the
  actual app will replace it in the README and the documentation site.

### Fixed

- Live Codex account limits now render in their own panel and stay visible
  when local usage reading is paused or when no local logs exist. Previously a
  successful connection could remain hidden behind the "No logs found" or
  "Usage tracking is paused" states (NT-008).

### Added

- Continuous integration via GitHub Actions: a debug build, the XCTest unit
  tests and the project checks run on every push and pull request, with no
  signing secrets (NT-003).
- This changelog and a bug report template covering macOS version, screen
  setup and reproduction steps (NT-004).
- `release.sh`: builds the app and packages two release artifacts — a DMG
  with the standard drag-to-Applications layout and a portable zip. Both were
  verified end-to-end: signature intact inside each container, executable
  permissions preserved. Install docs cover the DMG path and the one-time
  Gatekeeper confirmation while the app is unsigned.

## Before this repository

The app was developed under the working name "Halo" up to version 0.5, before
this repository existed. It was renamed to **Notchest** at publication, and the
name was verified to be unused on GitHub and the wider web. The first commit
captures the 0.5 baseline under the new name; `FEATURES.md` describes the
feature state at that point, and `ROADMAP.md` the plan from there to 1.0.

### Changed (at rename)

- Project, package, targets, bundle identifier, docs, and brand assets renamed
  from "Halo" to "Notchest". The full package rebuilds and all 34 checks pass
  after the rename.
