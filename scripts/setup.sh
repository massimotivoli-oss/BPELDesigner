#!/usr/bin/env bash
source "$(dirname "$0")/env.sh"
mkdir -p "$ROOT/.cache" "$ROOT/.runtime"
fetch() { local url="$1" dst="$2"; [[ -f "$dst" ]] || { curl --fail --location --retry 3 "$url" -o "$dst.part"; mv "$dst.part" "$dst"; }; }
base=https://archive.apache.org/dist
fetch "$base/tomcat/tomcat-8/v8.5.100/bin/apache-tomcat-8.5.100.tar.gz" "$ROOT/.cache/tomcat.tgz"
fetch "$base/tomcat/tomcat-8/v8.5.100/bin/apache-tomcat-8.5.100.tar.gz.sha512" "$ROOT/.cache/tomcat.sha512"
fetch "$base/maven/maven-3/3.9.9/binaries/apache-maven-3.9.9-bin.tar.gz" "$ROOT/.cache/maven.tgz"
fetch "$base/maven/maven-3/3.9.9/binaries/apache-maven-3.9.9-bin.tar.gz.sha512" "$ROOT/.cache/maven.sha512"
fetch "$base/ode/apache-ode-war-1.3.8.zip" "$ROOT/.cache/ode.zip"
fetch "$base/ode/apache-ode-war-1.3.8.zip.sha1" "$ROOT/.cache/ode.sha1"
python3 "$ROOT/scripts/verify-downloads.py"
[[ -d "$TC" ]] || tar xzf "$ROOT/.cache/tomcat.tgz" -C "$ROOT/.runtime"
[[ -d "$ROOT/.runtime/apache-maven-3.9.9" ]] || tar xzf "$ROOT/.cache/maven.tgz" -C "$ROOT/.runtime"
python3 "$ROOT/scripts/configure.py"
mvn -B -f "$ROOT/services/pom.xml" clean package
cp "$ROOT/services/target/participants.war" "$ROOT/.runtime/participants/webapps/"
echo 'Setup completed. Run scripts/start.sh, scripts/deploy.sh, scripts/smoke.sh.'
