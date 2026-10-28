#!/bin/zsh
# Samples CPU and memory of the running Notchest app.
# Usage: ./Scripts/measure.sh [seconds] [label]
set -euo pipefail
DURATION="${1:-60}"
LABEL="${2:-sample}"
APP_PID=$(pgrep -x Notchest | head -1)
[[ -n "$APP_PID" ]] || { print "Notchest is not running"; exit 1 }
print "Sampling Notchest (pid $APP_PID) for ${DURATION}s — $LABEL"
CPU_SUM=0; RSS_MAX=0; N=0
for _ in {1..$DURATION}; do
  STATS=$(ps -o %cpu=,rss= -p "$APP_PID" | tr -s ' ' | sed 's/^ //')
  CPU=${STATS%% *}; RSS=${STATS##* }
  CPU_SUM=$(( CPU_SUM + ${CPU%.*} )); (( RSS > RSS_MAX )) && RSS_MAX=$RSS; N=$(( N + 1 ))
  sleep 1
done
print "label: $LABEL"
print "samples: $N"
print "avg_cpu_percent: $(( CPU_SUM / N ))"
print "peak_rss_mb: $(( RSS_MAX / 1024 ))"
