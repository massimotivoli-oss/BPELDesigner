#!/usr/bin/env bash
source "$(dirname "$0")/env.sh"
mkdir -p "$ROOT/.cache" "$ROOT/.ide"
case "$(uname -s)" in
 Darwin) package=eclipse-jee-photon-R-macosx-cocoa-x86_64.tar.gz; launcher="$ROOT/.ide/Eclipse.app/Contents/MacOS/eclipse" ;;
 Linux) package=eclipse-jee-photon-R-linux-gtk-x86_64.tar.gz; launcher="$ROOT/.ide/eclipse/eclipse" ;;
 *) echo 'Supported installer hosts: macOS and Linux x86_64.' >&2; exit 1 ;;
esac
url="https://archive.eclipse.org/technology/epp/downloads/release/photon/R/$package"
if [[ ! -x "$launcher" ]]; then
 curl -fL --retry 3 "$url" -o "$ROOT/.cache/$package.part"
 # Linux checksum published by Eclipse: https://www.eclipse.org/downloads/packages/file/51981
 if [[ "$(uname -s)" == Linux ]]; then
  python3 - "$ROOT/.cache/$package.part" <<'CHECK'
import hashlib,sys
expected='c7bc139310ccaf899daf7c8846a2d53c14d0fa580036d5ba71494a354bc03939c856bde1f736d7ea804cd28cc6f959e8e4ac59b543718f3e846af716aeec8638'
assert hashlib.sha512(open(sys.argv[1],'rb').read()).hexdigest()==expected, 'Eclipse checksum mismatch'
CHECK
 fi
 mv "$ROOT/.cache/$package.part" "$ROOT/.cache/$package"
 tar xzf "$ROOT/.cache/$package" -C "$ROOT/.ide"
fi
"$launcher" -nosplash -vm "$JAVA_HOME/bin/java"  -application org.eclipse.equinox.p2.director  -repository https://download.eclipse.org/releases/photon/201806271001/  -installIU org.eclipse.bpel.feature.feature.group,org.eclipse.bpel.apache.ode.runtime.feature.feature.group  -acceptLicense
echo 'Eclipse installed. Run scripts/eclipse.sh.'
