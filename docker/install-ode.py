import hashlib
import io
import re
import urllib.request
import zipfile
from pathlib import Path

url = 'https://archive.apache.org/dist/ode/apache-ode-war-1.3.8.zip'
with urllib.request.urlopen(url, timeout=180) as response:
    data = response.read()
with urllib.request.urlopen(url + '.sha1', timeout=60) as response:
    checksum = response.read().decode()
expected = re.search(r'\b[0-9a-fA-F]{40}\b', checksum).group().lower()
assert hashlib.sha1(data).hexdigest() == expected, 'ODE checksum mismatch'
target = Path('/opt/tomcat/webapps/ode')
with zipfile.ZipFile(io.BytesIO(data)) as archive:
    wars = [name for name in archive.namelist() if name.endswith('.war')]
    assert len(wars) == 1, wars
    with zipfile.ZipFile(io.BytesIO(archive.read(wars[0]))) as war:
        war.extractall(target)
# Compose preserves both the embedded database and the working directory.
assert (target / 'WEB-INF/derby-jpadb/service.properties').is_file()
(target / 'WEB-INF/work').mkdir(parents=True, exist_ok=True)
# The stock WAR logs engine/deployment errors to a relative ode.log only.
# Keep the file in Tomcat's logs directory and also emit to Docker stdout.
logging = target / 'WEB-INF/classes/log4j2.xml'
text = logging.read_text().replace('fileName="ode.log"', 'fileName="/opt/tomcat/logs/ode.log"')
text = text.replace('<AppenderRef ref="FILE"/>', '<AppenderRef ref="FILE"/><AppenderRef ref="STDOUT"/>')
logging.write_text(text)
# ODE's WAR includes xalan-2.7.1 but omits its separate serializer dependency.
# Without TreeWalker, Axis2 fails to render the WSDL even after a successful deploy.
serializer_url = 'https://repo.maven.apache.org/maven2/xalan/serializer/2.7.1/serializer-2.7.1.jar'
with urllib.request.urlopen(serializer_url, timeout=120) as response:
    serializer = response.read()
assert hashlib.sha256(serializer).hexdigest() == 'a15078d243d4a20b6b4e8ae2f61ed4655e352054e121aada6f7441f1ed445a3c', 'Serializer checksum mismatch'
with zipfile.ZipFile(io.BytesIO(serializer)) as library:
    assert 'org/apache/xml/serializer/TreeWalker.class' in library.namelist()
(target / 'WEB-INF/lib/serializer-2.7.1.jar').write_bytes(serializer)
