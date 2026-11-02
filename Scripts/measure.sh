#!/bin/zsh
# Samples an explicitly selected running app, retaining fractional CPU readings.
# Usage: NOTCHEST_PID=123 ./Scripts/measure.sh [seconds] [label]
set -euo pipefail
python3 - "${1:-60}" "${2:-sample}" "${NOTCHEST_PID:-}" <<'PY'
import json, statistics, subprocess, sys, time
seconds=int(sys.argv[1])
if not 1 <= seconds <= 3600:
    raise SystemExit('Duration must be between 1 and 3600 seconds')
label=sys.argv[2]
pid=sys.argv[3]
if not pid:
    found=subprocess.run(['pgrep','-x','Notchest'],capture_output=True,text=True).stdout.split()
    if len(found)!=1:
        raise SystemExit('Run one Notchest instance or set NOTCHEST_PID to the intended process')
    pid=found[0]
if not pid.isdigit():
    raise SystemExit('Invalid process ID')
rows=[]
for _ in range(seconds):
    start=time.monotonic()
    response=subprocess.run(['ps','-o','%cpu=,rss=','-p',pid],capture_output=True,text=True,check=True)
    values=response.stdout.split()
    if len(values)!=2:
        raise SystemExit('The process ended during sampling')
    rows.append((float(values[0]),int(values[1])))
    time.sleep(max(0,1-(time.monotonic()-start)))
print(json.dumps({'label':label,'pid':int(pid),'samples':len(rows),'average_cpu_percent':round(statistics.mean(x[0] for x in rows),2),'peak_rss_mb':round(max(x[1] for x in rows)/1024,2)},indent=2))
PY
