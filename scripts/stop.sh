#!/usr/bin/env bash
source "$(dirname "$0")/env.sh"
for instance in ode participants; do
 export CATALINA_HOME="$TC" CATALINA_BASE="$ROOT/.runtime/$instance" CATALINA_PID="$ROOT/.runtime/$instance/tomcat.pid"
 "$TC/bin/catalina.sh" stop
done
