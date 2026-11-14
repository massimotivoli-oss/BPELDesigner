#!/usr/bin/env bash
set -euo pipefail
cd /tmp
base=https://archive.apache.org/dist
download() { curl -fsSL --retry 3 --connect-timeout 30 --max-time 900 "$1" -o "$2"; }
download "$base/tomcat/tomcat-8/v8.5.100/bin/apache-tomcat-8.5.100.tar.gz" tomcat.tgz
download "$base/tomcat/tomcat-8/v8.5.100/bin/apache-tomcat-8.5.100.tar.gz.sha512" tomcat.sha512
download "$base/maven/maven-3/3.9.9/binaries/apache-maven-3.9.9-bin.tar.gz" maven.tgz
download "$base/maven/maven-3/3.9.9/binaries/apache-maven-3.9.9-bin.tar.gz.sha512" maven.sha512
python3 - <<'PY'
import hashlib,re
from pathlib import Path
for name in ['tomcat','maven']:
    expected=re.search(r'\b[0-9a-fA-F]{128}\b',Path(name+'.sha512').read_text()).group().lower()
    assert hashlib.sha512(Path(name+'.tgz').read_bytes()).hexdigest()==expected,name+' checksum mismatch'
PY
mkdir -p /opt/tomcat /opt/maven
tar xzf tomcat.tgz -C /opt/tomcat --strip-components=1
tar xzf maven.tgz -C /opt/maven --strip-components=1
rm -rf /opt/tomcat/webapps/* tomcat.tgz tomcat.sha512 maven.tgz maven.sha512
