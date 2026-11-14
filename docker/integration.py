"""SOAP integration checks against two independent Tomcat containers."""
import concurrent.futures
import os
import urllib.error
import urllib.request
import xml.etree.ElementTree as E
from xml.sax.saxutils import escape

ode = os.environ.get('ODE_URL', 'http://localhost:8080').rstrip('/')
participant = os.environ.get('PARTICIPANT_URL', 'http://localhost:8081').rstrip('/')
soap_ns = 'http://schemas.xmlsoap.org/soap/envelope/'


def hello(base, endpoint, name):
    body = ('<s:Envelope xmlns:s="' + soap_ns + '" xmlns:h="urn:hello">'
            '<s:Body><h:hello><name>' + escape(name) + '</name></h:hello></s:Body></s:Envelope>')
    request = urllib.request.Request(base + endpoint, data=body.encode(), headers={
        'Content-Type': 'text/xml; charset=utf-8', 'SOAPAction': '""'})
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            xml = response.read()
    except urllib.error.HTTPError as error:
        raise AssertionError('HTTP error from ' + base + ': ' + error.read().decode()) from error
    root = E.fromstring(xml)
    assert root.find('.//{' + soap_ns + '}Fault') is None, xml
    returns = [node.text or '' for node in root.iter() if node.tag.split('}')[-1] == 'return']
    assert returns == ['Ciao, ' + name + '!'], xml


if __name__ == '__main__':
    for base, endpoint in [(participant, '/participants/hello'), (ode, '/ode/processes/Orchestrator')]:
        with urllib.request.urlopen(base + endpoint + '?wsdl', timeout=30) as response:
            root = E.fromstring(response.read())
        assert root.tag == '{http://schemas.xmlsoap.org/wsdl/}definitions', root.tag
        for name in ['Massimo', 'Elena', 'È già & <pronto>', '']:
            hello(base, endpoint, name)
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        list(pool.map(lambda i: hello(ode, '/ode/processes/Orchestrator', 'Richiesta ' + str(i)), range(12)))
    print('PASS: two WSDLs, 4 direct SOAP calls, 4 orchestrated cases, 12 concurrent orchestrations')
