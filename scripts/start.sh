#!/usr/bin/env bash
source "$(dirname "$0")/env.sh"
[[ -d "$TC" ]] || { echo 'Run scripts/setup.sh first.' >&2; exit 1; }
for instance in participants ode; do
 export CATALINA_HOME="$TC" CATALINA_BASE="$ROOT/.runtime/$instance" CATALINA_PID="$ROOT/.runtime/$instance/tomcat.pid"
 if [[ -f "$CATALINA_PID" ]] && kill -0 "$(cat "$CATALINA_PID")" 2>/dev/null; then echo "$instance already running"; continue; fi
 export CATALINA_OPTS='-Xms128m -Xmx768m -Djava.awt.headless=true'
 "$TC/bin/catalina.sh" start
done
