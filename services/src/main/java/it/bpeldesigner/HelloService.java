package it.bpeldesigner;

import javax.jws.WebMethod;
import javax.jws.WebParam;
import javax.jws.WebService;

@WebService(
    targetNamespace = "urn:hello",
    serviceName = "HelloService",
    portName = "HelloPort",
    name = "HelloPortType"
)
public class HelloService {
    @WebMethod(operationName = "hello")
    public String hello(@WebParam(name = "name") String name) {
        return "Hello, " + name + "!";
    }
}
