#!/usr/bin/env bash
set -euo pipefail
for url in 'http://127.0.0.1:8081/participants/hello?wsdl' 'http://127.0.0.1:8080/ode/processes/Orchestrator?wsdl'; do
 ready=0
 for attempt in {1..60}; do
  if curl -fsS --max-time 3 "$url" >/dev/null; then ready=1; break; fi
  sleep 2
 done
 [[ "$ready" == 1 ]] || { echo "Not ready: $url" >&2; exit 1; }
done
response="$(curl --fail-with-body -sS --max-time 30 -H 'Content-Type: text/xml; charset=utf-8' -H 'SOAPAction: ""' --data '<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" xmlns:h="urn:hello"><s:Body><h:hello><name>Massimo</name></h:hello></s:Body></s:Envelope>' http://127.0.0.1:8080/ode/processes/Orchestrator)"
SOAP_RESPONSE="$response" python3 - <<'CHECK'
import os,xml.etree.ElementTree as E
root=E.fromstring(os.environ['SOAP_RESPONSE'])
if not any(e.tag.split('}')[-1]=='return' and e.text=='Ciao, Massimo!' for e in root.iter()):
 raise SystemExit('Unexpected SOAP response: '+os.environ['SOAP_RESPONSE'])
print('PASS: client -> ODE :8080 -> JAX-WS :8081 -> client')
CHECK
