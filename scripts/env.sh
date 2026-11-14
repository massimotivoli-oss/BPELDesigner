#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -z "${JAVA_HOME:-}" && -x /usr/libexec/java_home ]]; then
 export JAVA_HOME="$(/usr/libexec/java_home -v 1.8)"
fi
if [[ -z "${JAVA_HOME:-}" || ! -x "$JAVA_HOME/bin/javac" ]]; then echo 'Set JAVA_HOME to a JDK 8 installation.' >&2; exit 1; fi
"$JAVA_HOME/bin/java" -version 2>&1 | head -1 | grep -q '"1.8.' || { echo 'JDK 8 required.' >&2; exit 1; }
export PATH="$JAVA_HOME/bin:$ROOT/.runtime/apache-maven-3.9.9/bin:$PATH"
TC="$ROOT/.runtime/apache-tomcat-8.5.100"
