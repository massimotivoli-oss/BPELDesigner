from pathlib import Path
import subprocess,xml.etree.ElementTree as E
r=Path(__file__).resolve().parent.parent
for f in r.rglob('*'):
    if any(p.startswith('.') and p not in ('.project',) for p in f.relative_to(r).parts): continue
    if f.is_file() and (f.suffix in ('.xml','.wsdl','.bpel') or f.name=='.project'):
        E.parse(f)
for f in (r/'scripts').glob('*.sh'): subprocess.run(['bash','-n',str(f)],check=True)
ns={'b':'http://docs.oasis-open.org/wsbpel/2.0/process/executable','w':'http://schemas.xmlsoap.org/wsdl/','s':'http://schemas.xmlsoap.org/wsdl/soap/'}
b=E.parse(r/'processes/HelloProcess/bpelContent/HelloProcess.bpel')
assert b.find('b:sequence/b:invoke',ns).get('partnerLink')=='participant'
w=E.parse(r/'processes/HelloProcess/bpelContent/Hello.wsdl')
addresses={e.get('location') for e in w.findall('.//s:address',ns)}
assert addresses=={'http://localhost:8081/participants/hello','http://localhost:8080/ode/processes/Orchestrator'}
print('PASS: XML syntax, shell syntax, orchestration link and separate HTTP endpoints')

project = r / 'processes/HelloProcess'
metadata = E.parse(project / '.project')
assert 'org.eclipse.bpel.validator.builder' in {
    node.text for node in metadata.findall('buildSpec/buildCommand/name')
}
assert 'org.eclipse.wst.common.project.facet.core.nature' in {
    node.text for node in metadata.findall('natures/nature')
}
facets = E.parse(project / '.settings/org.eclipse.wst.common.project.facet.core.xml')
assert facets.find("installed[@facet='bpel.facet.core'][@version='2.0']") is not None
component = E.parse(project / '.settings/org.eclipse.wst.common.component')
assert component.find("wb-module/wb-resource[@source-path='/bpelContent'][@deploy-path='/']") is not None
assert (project / 'deploy.xml').is_file()
print('PASS: HelloProcess BPEL 2.0 facet, builder, content mapping and root deployment descriptor')

artifacts = E.parse(project / 'bpelContent/HelloProcessArtifacts.wsdl')
assert artifacts.getroot().get('targetNamespace') == 'urn:helloArtifacts'
assert artifacts.find("w:import[@namespace='urn:hello'][@location='Hello.wsdl']", ns) is not None
link_ns = {'p': 'http://docs.oasis-open.org/wsbpel/2.0/plnktype'}
link = artifacts.find("p:partnerLinkType[@name='HelloPortTypePLT']", link_ns)
assert link is not None
role = link.find("p:role[@name='HelloPortTypeRole']", link_ns)
assert role is not None and role.get('portType') == 'h:HelloPortType'
assert b.find("b:import[@namespace='urn:helloArtifacts'][@location='HelloProcessArtifacts.wsdl']", ns) is not None
client = b.find("b:partnerLinks/b:partnerLink[@name='client']", ns)
assert client.get('partnerLinkType') == 'a:HelloPortTypePLT'
assert client.get('myRole') == 'HelloPortTypeRole'
print('PASS: wizard-style artifacts WSDL import, client partner-link type and role')
