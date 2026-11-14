#!/usr/bin/env bash
set -euo pipefail
python3 /opt/tools/deploy.py
exec /opt/tomcat/bin/catalina.sh run
