from pathlib import Path
import hashlib,re
r=Path(__file__).resolve().parent.parent/'.cache'
for archive,sidecar,algorithm in [('tomcat.tgz','tomcat.sha512','sha512'),('maven.tgz','maven.sha512','sha512'),('ode.zip','ode.sha1','sha1')]:
    expected=re.search(r'(?i)\b[0-9a-f]{%d}\b' % (128 if algorithm=='sha512' else 40),(r/sidecar).read_text())
    actual=hashlib.new(algorithm,(r/archive).read_bytes()).hexdigest()
    if expected is None or actual.lower()!=expected.group().lower():
        raise SystemExit('Checksum mismatch: '+archive)
    print('Verified '+archive)
