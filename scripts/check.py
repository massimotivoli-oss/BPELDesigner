from pathlib import Path
import subprocess,xml.etree.ElementTree as E
r=Path(__file__).resolve().parent.parent
for f in r.rglob('*'):
    if any(p.startswith('.') and p not in ('.project',) for p in f.relative_to(r).parts): continue
    if f.is_file() and (f.suffix in ('.xml','.wsdl','.bpel') or f.name=='.project'):
        E.parse(f)
for f in (r/'scripts').glob('*.sh'): subprocess.run(['bash','-n',str(f)],check=True)
ns={'b':'http://docs.oasis-open.org/wsbpel/2.0/process/executable','w':'http://schemas.xmlsoap.org/wsdl/','s':'http://schemas.xmlsoap.org/wsdl/soap/'}
b=E.parse(r/'processes/HelloProcess/HelloProcess.bpel')
assert b.find('b:sequence/b:invoke',ns).get('partnerLink')=='participant'
w=E.parse(r/'processes/HelloProcess/Hello.wsdl')
addresses={e.get('location') for e in w.findall('.//s:address',ns)}
assert addresses=={'http://localhost:8081/participants/hello','http://localhost:8080/ode/processes/Orchestrator'}
print('PASS: XML syntax, shell syntax, orchestration link and separate HTTP endpoints')
