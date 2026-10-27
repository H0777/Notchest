# Feature gallery and screenshot provenance

The website contains **39 feature entries illustrated by 25 captures** of the
running Notchest SwiftUI/AppKit interface. Related tools share a capture of their
actual panel. The website provides descriptions, setup notes, filtering, search,
and full-resolution image viewing in English and Arabic.

## What the images show

These are app captures, not AI-generated interfaces or painted UI mockups.
A separate documentation build uses illustrative notes, files, snippets, usage
counters, system readings, weather conditions, task events, calendar entries,
shortcut names, and an original demonstration music track. This is disclosed in
the gallery, relevant feature notes, and the capture FAQ. Where setup is required,
the capture shows the setup controls rather than implying a personal account is
connected. No personal account data, private clipboard, API keys, camera imagery,
or personal calendar events were used.

The terminal runs a real isolated interactive shell in `/tmp/Notchest-Demo`;
the command-runner example executes `printf` and displays its actual result.
No music was played, and no camera, calendar, accessibility, or recording
permissions were granted to produce these images.

The native UI source baseline is commit `b954529`. Documentation fixtures are
kept in `Scripts/gallery/`, outside production `Sources/`. The preparation script
copies the app into an ignored build directory, injects demonstration models,
skips background-service startup, and uses a separate bundle identifier. The
release app is unchanged by the gallery work.

## Regenerate the capture build

On a Mac with the project's build prerequisites:

```sh
python3 Scripts/gallery/prepare.py
NOTCHEST_BUILD_DIR="$PWD/.build/gallery-products" \
  .build/gallery-source/build.sh "$PWD/dist/Notchest-Gallery.app"
/usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier dev.notchest.gallery' \
  dist/Notchest-Gallery.app/Contents/Info.plist
/usr/libexec/PlistBuddy -c 'Set :CFBundleDisplayName Notchest Gallery' \
  dist/Notchest-Gallery.app/Contents/Info.plist
codesign --force --sign - dist/Notchest-Gallery.app
```

Launch only the prepared gallery bundle. Capture the app window while navigating
the relevant tabs. Save the original high-resolution captures as JPEGs under
`site/assets/screenshots/`. Do not capture connected personal accounts or grant
additional permissions for documentation.

The site applies the app's exact outline as a CSS mask to the JPEG's empty outer
corners. Captured interface pixels and displayed content are otherwise unchanged.
The identity banner and social card are separate brand artwork, generated with
`swift Scripts/generate-repo-art.swift`; neither is presented as an app capture.

## Capture map

| Capture | Feature coverage |
| --- | --- |
| `overview.jpg` | Overview and keep-awake entry |
| `focus.jpg`, `stopwatch.jpg` | Focus modes |
| `notes.jpg` | Autosaved notes |
| `clipboard.jpg` | Opt-in clipboard and search |
| `shelf.jpg` | File/app shelf, open/reveal/share actions |
| `terminal.jpg`, `commands.jpg` | Interactive shell and command runner |
| `code.jpg` | JSON, encodings, hashes, IDs, time, counters, regex |
| `git.jpg`, `github.jpg` | Git state and GitHub setup |
| `snippets.jpg` | Saved snippets |
| `activity.jpg` | Local activity API and optional monitors |
| `ai.jpg` | Illustrative local usage and account-limit entry |
| `system.jpg` | Example system readings, audio and window controls |
| `music.jpg`, `media-tools.jpg` | Demo music, original lyrics, camera entry |
| `file-tools.jpg` | Capture, OCR, colors, conversion and archives |
| `daily.jpg` | Calculator, browser search, Shortcuts, calendar/reminder entries |
| `weather.jpg`, `translation.jpg`, `stocks.jpg` | Sample current weather and connected-tool setup |
| `settings.jpg`, `startup.jpg` | Dimensions, appearance, motion and startup |
| `arabic.jpg` | Actual right-to-left Arabic layout |

## Maintain the website

- Edit `site/features.json` for bilingual feature copy and capture mappings.
- Run `python3 Scripts/build-site.py` to regenerate both landing pages.
- Run `python3 Scripts/check-site.py` to validate the built artifact.
- Pages and CI workflows validate the gallery before publishing.

Documentation copy and setup requirements remain part of review; the validation
script checks completeness and links, not whether an unsupported feature works.
