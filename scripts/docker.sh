#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
command -v docker >/dev/null || { echo 'Installa e avvia Docker Desktop: https://docs.docker.com/desktop/setup/install/mac-install/' >&2; exit 1; }
docker info >/dev/null 2>&1 || { echo 'Avvia Docker Desktop e attendi che il motore sia pronto.' >&2; exit 1; }
docker compose version
case "${1:-up}" in
  up)
    mkdir -p artifacts
    if ! docker compose --progress plain build 2>&1 | tee artifacts/build.log; then
      echo 'Build fallita. Dettagli in artifacts/build.log.' >&2
      bash scripts/collect-docker-evidence.sh
      exit 1
    fi
    if ! docker compose up -d --wait --wait-timeout 600 2>&1 | tee artifacts/startup.log; then
      echo 'Avvio fallito. Dettagli in artifacts/startup.log e artifacts/compose.log.' >&2
      bash scripts/collect-docker-evidence.sh
      exit 1
    fi
    echo 'Eclipse: http://localhost:6080/vnc.html?autoconnect=true&resize=scale'
    ;;
  test)
    docker compose run --build --rm test
    docker compose exec -T ide python3 /opt/tools/ide-health.py
    docker compose exec -T ide cat /workspace/.metadata/bpel-editor-check.ok
    ;;
  restart-test)
    docker compose restart ode participants ide
    docker compose up -d --wait --wait-timeout 600
    bash scripts/docker.sh test
    ;;
  recreate-test)
    # A restart alone cannot prove persistence: the writable container layer survives it.
    docker compose up -d --force-recreate --wait --wait-timeout 600
    bash scripts/docker.sh test
    ;;
  deploy)
    # Restart performs a new snapshot deploy and preserves the ODE database.
    docker compose restart ode
    docker compose up -d --wait --wait-timeout 600
    ;;
  logs) docker compose logs --no-color --tail=200 ;;
  stop) docker compose stop ;;
  down) docker compose down ;;
  *) echo 'Uso: bash scripts/docker.sh {up|test|restart-test|recreate-test|deploy|logs|stop|down}' >&2; exit 2 ;;
esac
