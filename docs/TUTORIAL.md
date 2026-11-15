# Student tutorial: from Java service to BPEL orchestration

This exercise adds a `GreetingService` to the participant Tomcat and a `GreetingProcess` to Apache ODE. The existing HelloProcess stays available for the built-in healthchecks and regression tests.

You need a running Docker environment ([first launch](../README.md#first-launch)), a terminal in the repository root, and a text editor or the browser-based Eclipse desktop. Commands assume Bash on macOS or Linux. The process-copy command also requires host Python 3; no host Java or Maven installation is needed.

Allow time for the first Docker build. All paths below are relative to the repository root unless they start with `/project`, which is the same checkout inside Eclipse.

## 1. Understand the running example

Read these files before starting:

| File | Purpose |
|---|---|
| `services/src/main/java/it/bpeldesigner/HelloService.java` | Java endpoint implementation and JAX-WS annotations |
| `services/src/main/webapp/WEB-INF/sun-jaxws.xml` | Metro endpoint implementation and URL |
| `services/src/main/webapp/WEB-INF/web.xml` | Servlet registration and URL mapping |
| `services/pom.xml` | Java 8, Metro 2.3.7, and WAR build |
| `processes/HelloProcess/Hello.wsdl` | Messages, port type, SOAP binding, services, and partner-link type |
| `processes/HelloProcess/HelloProcess.bpel` | Receive → Invoke → Reply |
| `processes/HelloProcess/deploy.xml` | ODE mapping between BPEL partner links and WSDL service/port names |

The request flow is:

```text
Your SOAP client
  → localhost:8080/ode/processes/Orchestrator
  → participants:8081/participants/hello (from ODE)
  → Hello, <name>!
```

`localhost` inside ODE means the ODE container itself. It does not mean your computer or the participant container. Clients on your computer use `localhost:8080` and `localhost:8081`; container-to-container calls use Compose service names `ode` and `participants`.

The deployment script rewrites the exact WSDL prefixes `http://localhost:8081/` to `http://participants:8081/` and `http://localhost:8080/` to `http://ode:8080/` in ODE's copies. Other hostnames, ports, XSDs, and dynamic endpoint references are not rewritten.

## 2. Create a new JAX-WS service

In Eclipse, import **File → Import → Maven → Existing Maven Projects**, root `/project/services`. Create the Java class in the `it.bpeldesigner` package, or use your host editor.

### Implement the endpoint

Create `services/src/main/java/it/bpeldesigner/GreetingService.java`:

```java
package it.bpeldesigner;

import javax.jws.WebMethod;
import javax.jws.WebParam;
import javax.jws.WebService;

@WebService(
    targetNamespace = "urn:greeting",
    serviceName = "GreetingService",
    portName = "GreetingPort",
    name = "GreetingPortType"
)
public class GreetingService {
    @WebMethod(operationName = "greeting")
    public String greeting(@WebParam(name = "name") String name) {
        return "Hello, " + name + "!";
    }
}
```

Use `javax.jws` with the pinned Metro 2.3.7 / Java 8 stack. Keep the existing Maven settings for this exercise.

### Register the endpoint in Metro

In `services/src/main/webapp/WEB-INF/sun-jaxws.xml`, add this element **inside the existing `<endpoints>` root**, alongside HelloService:

```xml
<endpoint name="GreetingService"
          implementation="it.bpeldesigner.GreetingService"
          url-pattern="/greeting"/>
```

### Map the servlet

In `services/src/main/webapp/WEB-INF/web.xml`, add these elements **inside the existing `<web-app>` root**. Keep the existing listener and HelloService servlet/mapping. Place the new servlet with the servlet declarations and its mapping with the mappings:

```xml
<servlet>
  <servlet-name>GreetingService</servlet-name>
  <servlet-class>com.sun.xml.ws.transport.http.servlet.WSServlet</servlet-class>
  <load-on-startup>2</load-on-startup>
</servlet>
<servlet-mapping>
  <servlet-name>GreetingService</servlet-name>
  <url-pattern>/greeting</url-pattern>
</servlet-mapping>
```

The mapping must match Metro's `/greeting` path. The application context `/participants` comes from `participants.war`, not from the Java package or service name. Multiple service classes share this WAR and Tomcat in this exercise.

### Build and deploy on the participant Tomcat

```bash
docker compose up -d --build --wait --wait-timeout 600 participants
curl --fail --silent --show-error 'http://localhost:8081/participants/greeting?wsdl'
```

The Docker build runs Maven inside the `service-build` stage, packages the WAR, and installs it in `/opt/tomcat/webapps/participants.war` in the participant image. You do not need Tomcat Manager, a manual WAR upload, or Eclipse's server adapter. Inspect failures with `docker compose logs --tail=200 participants`.

The returned WSDL should describe namespace `urn:greeting`, port type `GreetingPortType`, service `GreetingService`, port `GreetingPort`, and operation `greeting`. Inspect its imported schemas as well if Metro separates them from the WSDL.

### Call the service directly

Create an ignored request file for use throughout this tutorial:

```bash
mkdir -p artifacts
cat > artifacts/greeting-request.xml <<'XML'
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"
            xmlns:g="urn:greeting">
  <s:Body>
    <g:greeting><name>Ada</name></g:greeting>
  </s:Body>
</s:Envelope>
XML

curl --fail-with-body --silent --show-error \
  -H 'Content-Type: text/xml; charset=utf-8' \
  -H 'SOAPAction: ""' \
  --data-binary @artifacts/greeting-request.xml \
  http://localhost:8081/participants/greeting
```

Expect a SOAP response containing `<return>Hello, Ada!</return>`; XML prefixes may vary. The wrapper `g:greeting` belongs to `urn:greeting`, while the child `name` is unqualified. HTTP 200 alone is insufficient: inspect the returned value and check for SOAP faults.

### Create and run a Java client in Eclipse

You can also test the service with a Java `main` program and read its response in the Eclipse Console. Create a separate Java project for clients, so test programs stay outside the participant WAR.

#### Create the client project

1. In the browser-based Eclipse desktop, choose **File → New → Java Project** (or **File → New → Other → Java → Java Project**).
2. Enter `GreetingClients` as the project name, clear **Use default location**, and set the location to `/project/clients/greeting`.
3. Select the installed **JavaSE-1.8 / JDK 8** execution environment and keep separate source/output folders, `src` and `bin`. Click **Finish**. If Eclipse offers to switch to the Java perspective, accept.

The Java 8 JDK includes the JAX-WS client APIs and `wsimport`; this plain Java client project needs no additional Maven dependencies. These instructions target the pinned JDK 8 environment; newer JDKs do not necessarily include those tools or APIs.

#### Generate Java types from the service WSDL

After deploying GreetingService, run this command **from your host terminal**, in the repository root:

```bash
docker compose exec -T --user developer ide bash -c '
  cd /project/clients/greeting &&
  wsimport -keep -Xnocompile -s src \
    -p it.bpeldesigner.client.generated \
    http://participants:8081/participants/greeting?wsdl
'
```

The command executes the JDK tool **inside the IDE container**. `-s src` writes Java sources into the client project, `-p` selects their package, and `-Xnocompile` leaves compilation to Eclipse. The generated code includes `GreetingService`, the `GreetingPortType` service interface, and request/response types. Do not edit generated sources; regenerate them when the service contract changes.

In Eclipse, select `GreetingClients` and press **F5 / Refresh**. With **Project → Build Automatically** enabled, Eclipse compiles the generated files. Check the Problems view if it reports errors; confirm that the project's JRE System Library is JavaSE-1.8.

#### Write the client program

Under `GreetingClients/src`, create package `it.bpeldesigner.client`, then class `GreetingServiceClient` with a `public static void main(String[] args)` method. Paste:

```java
package it.bpeldesigner.client;

import java.net.URL;
import javax.xml.ws.BindingProvider;
import it.bpeldesigner.client.generated.GreetingPortType;
import it.bpeldesigner.client.generated.GreetingService;

public class GreetingServiceClient {
    public static void main(String[] args) throws Exception {
        String endpoint = "http://participants:8081/participants/greeting";
        GreetingService service = new GreetingService(new URL(endpoint + "?wsdl"));
        GreetingPortType port = service.getGreetingPort();

        // Use the endpoint reachable from the IDE container, regardless of
        // the address advertised in the downloaded WSDL.
        ((BindingProvider) port).getRequestContext().put(
            BindingProvider.ENDPOINT_ADDRESS_PROPERTY, endpoint);

        String response = port.greeting("Ada");
        System.out.println("Service response: " + response);
        if (!"Hello, Ada!".equals(response)) {
            throw new AssertionError("Unexpected service response: " + response);
        }
    }
}
```

`wsimport` converts the WSDL operation into the Java method `greeting(String)`. The client calls the SOAP endpoint through that generated interface and receives the operation's return value as a Java `String`; it does not need to build or parse XML manually. The explicit endpoint override matters because a WSDL can advertise a `localhost` address that is unreachable from a different container.

#### Run it and inspect standard output

Right-click `GreetingServiceClient.java` → **Run As → Java Application**. Open **Window → Show View → Console** if needed, and select this Java application's console. Expect:

```text
Service response: Hello, Ada!
```

`System.out.println` writes to the Eclipse Console for the launched application. SOAP faults or connection failures appear as exceptions in the same console; an unexpected return value triggers the assertion. This client runs in the IDE container, so use `participants:8081`, not `localhost:8081`. No server redeploy is needed after changing just the client: save and run it again.

If you later run the client on your host with a compatible Java setup, change `endpoint` to `http://localhost:8081/participants/greeting`; both the WSDL download and the SOAP invocation must use an address reachable from the machine running the client.

## 3. Create a new BPEL process

### Create a separate deployment unit

For the first exercise, copy the working process and consistently rename its contract. Run the following once from the repository root; it refuses to overwrite an existing exercise directory:

```bash
python3 - <<'PY'
from pathlib import Path

source = Path('processes/HelloProcess')
target = Path('processes/GreetingProcess')
target.mkdir(exist_ok=False)
files = {
    'Hello.wsdl': 'Greeting.wsdl',
    'HelloProcess.bpel': 'GreetingProcess.bpel',
    'deploy.xml': 'deploy.xml',
    '.project': '.project',
}
for old, new in files.items():
    text = (source / old).read_text()
    text = text.replace('urn:orchestrator', 'urn:greeting-orchestrator')
    text = text.replace('Orchestrator', 'GreetingOrchestrator')
    text = text.replace('Hello', 'Greeting').replace('hello', 'greeting')
    (target / new).write_text(text)
print('Created processes/GreetingProcess')
PY
```

The folder now contains `.project`, `Greeting.wsdl`, `GreetingProcess.bpel`, and `deploy.xml`. This particular replacement works because the example and the new service deliberately use the same request/response shape. It is not a general way to generate BPEL contracts from arbitrary Java classes.

In Eclipse, use **File → Import → General → Existing Projects into Workspace**, root `/project/processes/GreetingProcess`, without copying the project into the workspace. Open `GreetingProcess.bpel` with the BPEL editor and inspect Receive, CallParticipant, and Reply. Refresh the project if you created files from a terminal.

### Inspect the WSDL contract

`Greeting.wsdl` declares:

| Item | Value |
|---|---|
| Target namespace | `urn:greeting` |
| Request / response elements and messages | `greeting` / `greetingResponse` |
| Port type / operation | `GreetingPortType` / `greeting` |
| Participant service / port | `GreetingService` / `GreetingPort` |
| Participant source address | `http://localhost:8081/participants/greeting` |
| Process service / port | `GreetingOrchestratorService` / `GreetingOrchestratorPort` |
| Process source address | `http://localhost:8080/ode/processes/GreetingOrchestrator` |
| Partner-link type / role | `GreetingLink` / `provider` |

The contract includes a SOAP document/literal binding and a BPEL partner-link type. Metro's generated WSDL supplies the Java service contract, but does not supply your BPEL partner links or ODE deployment descriptor. For this exercise, the copied WSDL intentionally describes both the participant and orchestration services using the same operation and messages.

### Inspect the BPEL activities

`GreetingProcess.bpel` must have process name `GreetingProcess`, target namespace `urn:greeting-orchestrator`, and an import of `Greeting.wsdl` for namespace `urn:greeting`.

1. **Receive** uses partner link `client`, operation `greeting`, request variable `request`, and `createInstance="yes"` to start an instance.
2. **CallParticipant** invokes partner link `participant`, using `request` as input and `response` as output.
3. **Reply** returns `response` to `client` for the same operation.

The client partner link uses `myRole="provider"`; the participant uses `partnerRole="provider"`. Both refer to `GreetingLink`. The message variables refer to the WSDL message QNames, not Java type names.

### Inspect the ODE descriptor

The generated `deploy.xml` is equivalent to:

```xml
<deploy xmlns="http://www.apache.org/ode/schemas/dd/2007/03"
        xmlns:p="urn:greeting-orchestrator"
        xmlns:g="urn:greeting">
  <process name="p:GreetingProcess">
    <active>true</active>
    <retired>false</retired>
    <provide partnerLink="client">
      <service name="g:GreetingOrchestratorService"
               port="GreetingOrchestratorPort"/>
    </provide>
    <invoke partnerLink="participant">
      <service name="g:GreetingService" port="GreetingPort"/>
    </invoke>
  </process>
</deploy>
```

The descriptor's process QName must match the BPEL process. Each `partnerLink` must match its BPEL declaration; service QNames and port names must match the WSDL. Prefix spelling is arbitrary, but the bound namespace URI is significant.

### Deploy on Apache ODE

```bash
bash scripts/docker.sh deploy
docker compose logs --tail=200 ode
curl --fail --silent --show-error \
  'http://localhost:8080/ode/processes/GreetingOrchestrator?wsdl'
```

On ODE startup, `docker/deploy.py` scans immediate subdirectories of `/processes` with a `deploy.xml`. It copies `.bpel`, `.wsdl`, `.xsd`, and `.xml` files, including nested files, into `/opt/tomcat/webapps/ode/WEB-INF/processes/<folder>`, copying the descriptor last. ODE compiles each deployment unit. This restarts ODE and interrupts in-flight requests; use it between laboratory test runs.

The Compose ODE healthcheck still checks the original Orchestrator. A successful deploy command therefore does not prove that your new process compiled: inspect ODE logs and fetch the new WSDL explicitly. A new endpoint may take a short time to appear.

## 4. Test the complete orchestration

Use the same SOAP request, now addressed to ODE:

```bash
curl --fail-with-body --silent --show-error \
  -H 'Content-Type: text/xml; charset=utf-8' \
  -H 'SOAPAction: ""' \
  --data-binary @artifacts/greeting-request.xml \
  http://localhost:8080/ode/processes/GreetingOrchestrator
```

Expect `Hello, Ada!` again. The participant and process endpoints now have matching input/output contracts, and ODE forwards the message using Receive → Invoke → Reply.

For an executable assertion, save the response and parse the SOAP body:

```bash
curl --fail-with-body --silent --show-error \
  -H 'Content-Type: text/xml; charset=utf-8' -H 'SOAPAction: ""' \
  --data-binary @artifacts/greeting-request.xml \
  http://localhost:8080/ode/processes/GreetingOrchestrator \
  > artifacts/greeting-response.xml

python3 - <<'PY'
from xml.etree import ElementTree as E
root = E.parse('artifacts/greeting-response.xml').getroot()
ns = {'s': 'http://schemas.xmlsoap.org/soap/envelope/'}
body = root.find('s:Body', ns)
assert body is not None, 'Missing SOAP Body'
assert body.find('s:Fault', ns) is None, E.tostring(body)
values = [node.text for node in body.iter()
          if node.tag.split('}')[-1] == 'return']
assert values == ['Hello, Ada!'], values
print('PASS: client -> GreetingProcess -> GreetingService -> client')
PY

bash scripts/docker.sh test
```

The final command checks the original HelloProcess and editor as a regression check. It does not test GreetingProcess. Before submitting your work, also test your new endpoints with an empty name, Unicode text, and XML-escaped characters, and add your own assertions to a versioned test script. The existing `docker/integration.py` is a model for SOAP assertions and concurrent calls. To run new checks in CI, include them in the test image/workflow; a local request file alone does not add CI coverage.

### Invoke the orchestrator from a Java client in Eclipse

After deploying GreetingProcess, use the same `GreetingClients` project, but generate a **second set of client types from ODE's published WSDL**. Although the request/response XML matches the participant contract, ODE's published WSDL in this environment names the service `GreetingOrchestrator` and the port type `GreetingOrchestratorPortType`. These differ from the service and port-type names in the source `Greeting.wsdl`. Generate against the running endpoint rather than assuming the source names survive publication unchanged.

Run from your host terminal, in the repository root:

```bash
docker compose exec -T --user developer ide bash -c '
  cd /project/clients/greeting &&
  wsimport -keep -Xnocompile -s src \
    -p it.bpeldesigner.client.orchestrator.generated \
    http://ode:8080/ode/processes/GreetingOrchestrator?wsdl
'
```

The separate package keeps the orchestrator's generated types apart from the participant's. In Eclipse, select `GreetingClients` → **Refresh** and let it build. The new package contains the `GreetingOrchestrator` service class and `GreetingOrchestratorPortType` interface.

Create `OrchestratorClient.java` in the `it.bpeldesigner.client` package:

```java
package it.bpeldesigner.client;

import java.net.URL;
import javax.xml.ws.BindingProvider;
import it.bpeldesigner.client.orchestrator.generated.GreetingOrchestrator;
import it.bpeldesigner.client.orchestrator.generated.GreetingOrchestratorPortType;

public class OrchestratorClient {
    public static void main(String[] args) throws Exception {
        String endpoint = "http://ode:8080/ode/processes/GreetingOrchestrator";
        GreetingOrchestrator service = new GreetingOrchestrator(
            new URL(endpoint + "?wsdl"));
        GreetingOrchestratorPortType port = service.getGreetingOrchestratorPort();
        ((BindingProvider) port).getRequestContext().put(
            BindingProvider.ENDPOINT_ADDRESS_PROPERTY, endpoint);

        String response = port.greeting("Ada");
        System.out.println("Orchestrator response: " + response);
        if (!"Hello, Ada!".equals(response)) {
            throw new AssertionError("Unexpected orchestrator response: " + response);
        }
    }
}
```

Here, both the service class and port interface are generated from ODE's WSDL. Their contract namespace is `urn:greeting`, not the BPEL process namespace `urn:greeting-orchestrator`. The Java client downloads ODE's published WSDL and explicitly sets the SOAP destination to ODE; the override also avoids relying on the `localhost` address that ODE may advertise in its WSDL.

Right-click `OrchestratorClient.java` → **Run As → Java Application**. In that application's Eclipse Console, expect:

```text
Orchestrator response: Hello, Ada!
```

This is the final response from the synchronous orchestration: the Java client invokes ODE, ODE invokes GreetingService in the participant container, and the BPEL Reply sends the result back to Java. No extra polling is needed for this request/response process. Compare both Java clients to verify direct and orchestrated access independently.

The client runs inside the IDE container, so its endpoint uses `ode:8080`. To run it on your host, change the endpoint to `http://localhost:8080/ode/processes/GreetingOrchestrator`. If a call fails, inspect both the Eclipse Console exception and `docker compose logs --tail=200 ode participants`. Test the endpoint WSDL from the IDE container when diagnosing connectivity; a successful host-browser request checks a different network path.

## 5. Develop your own contracts

Once the exercise works, replace the greeting operation with your own domain service. Start by agreeing on request/response XML with your teammates.

- For Java-first services, implement and register the endpoint, rebuild, then inspect the generated WSDL and imported XSDs. Keep the BPEL partner contract compatible with those message definitions.
- For contract-first work, define the WSDL/XSD and generate or implement the corresponding Java endpoint with the appropriate JAX-WS tooling. This repository does not automate contract-first code generation.
- Add WSDL partner-link types for BPEL roles, then create BPEL imports, message variables, Receive, Invoke, Assign, and Reply activities as needed. If client and participant messages differ, use Assign to map data rather than forwarding incompatible messages unchanged.
- Update `deploy.xml` for each provided or invoked partner link. Include all imported WSDL/XSD files in the deployment directory and use resolvable relative paths.
- Use distinct process QNames, service QNames, and endpoint paths for independent processes. A different folder name alone does not prevent service collisions.

For a project created through **File → New → Other → BPEL → BPEL Project**, select a location below `/project/processes`. Save its deployable files there and use the same script deployment workflow. The Eclipse adapter is not needed.

### Everyday edit/build/deploy cycle

| Changed files | Action | Verification |
|---|---|---|
| Java or participant `WEB-INF` descriptors | `docker compose up -d --build --wait --wait-timeout 600 participants` | Fetch the new service WSDL and call it directly |
| BPEL, process WSDL/XSD, or `deploy.xml` | `bash scripts/docker.sh deploy` | Inspect ODE logs, fetch the new process WSDL, and call it |
| Participant contract and process contract | Rebuild participants first, then deploy ODE | Direct call, orchestrated call, regression tests |
| Docker images or Eclipse startup plugin | `bash scripts/docker.sh up` | Healthchecks, SOAP tests, and browser editor inspection |

Save files before deploying. Refresh Eclipse after terminal edits. Source files are on your computer; workspace metadata and ODE runtime state live in named volumes. Stopping the environment retains them ([persistence details](../README.md#persistence-and-shutdown)).

## 6. Troubleshooting

| Symptom | Check and action |
|---|---|
| New Java endpoint returns 404 | Verify the endpoint in `sun-jaxws.xml`, servlet mapping in `web.xml`, `/participants` context, and participant rebuild; inspect participant logs |
| Java client cannot connect from Eclipse | Use `participants:8081` for the service or `ode:8080` for the process; override the WSDL endpoint using `BindingProvider` |
| Generated client types are missing in Eclipse | Run `wsimport` after creating the client project, refresh it, and check the JavaSE-1.8 library and Problems view |
| Old Java response after saving | Java sources are baked into the WAR image; rebuild/recreate `participants` |
| Process WSDL returns 404 | Inspect ODE compilation errors; verify `deploy.xml`, process QName, service/port names, imports, and endpoint spelling; allow startup time |
| Invoke cannot connect | Use `participants:8081` inside Docker; check the deployed WSDL copy, not just host sources |
| SOAP fault or unexpected empty field | Check namespace URIs, wrapper names, unqualified `name`, operation, message parts, and schema compatibility |
| New process fails but Compose is healthy | Healthchecks cover the original example; call and test the new endpoint explicitly |
| Eclipse cannot see new files | Refresh or import the project; use `/project/processes/...`, without copying into the workspace |
| Eclipse edits are not on the host | Check that the project is under `/project`, rather than only under `/workspace` |
| Removing a source folder does not undeploy it | Snapshot deployment does not delete old units or stale files in the persistent ODE volume; renaming is not undeployment |

Useful diagnostics:

```bash
docker compose ps
docker compose logs --tail=200 participants ode
docker compose exec -T ode cat \
  /opt/tomcat/webapps/ode/WEB-INF/processes/GreetingProcess/Greeting.wsdl
bash scripts/collect-docker-evidence.sh
```

For a completely fresh disposable lab, `docker compose down -v` removes **all** named volumes, including Eclipse workspace metadata and ODE database/state. It does not delete bind-mounted source files. Use it only when you intend to reset the whole lab, then run `bash scripts/docker.sh up` again. It is not a selective undeploy command.

## 7. Submit an exercise

Keep your Java sources, descriptors, process files, and tests under version control. Exclude `artifacts/`, Maven output, the client project's compiled `clients/greeting/bin/` directory, and workspace/database files. Add `clients/greeting/bin/` to `.gitignore` when you create the client project. In your submission, state the new service and process URLs, provide a sample SOAP request and expected response, and record the tests you ran. See the [repository contribution workflow](../README.md#github-and-acceptance-criteria).

For background, use the [Metro 2.3.x documentation linked from the official Metro site](https://eclipse-ee4j.github.io/metro-jax-ws/) and [Apache ODE WAR deployment documentation](https://ode.apache.org/war-deployment.html), together with the pinned versions and working examples in this repository.

For Java client generation options and endpoint configuration, see the official JDK 8 [`wsimport` documentation](https://docs.oracle.com/javase/8/docs/technotes/tools/unix/wsimport.html) and [`BindingProvider` API](https://docs.oracle.com/javase/8/docs/api/javax/xml/ws/BindingProvider.html).
