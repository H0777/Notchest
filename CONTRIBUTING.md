# Contributing to Notchest

Thanks for helping — pull requests that fit the roadmap land fastest.

## Getting started

```sh
git clone https://github.com/H0777/Notchest.git
cd Notchest
swift build          # or open Package.swift in Xcode 26+
./check.sh           # must pass (36 checks)
```

`swift test` needs a full Xcode installation; command-line tools alone do not
include XCTest. CI runs the same build, tests, and checks on every pull
request — a green CI is required before merge.

## Ground rules

- **SwiftUI + AppKit, feature-first.** Keep services out of views: models read
  data, views render it.
- **Two languages, one string.** User-visible wording carries both Arabic and
  English: views use `app.text("عربي", "English")`, service layers use
  `ServiceText("عربي", "English")` and resolve with the language flag. Never
  concatenate both languages into one string — the checks reject it.
- **Honest feature status.** A feature ships as "complete" only with
  validation evidence, never merely because its UI exists. Update
  `FEATURES.md` and `CHANGELOG.md` with your change.
- **Privacy is a feature.** No telemetry, no accounts, no keys in the repo.
  New permissions need a usage description in `Resources/Info.plist` and a
  note in the docs.
- **Small, reviewable diffs.** One concern per pull request.

## Suggested flow

1. Check [ROADMAP.md](ROADMAP.md) and open an issue describing the change.
2. Branch from `main`.
3. Add or update checks in `Checks/RunChecks.swift` when your change has
   testable behavior.
4. Open a pull request; CI must pass; a maintainer reviews.
