import sys
import xml.etree.ElementTree as E
from pathlib import Path

path = Path('/opt/tomcat/conf/server.xml')
tree = E.parse(path)
tree.getroot().set('port', '-1')
for service in tree.getroot().findall('Service'):
    for connector in list(service.findall('Connector')):
        if 'HTTP' in connector.get('protocol', 'HTTP'):
            connector.set('port', sys.argv[1])
            # Reachable by sibling containers. Host publication is loopback-only.
            connector.set('address', '0.0.0.0')
        else:
            service.remove(connector)
tree.write(path, encoding='UTF-8', xml_declaration=True)
