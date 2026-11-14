import socket
import subprocess
from pathlib import Path

assert not Path('/workspace/.metadata/bpel-editor-check.error').exists(), 'BPEL editor failed'
assert Path('/workspace/.metadata/bpel-editor-check.ok').is_file(), 'BPEL editor has not opened'
# The native Eclipse launcher may host the JVM in-process instead of spawning java.
running = False
for process in Path('/proc').iterdir():
    if not process.name.isdigit():
        continue
    try:
        command = (process / 'cmdline').read_bytes().split(b'\0')
        # Docker Desktop/Rosetta may prepend its interpreter to argv.
        if b'/opt/eclipse/eclipse' in command or (
                any(arg.endswith(b'/java') for arg in command)
                and any(b'org.eclipse.equinox.launcher' in arg for arg in command)):
            running = True
    except (FileNotFoundError, PermissionError):
        pass
assert running, 'Eclipse process is not running'
subprocess.run(['xdpyinfo'], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
for port in [5900, 6080]:
    with socket.create_connection(('127.0.0.1', port), timeout=2):
        pass
