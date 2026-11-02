#!/bin/zsh
set -euo pipefail
PROJECT_DIR="${0:A:h}"
CHECK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/notchest-checks.XXXXXX")"
trap 'rm -rf "$CHECK_DIR"' EXIT
swiftc -parse-as-library "$PROJECT_DIR/Sources/Notchest/FocusClock.swift" "$PROJECT_DIR/Sources/Notchest/IslandSizing.swift" "$PROJECT_DIR/Sources/Notchest/ActivityCenter.swift" "$PROJECT_DIR/Sources/Notchest/SystemMonitor.swift" "$PROJECT_DIR/Sources/Notchest/WeatherModel.swift" "$PROJECT_DIR/Sources/Notchest/StocksModel.swift" "$PROJECT_DIR/Sources/Notchest/LyricsService.swift" "$PROJECT_DIR/Sources/Notchest/MusicService.swift" "$PROJECT_DIR/Sources/Notchest/UsageReader.swift" "$PROJECT_DIR/Sources/Notchest/CodexLiveReader.swift" "$PROJECT_DIR/Sources/Notchest/DeveloperModel.swift" "$PROJECT_DIR/Sources/Notchest/NativeTools.swift" "$PROJECT_DIR/Sources/Notchest/AppModel.swift" "$PROJECT_DIR/Sources/Notchest/ServiceText.swift" "$PROJECT_DIR/Sources/Notchest/WorkspacePreferences.swift" "$PROJECT_DIR/Sources/Notchest/SetupModel.swift" "$PROJECT_DIR/Sources/Notchest/UpdateModel.swift" "$PROJECT_DIR/Sources/Notchest/UsageAlerts.swift" "$PROJECT_DIR/Sources/Notchest/ProjectMonitor.swift" "$PROJECT_DIR/Sources/Notchest/HookIntegration.swift" "$PROJECT_DIR/Sources/NotchestCommand/HookPayload.swift" "$PROJECT_DIR/Checks/RunChecks.swift" -o "$CHECK_DIR/NotchestChecks"
"$CHECK_DIR/NotchestChecks"
