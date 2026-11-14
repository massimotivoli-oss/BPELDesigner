#!/usr/bin/env bash
set -euo pipefail
# A named volume may initially be root-owned. Never chown the host sources.
chown developer:developer /workspace
mkdir -p /workspace/.metadata
chown developer:developer /workspace/.metadata
rm -f /workspace/.metadata/bpel-editor-check.ok /workspace/.metadata/bpel-editor-check.error
exec gosu developer /usr/bin/supervisord -n -c /etc/supervisor/conf.d/desktop.conf
