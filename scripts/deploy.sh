#!/usr/bin/env bash
source "$(dirname "$0")/env.sh"
target="$ROOT/.runtime/ode/webapps/ode/WEB-INF/processes"
[[ -d "$ROOT/.runtime/ode/webapps/ode/WEB-INF" ]] || { echo 'Run setup first.' >&2; exit 1; }
mkdir -p "$target"
cp -R "$ROOT/processes/HelloProcess" "$target/"
echo 'HelloProcess copied; ODE hot deployment will compile it. Check ode/logs/catalina.out.'
