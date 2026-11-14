#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")/.."
mkdir -p artifacts
docker compose ps -a > artifacts/compose-status.txt 2>&1
docker compose logs --no-color > artifacts/compose.log 2>&1
docker compose config > artifacts/compose-resolved.yaml 2>&1
docker version > artifacts/docker-version.txt 2>&1
for service in ode participants; do
  mkdir -p "artifacts/$service-logs"
  docker compose cp "$service:/opt/tomcat/logs/." "artifacts/$service-logs/" > "artifacts/$service-log-copy.txt" 2>&1
done
# Existing images may still use the stock WAR's relative log path.
docker compose exec -T ode sh -c 'cat /ode.log /opt/tomcat/ode.log /opt/tomcat/logs/ode.log 2>/dev/null' > artifacts/ode-engine.log 2>&1
if [[ -n "$(docker compose ps --status running -q ide 2>/dev/null)" ]]; then
  mkdir -p artifacts/desktop-logs
  for file in supervisord.log xvfb.log xvfb-error.log eclipse-launcher.log eclipse-launcher-error.log fluxbox.log vnc.log novnc.log; do
    docker compose cp "ide:/tmp/$file" "artifacts/desktop-logs/$file" > /dev/null 2>&1
  done
  docker compose exec -T ide cat /workspace/.metadata/.log > artifacts/eclipse.log 2>&1
  docker compose exec -T ide cat /workspace/.metadata/bpel-editor-check.ok > artifacts/editor-check.txt 2>&1
  docker compose exec -T ide cat /workspace/.metadata/bpel-editor-check.error > artifacts/editor-error.txt 2>&1
  if docker compose exec -T ide xdpyinfo > /dev/null 2>&1 && \
     docker compose exec -T ide python3 /opt/tools/screenshot.py > artifacts/screenshot.log 2>&1; then
    docker compose cp ide:/tmp/eclipse-desktop.png artifacts/eclipse-desktop.png
  else
    echo 'Screenshot non disponibile: desktop non pronto. Gli altri log sono stati raccolti.'
  fi
else
  echo 'IDE non in esecuzione: raccolta log Eclipse saltata. Consultare build.log, startup.log e compose.log.'
fi
# Missing optional GUI evidence must not mask the original build/startup failure.
exit 0
