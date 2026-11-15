#!/usr/bin/env bash
set -euo pipefail
# A named volume may initially be root-owned. Never chown the host sources.
chown developer:developer /workspace
mkdir -p /workspace/.metadata
chown developer:developer /workspace/.metadata
rm -f /workspace/.metadata/bpel-editor-check.ok /workspace/.metadata/bpel-editor-check.error
# Keep the distro's window decorations but replace its image wallpaper with
# a solid fill. fbsetbg handles this through the bundled fbsetroot utility.
fluxbox_dir=/home/developer/.fluxbox
mkdir -p "$fluxbox_dir"
if [[ ! -f "$fluxbox_dir/init" ]]; then
    cp /etc/X11/fluxbox/init "$fluxbox_dir/init"
fi
sed '/^background[.:]/d' /usr/share/fluxbox/styles/ubuntu-light > "$fluxbox_dir/lab-style"
printf '\nbackground: flat\nbackground.color: gray25\n' >> "$fluxbox_dir/lab-style"
sed -i '/^session.styleFile:/d' "$fluxbox_dir/init"
printf '\nsession.styleFile: %s/lab-style\n' "$fluxbox_dir" >> "$fluxbox_dir/init"
chown developer:developer "$fluxbox_dir" "$fluxbox_dir/init" "$fluxbox_dir/lab-style"
exec gosu developer /usr/bin/supervisord -n -c /etc/supervisor/conf.d/desktop.conf
