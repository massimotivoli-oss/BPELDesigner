from pathlib import Path
import shutil,zipfile,io
import xml.etree.ElementTree as E
r=Path(__file__).resolve().parent.parent
runtime=r/'.runtime'
for name,http,shutdown,ajp in [('ode',8080,8005,8009),('participants',8081,8006,8010)]:
    base=runtime/name
    for directory in ['conf','logs','temp','webapps','work']:
        (base/directory).mkdir(parents=True,exist_ok=True)
    for f in (runtime/'apache-tomcat-8.5.100/conf').iterdir():
        if f.is_file() and not (base/'conf'/f.name).exists(): shutil.copy2(f,base/'conf'/f.name)
    tree=E.parse(base/'conf/server.xml');root=tree.getroot();root.set('port',str(shutdown));root.set('address','127.0.0.1')
    for service in root.findall('Service'):
        for c in list(service.findall('Connector')):
            if 'HTTP' in c.get('protocol','HTTP'): c.set('port',str(http));c.set('address','127.0.0.1')
            else: service.remove(c)
    tree.write(base/'conf/server.xml',encoding='UTF-8',xml_declaration=True)
# Expand before starting Tomcat, so BPEL deploy has a deterministic target.
if not (runtime/'ode/webapps/ode/WEB-INF').exists():
    with zipfile.ZipFile(r/'.cache/ode.zip') as z:
        wars=[n for n in z.namelist() if n.endswith('.war')]
        if len(wars)!=1: raise SystemExit('Expected one ODE WAR: '+repr(wars))
        with zipfile.ZipFile(io.BytesIO(z.read(wars[0]))) as war: war.extractall(runtime/'ode/webapps/ode')
