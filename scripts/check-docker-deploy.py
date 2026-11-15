"""Check namespace-safe Docker deployment without needing a Docker daemon."""
import subprocess
import tempfile
import xml.etree.ElementTree as E
from pathlib import Path

root = Path(__file__).resolve().parent.parent
original = root / 'processes/HelloProcess/bpelContent/Hello.wsdl'
before = original.read_bytes()
with tempfile.TemporaryDirectory(prefix='bpeldesigner-deploy-') as directory:
    target = Path(directory)
    legacy = target / 'HelloProcess'
    legacy.mkdir()
    for name in ['HelloProcess.bpel', 'Hello.wsdl', 'HelloProcess.cbp']:
        (legacy / name).write_text('legacy deployment')
    # Unrelated packages/files must survive the migration.
    (legacy / 'unrelated.txt').write_text('keep')
    subprocess.run(['python3', str(root / 'docker/deploy.py'), str(root / 'processes'), str(target)], check=True)
    deployed = target / 'HelloProcess/bpelContent/Hello.wsdl'
    # WSDL contains QName-valued attributes. Their namespace declarations must survive.
    namespaces = {}
    for _, declaration in E.iterparse(deployed, events=['start-ns']):
        namespaces[declaration[0]] = declaration[1]
    assert namespaces['tns'] == 'urn:hello'
    assert namespaces['xs'] == 'http://www.w3.org/2001/XMLSchema'
    assert namespaces['plnk'] == 'http://docs.oasis-open.org/wsbpel/2.0/plnktype'
    addresses = {node.get('location') for node in E.parse(deployed).findall(
        './/{http://schemas.xmlsoap.org/wsdl/soap/}address')}
    assert addresses == {'http://participants:8081/participants/hello', 'http://ode:8080/ode/processes/Orchestrator'}
    for name in ['bpelContent/HelloProcess.bpel', 'bpelContent/HelloProcessArtifacts.wsdl', 'deploy.xml']:
        assert (target / 'HelloProcess' / name).read_bytes() == (original.parent.parent / name).read_bytes()
    artifact_ns = {prefix: uri for _, (prefix, uri) in E.iterparse(
        target / 'HelloProcess/bpelContent/HelloProcessArtifacts.wsdl', events=['start-ns'])}
    # Keep declarations referenced by QName-valued attributes in the artifacts WSDL too.
    assert artifact_ns['h'] == 'urn:hello'
    assert not (target / 'HelloProcess/.settings').exists(), 'IDE metadata was deployed'
    for name in ['HelloProcess.bpel', 'Hello.wsdl', 'HelloProcess.cbp']:
        assert not (legacy / name).exists(), 'Obsolete root process survived migration'
    assert (legacy / 'unrelated.txt').read_text() == 'keep'
    assert original.read_bytes() == before, 'Deployment modified host sources'
print('PASS: Docker deployment preserves WSDL namespaces and source files; uses container DNS')
