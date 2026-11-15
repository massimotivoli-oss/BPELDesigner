#!/usr/bin/env bash
set -euo pipefail
python3 /opt/tools/deploy.py
# Existing database registrations are restored before ODE's deployment poller runs.
java -cp '/opt/tools/classes:/opt/tomcat/webapps/ode/WEB-INF/lib/*' \
    org.apache.ode.store.PrepareHelloProcess \
    /opt/tomcat/webapps/ode/WEB-INF/processes/HelloProcess
exec /opt/tomcat/bin/catalina.sh run
