#!/usr/bin/env bash
source "$(dirname "$0")/env.sh"
case "$(uname -s)" in
 Darwin) launcher="$ROOT/.ide/Eclipse.app/Contents/MacOS/eclipse" ;;
 Linux) launcher="$ROOT/.ide/eclipse/eclipse" ;;
esac
exec "$launcher" -vm "$JAVA_HOME/bin/java" -data "$ROOT/workspace" "$@"
