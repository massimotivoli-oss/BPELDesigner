#!/usr/bin/env bash
source "$(dirname "$0")/env.sh"
target="$ROOT/.runtime/ode/webapps/ode/WEB-INF/processes"
[[ -d "$ROOT/.runtime/ode/webapps/ode/WEB-INF" ]] || { echo 'Run setup first.' >&2; exit 1; }
mkdir -p "$target"
# Remove the old root sources/compiled process when upgrading this example.
python3 - "$target/HelloProcess" <<'PYTHON'
from pathlib import Path
import sys

project = Path(sys.argv[1])
for name in ['HelloProcess.bpel', 'Hello.wsdl', 'HelloProcess.cbp']:
    legacy = project / name
    if legacy.is_file():
        legacy.unlink()
PYTHON
cp -R "$ROOT/processes/HelloProcess" "$target/"
# Prepare the relocated compiled process for ODE's process registry.
mkdir -p "$ROOT/.runtime/ode-prepare"
javac -encoding UTF-8 -cp "$ROOT/.runtime/ode/webapps/ode/WEB-INF/lib/*" \
    -d "$ROOT/.runtime/ode-prepare" "$ROOT/docker/PrepareHelloProcess.java"
java -cp "$ROOT/.runtime/ode-prepare:$ROOT/.runtime/ode/webapps/ode/WEB-INF/lib/*" \
    org.apache.ode.store.PrepareHelloProcess "$target/HelloProcess"
echo 'HelloProcess copied and prepared for ODE hot deployment. Check ode/logs/catalina.out.'
