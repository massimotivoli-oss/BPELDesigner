"""Align Photon BPEL's obsolete WSDL4J bounds with Photon's WST bundle."""
import re
import sys
import zipfile
from pathlib import Path

plugins = Path(sys.argv[1]) / 'plugins'
patched = 0
for path in sorted(plugins.glob('org.eclipse.bpel*_1.1.2.Final-v20180514-2000.jar')):
    with zipfile.ZipFile(path) as source:
        entries = {entry.filename: source.read(entry) for entry in source.infolist()}
    manifest = entries['META-INF/MANIFEST.MF'].decode().replace('\r\n ', '')
    fixed, count = re.subn(r'javax\.wsdl;bundle-version="\[1\.5\.0,1\.6\.[02][\])]"',
                           'javax.wsdl;bundle-version="[1.6.2,1.7.0)"', manifest)
    if not count:
        continue
    # Modified bundles are local derivatives: discard upstream signature metadata.
    main = fixed.split('\r\n\r\n')[0]
    lines = []
    for line in main.split('\r\n'):
        while len(line.encode()) > 70:
            lines.append(line[:70])
            line = ' ' + line[70:]
        lines.append(line)
    entries['META-INF/MANIFEST.MF'] = ('\r\n'.join(lines) + '\r\n\r\n').encode()
    with zipfile.ZipFile(path, 'w', zipfile.ZIP_DEFLATED) as target:
        for name, data in entries.items():
            if name.startswith('META-INF/') and name.upper().endswith(('.SF', '.RSA', '.DSA', '.EC')):
                continue
            target.writestr(name, data)
    patched += 1
assert patched == 8, f'Unexpected BPEL distribution: patched {patched} bundles'
print(f'Aligned WSDL4J dependency in {patched} BPEL bundles')
