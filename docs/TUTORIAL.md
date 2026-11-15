# Student tutorial: from Java service to BPEL orchestration

This exercise adds a `GreetingService` to the participant Tomcat and a `GreetingProcess` to Apache ODE. The existing HelloProcess stays available for the built-in healthchecks and regression tests.

You need a running Docker environment ([first launch](../README.md#first-launch)), a terminal in the repository root, and a text editor or the browser-based Eclipse desktop. Commands assume Bash on macOS or Linux. The optional Python response assertion requires host Python 3; no host Java or Maven installation is needed.

Allow time for the first Docker build. All paths below are relative to the repository root unless they start with `/project`, which is the same checkout inside Eclipse.

## 1. Understand the running example

The supplied HelloProcess is already a BPEL 2.0 project with the same `bpelContent` layout used later in this tutorial. Its facet and content mapping are versioned under `.settings`. Read these files before starting:

| File | Purpose |
|---|---|
| `services/src/main/java/it/bpeldesigner/HelloService.java` | Java endpoint implementation and JAX-WS annotations |
| `services/src/main/webapp/WEB-INF/sun-jaxws.xml` | Metro endpoint implementation and URL |
| `services/src/main/webapp/WEB-INF/web.xml` | Servlet registration and URL mapping |
| `services/pom.xml` | Java 8, Metro 2.3.7, and WAR build |
| `processes/HelloProcess/bpelContent/Hello.wsdl` | Messages, port type, SOAP binding, services, and partner-link type |
| `processes/HelloProcess/bpelContent/HelloProcessArtifacts.wsdl` | Wizard-style client partner-link type and role, importing Hello.wsdl |
| `processes/HelloProcess/bpelContent/HelloProcess.bpel` | Receive → Invoke → Reply |
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

Under `GreetingClients/src`, use the existing parent package `it.bpeldesigner.client`, introduced by the generated `it.bpeldesigner.client.generated` package; do not recreate it. Eclipse may show only the full generated package in its flat package presentation. Choose **New → Class** on `src` and set **Package** to `it.bpeldesigner.client` and **Name** to `GreetingServiceClient` (or select the parent package if it is visible). Select the `public static void main(String[] args)` option. Paste:

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

Create a process as an independent project, starting from its contracts. This workflow does not copy or rename HelloProcess. It also applies when the client and participant contracts differ: define both contracts, import their message types, and map data between them.

For this exercise, GreetingProcess accepts a greeting request and invokes the GreetingService developed in section 2. The public process and the participant have separate WSDL files, namespaces, messages, port types, and service definitions. Two Assign activities map their request/response data without coupling the public contract to the participant contract. The process wizard generates the client-facing partner-link type from the selected public port type. Receive, Invoke, and Reply handle the interaction; the assignments make the boundary between the contracts explicit.

### Create a BPEL project in Eclipse

1. Choose **File → New → Other → BPEL 2.0 → BPEL Project**. The same wizard is available from **File → New → Project → BPEL 2.0 → BPEL Project**.
2. Name the project `GreetingProcess`, clear **Use default location**, and enter `/project/processes/GreetingProcess` as its location. Keep the BPEL 2.0 project configuration. Leave the target runtime unset if no Eclipse server runtime is configured: the servers used here run in Docker.
3. Click **Next** to review the BPEL facet settings and keep **Content Folder** set to `bpelContent`. Finish the wizard and switch to the BPEL perspective if Eclipse offers it.
4. Select `bpelContent` and create the public process contract **`GreetingProcess.wsdl`**, either manually with **File → New → File** or with **File → New → Other → Web Services → WSDL File** and **Create WSDL Skeleton** enabled. The two options are detailed under [Define the WSDL contracts](#define-the-wsdl-contracts). Complete and save the process-only WSDL shown below. Create a second file, **`GreetingService.wsdl`**, by copying the XML published at [the participant WSDL](http://localhost:8081/participants/greeting?wsdl), and save its imported XSD locally as explained below. Then create `GreetingProcess.bpel` with **BPEL 2.0 → BPEL Process File**, choosing **Create a BPEL process from a service description**, as detailed under [Create the process with the BPEL Designer wizard](#create-the-process-with-the-bpel-designer-wizard).
5. Select the **project root** and use **File → New → File** to create `deploy.xml`, with the contents below. Keep this descriptor in the root because the Docker deployment script uses its presence there to recognize a deployment unit.

Use the BPEL Project wizard so Eclipse configures the BPEL 2.0 facet, content-folder mapping, and BPEL validation builder. You can inspect the facet under **Project → Properties → Project Facets**. Keep the generated `.project` and `.settings` metadata; do not replace them with the metadata from HelloProcess.

The exercise layout is:

```text
processes/GreetingProcess/
├── .project
├── .settings/
├── deploy.xml
└── bpelContent/
    ├── GreetingProcess.wsdl          # public process interface
    ├── GreetingService.wsdl          # copied from the participant endpoint
    ├── GreetingService.xsd           # schema imported by Metro
    ├── GreetingProcessArtifacts.wsdl  # generated by the process wizard
    └── GreetingProcess.bpel
```

The BPEL import `location="GreetingProcess.wsdl"` stays valid because BPEL and WSDL are in the same folder. The deployment script copies their nested paths along with the root descriptor; ODE resolves the descriptor's service and process QNames from the deployment unit's contracts. The descriptor editor uses the facet's `bpelContent` mapping to discover those contracts. Scripts still handle server deployment, so an Eclipse server adapter is unnecessary. Keep HelloProcess in place because the environment's startup checks and existing regression tests use it.

### Define the WSDL contracts

#### Create the public process WSDL

Create `bpelContent/GreetingProcess.wsdl` with the Eclipse WSDL wizard:

1. Select `bpelContent`, choose **File → New → Other → Web Services → WSDL File**, and enter `GreetingProcess.wsdl`.
2. Continue with **Next**, set **Target namespace** to `urn:greeting-orchestrator` and **Prefix** to `tns`, enable **Create WSDL Skeleton**, and select **SOAP** and **document literal**.
3. Finish, then use the WSDL editor's **Design** and **Source** views to complete the process contract below. Replace the generated example schema/messages and operation, and check its port type, binding, service, port, and address. Remove unused sample definitions.

Alternatively, use **File → New → File** to create `GreetingProcess.wsdl` manually and enter the same contract. Both routes produce a WSDL containing **only the process's public interface**. Do not add the participant's port type, binding, service, or schema to this file, and do not import its WSDL here.

The names are separated by contract:

| Item | Public process | Java participant |
|---|---|---|
| Contract file | `GreetingProcess.wsdl` | `GreetingService.wsdl`, copied from the published endpoint |
| Target namespace | `urn:greeting-orchestrator` | `urn:greeting` |
| Port type | `GreetingProcessPortType` | `GreetingPortType` |
| Source WSDL service / port | `GreetingProcessService` / `GreetingProcessPort` | `GreetingService` / `GreetingPort` |
| SOAP endpoint path | `/ode/processes/GreetingProcess` | `/participants/greeting` |
| Request / response message QNames | `{urn:greeting-orchestrator}greeting` / `greetingResponse` | `{urn:greeting}greeting` / `greetingResponse` |

Both operations are named `greeting` and both exchange a name and greeting text, but their XML wrappers belong to different namespaces. The BPEL process itself also uses `urn:greeting-orchestrator`. The wizard therefore generates its artifacts WSDL in namespace `urn:greeting-orchestratorArtifacts`, derived from the public WSDL's target namespace plus `Artifacts`.

Complete `GreetingProcess.wsdl` as follows:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<definitions
    xmlns="http://schemas.xmlsoap.org/wsdl/"
    xmlns:tns="urn:greeting-orchestrator"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:soap="http://schemas.xmlsoap.org/wsdl/soap/"
    targetNamespace="urn:greeting-orchestrator">
    <types>
        <xs:schema targetNamespace="urn:greeting-orchestrator" elementFormDefault="unqualified">
            <xs:element name="greeting">
                <xs:complexType>
                    <xs:sequence>
                        <xs:element name="name" type="xs:string"/>
                    </xs:sequence>
                </xs:complexType>
            </xs:element>
            <xs:element name="greetingResponse">
                <xs:complexType>
                    <xs:sequence>
                        <xs:element name="return" type="xs:string"/>
                    </xs:sequence>
                </xs:complexType>
            </xs:element>
        </xs:schema>
    </types>

    <message name="greeting">
        <part name="parameters" element="tns:greeting"/>
    </message>
    <message name="greetingResponse">
        <part name="parameters" element="tns:greetingResponse"/>
    </message>

    <!-- The process's public contract, defined independently. -->
    <portType name="GreetingProcessPortType">
        <operation name="greeting">
            <input message="tns:greeting"/>
            <output message="tns:greetingResponse"/>
        </operation>
    </portType>

    <binding name="GreetingProcessBinding" type="tns:GreetingProcessPortType">
        <soap:binding style="document" transport="http://schemas.xmlsoap.org/soap/http"/>
        <operation name="greeting">
            <soap:operation soapAction=""/>
            <input>
                <soap:body use="literal"/>
            </input>
            <output>
                <soap:body use="literal"/>
            </output>
        </operation>
    </binding>

    <service name="GreetingProcessService">
        <port name="GreetingProcessPort" binding="tns:GreetingProcessBinding">
            <soap:address location="http://localhost:8080/ode/processes/GreetingProcess"/>
        </port>
    </service>

</definitions>
```

#### Obtain the participant WSDL from the running service

1. Open [http://localhost:8081/participants/greeting?wsdl](http://localhost:8081/participants/greeting?wsdl) in your host browser. Use **View Page Source** if needed and copy the complete XML, including the `definitions` root and namespace declarations, rather than the browser's rendered tree or HTML.
2. In Eclipse, select `bpelContent`, choose **File → New → File**, and name it `GreetingService.wsdl`. Paste the copied XML into its Source view, use **Source → Format** if desired, and save. This is the actual Java service contract: preserve its messages, `GreetingPortType`, `GreetingPortBinding`, `GreetingService`, and `GreetingPort`.
3. Inspect the imports. In this environment, Metro's WSDL contains `<xsd:import namespace="urn:greeting" schemaLocation="http://localhost:8081/participants/greeting?xsd=1"/>`. Open [the imported schema](http://localhost:8081/participants/greeting?xsd=1), copy its complete XML into a new `bpelContent/GreetingService.xsd`, and change **only that `schemaLocation`** in the saved WSDL to `GreetingService.xsd`. If your service publishes additional WSDL/XSD imports, save them too and make their import locations relative.
4. Keep the SOAP service address `http://localhost:8081/participants/greeting` in the source WSDL. The deployment script rewrites that address to Compose DNS in ODE's copy. The relative schema path lets Eclipse and ODE load the same contract without trying to download an XSD from their own `localhost`.

There is no need to recreate the participant's interface with a WSDL skeleton: copying its published contract avoids inventing a description that differs from the running implementation. Metro does not include BPEL partner-link types in that WSDL; add the BPEL role declaration to the separate artifacts WSDL below, leaving the downloaded service interface intact.

The published schema has qualified `greeting` / `greetingResponse` wrapper elements in `urn:greeting` and unqualified `name` / `return` children. The public process schema uses analogous wrappers in `urn:greeting-orchestrator`. The assignments below initialize each destination wrapper and copy the data fields across that namespace boundary. In BPEL literals, `xmlns=""` keeps `name` and `return` unqualified instead of inheriting the BPEL namespace.

### Create the process with the BPEL Designer wizard

Save `GreetingProcess.wsdl` before opening the wizard. The service description selected here is the **public contract implemented by the process**, not the Java participant's endpoint WSDL.

1. Select `GreetingProcess/bpelContent` in Project Explorer and choose **File → New → Other → BPEL 2.0 → BPEL Process File**. The bundled help also calls this wizard **New BPEL Process File**.
2. Select **Create a BPEL process from a service description**, enter **Process Name** `GreetingProcess` and **Namespace** `urn:greeting-orchestrator`. Keep **Abstract Process** unchecked: this exercise needs an executable process. Continue with **Next**.
3. On **Service Contract**, choose **Browse the workspace...** and select `/GreetingProcess/bpelContent/GreetingProcess.wsdl`. Alternatively, enter `file:/project/processes/GreetingProcess/bpelContent/GreetingProcess.wsdl` in **WSDL URL**. Click **Parse the given WSDL** (or leave the URL field with Tab) if needed to populate the contracts.
4. In **Service Contract**, select `{urn:greeting-orchestrator}GreetingProcessPortType`, and check that its `greeting` operation appears. This WSDL contains only the process port type; the participant's `GreetingPortType` is in `GreetingService.wsdl`.
5. Clear **Import the WSDL file with its dependencies** because the WSDL is already saved in this project's content folder. This avoids importing a second copy of the same contract. Continue with **Next**.
6. On **Select Files Location**, select `/GreetingProcess/bpelContent` and set the file name to `GreetingProcess.bpel`. Finish the wizard. If Eclipse offers to open the BPEL perspective, accept.

The wizard creates `GreetingProcess.bpel` and `GreetingProcessArtifacts.wsdl`. Keep both files. The artifacts WSDL imports `GreetingProcess.wsdl` and defines the generated client partner-link type `GreetingProcessPortTypePLT`, with role `GreetingProcessPortTypeRole`, in namespace `urn:greeting-orchestratorArtifacts`. Check that the generated imports use paths relative to the content folder, such as `GreetingProcess.wsdl`, rather than workspace-only `platform:/resource/...` URLs. ODE deploys filesystem files outside the Eclipse workspace.

The wizard initially creates the client partner-link declaration. Extend **`GreetingProcessArtifacts.wsdl`**, rather than either interface WSDL, with an import of `GreetingService.wsdl` and a participant partner-link type. In the WSDL editor add the import and the following role definition, or use BPEL Designer's partner-link type creation dialog and select `GreetingPortType` from the saved participant WSDL. The completed artifacts file is:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<definitions
    xmlns="http://schemas.xmlsoap.org/wsdl/"
    xmlns:p="urn:greeting-orchestrator"
    xmlns:g="urn:greeting"
    xmlns:plnk="http://docs.oasis-open.org/wsbpel/2.0/plnktype"
    targetNamespace="urn:greeting-orchestratorArtifacts">
    <import namespace="urn:greeting-orchestrator" location="GreetingProcess.wsdl"/>
    <import namespace="urn:greeting" location="GreetingService.wsdl"/>
    <plnk:partnerLinkType name="GreetingProcessPortTypePLT">
        <plnk:role name="GreetingProcessPortTypeRole" portType="p:GreetingProcessPortType"/>
    </plnk:partnerLinkType>
    <plnk:partnerLinkType name="GreetingProcessParticipantLink">
        <plnk:role name="provider" portType="g:GreetingPortType"/>
    </plnk:partnerLinkType>
</definitions>
```

This file contains only BPEL integration metadata and imports: it does not redefine either interface. The public process WSDL stays process-only, and the participant WSDL stays the copied service contract, with its schema import localized for deployment.

The generated process contains a main Sequence, a **Pick** named `SwitchInvokedOperation` with `createInstance="yes"`, and an **OnMessage** branch for each operation of the selected port type. For this request/response operation, the branch initially contains a Reply. It also creates a client partner link and request/response variables. It does **not** generate the invocation of GreetingService or your ODE deployment descriptor.

This tutorial uses only the **service description** option. For **Create a BPEL process from a template**, consult the plugin documentation inside Eclipse: **Help → Help Contents → BPEL User Guide → Getting Started → Creating and editing a BPEL project → Creating a BPEL process**. That topic explains the template-based workflow and its synchronous/asynchronous/empty process choices. Those template-specific service-creation pages are not the workflow followed here.

### Complete the generated process in the Designer

Open the generated process in the BPEL graphical editor and use the diagram/dashboard, Outline, and Properties view to complete it:

1. Select the process and set its **Name** to `GreetingProcess` and **Target Namespace** to `urn:greeting-orchestrator`. Check these explicitly: the wizard derives initial values from the file and service description, which need not match the process QName used by our ODE descriptor. Keep imports for `GreetingProcess.wsdl` (`urn:greeting-orchestrator`), `GreetingService.wsdl` (`urn:greeting`), and `GreetingProcessArtifacts.wsdl` (`urn:greeting-orchestratorArtifacts`).
2. Rename the generated client partner link, initially `bpelProcessPartner`, to `client`. Keep its generated partner-link type `GreetingProcessPortTypePLT` and **My Role** `GreetingProcessPortTypeRole`; leave its partner role unset. Keep the generated partner-link type and role resolved when renaming the link; the activities will be rewired below.
3. Add a second partner link named `participant`. Select `GreetingProcessParticipantLink` from `GreetingProcessArtifacts.wsdl` and set **Partner Role** to `provider`, leaving its my role unset.
4. Use process-scope variables `request` and `response` with **message types** `{urn:greeting-orchestrator}greeting` and `{urn:greeting-orchestrator}greetingResponse`. Rename/retype the wizard's initial variables as needed, clearing any element/type selection. Add two more message variables, `participantRequest` and `participantResponse`, with types `{urn:greeting}greeting` and `{urn:greeting}greetingResponse` selected from `GreetingService.wsdl`. These separate variables represent the two independent contracts.
5. Replace the generated **Pick/OnMessage** structure with **Receive**. Delete the Pick `SwitchInvokedOperation`, including its OnMessage branch and contained Reply, while keeping the outer Sequence, imports, partner links, and variables. Add Receive first in the outer Sequence; set name `Receive`, partner link `client`, port type `GreetingProcessPortType`, operation `greeting`, variable `request`, and **Create Instance** **yes**.
6. Add an **Assign** named `PrepareParticipantRequest` after Receive. In Properties, add two Copy rules in order: initialize `participantRequest`'s `parameters` part with the literal `<g:greeting xmlns:g="urn:greeting" xmlns=""><name/></g:greeting>`, then copy the `name` child from `request`'s `parameters` part to the `name` child of `participantRequest`'s `parameters` part. Use the XPath query `name` for both field selections. This initializes the participant's wrapper before copying the field.
7. Add **Invoke**, named `CallParticipant`, immediately after that Assign. Select partner link `participant`, port type `GreetingPortType`, operation `greeting`, input variable `participantRequest`, and output variable `participantResponse`.
8. Add another **Assign**, named `PrepareClientResponse`, after Invoke. First initialize `response`'s `parameters` part with `<p:greetingResponse xmlns:p="urn:greeting-orchestrator" xmlns=""><return/></p:greetingResponse>`. Then copy `participantResponse`'s `return` child to `response`'s `return` child, using the `parameters` parts and XPath query `return` on both sides.
9. Add **Reply**, named `Reply`, last in the same Sequence. Set partner link `client`, port type `GreetingProcessPortType`, operation `greeting`, and variable `response`. Save and inspect the Problems view. The Source tab should show the sequence below, with no Pick/OnMessage left.

The final diagram is **Receive → Assign → Invoke → Assign → Reply**. Receive, Invoke, and Reply are the basic communication activities; the assignments translate data between independent contracts. The public schema requires a `name` element (which may be empty), and GreetingService returns a `return` element. For a different service, handle optional/missing fields and faults according to its schema rather than assuming those XPath selections always exist.

Use the **Source** tab to compare names, imports, and variable types with the following completed reference. Namespace prefixes and diagram activity names may differ without changing the contract. This listing shows the result after completing the wizard-generated process; it is not an instruction to create the BPEL file through **New → File** or replace the generated process wholesale.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<process
    xmlns="http://docs.oasis-open.org/wsbpel/2.0/process/executable"
    xmlns:p="urn:greeting-orchestrator"
    xmlns:g="urn:greeting"
    xmlns:a="urn:greeting-orchestratorArtifacts"
    name="GreetingProcess"
    targetNamespace="urn:greeting-orchestrator"
    suppressJoinFailure="yes">
    <import
        namespace="urn:greeting-orchestrator"
        location="GreetingProcess.wsdl"
        importType="http://schemas.xmlsoap.org/wsdl/"/>

    <import
        namespace="urn:greeting-orchestratorArtifacts"
        location="GreetingProcessArtifacts.wsdl"
        importType="http://schemas.xmlsoap.org/wsdl/"/>

    <import
        namespace="urn:greeting"
        location="GreetingService.wsdl"
        importType="http://schemas.xmlsoap.org/wsdl/"/>

    <partnerLinks>
        <partnerLink
            name="client"
            partnerLinkType="a:GreetingProcessPortTypePLT"
            myRole="GreetingProcessPortTypeRole"/>
        <partnerLink
            name="participant"
            partnerLinkType="a:GreetingProcessParticipantLink"
            partnerRole="provider"/>
    </partnerLinks>

    <variables>
        <variable name="request" messageType="p:greeting"/>
        <variable name="response" messageType="p:greetingResponse"/>
        <variable name="participantRequest" messageType="g:greeting"/>
        <variable name="participantResponse" messageType="g:greetingResponse"/>
    </variables>

    <sequence name="MainSequence">
        <receive
            name="Receive"
            partnerLink="client"
            portType="p:GreetingProcessPortType"
            operation="greeting"
            variable="request"
            createInstance="yes"/>
        <assign name="PrepareParticipantRequest">
            <copy>
                <from>
                    <literal>
                        <g:greeting xmlns="">
                            <name/>
                        </g:greeting>
                    </literal>
                </from>
                <to variable="participantRequest" part="parameters"/>
            </copy>
            <copy>
                <from variable="request" part="parameters">
                    <query>name</query>
                </from>
                <to variable="participantRequest" part="parameters">
                    <query>name</query>
                </to>
            </copy>
        </assign>
        <invoke
            name="CallParticipant"
            partnerLink="participant"
            portType="g:GreetingPortType"
            operation="greeting"
            inputVariable="participantRequest"
            outputVariable="participantResponse"/>
        <assign name="PrepareClientResponse">
            <copy>
                <from>
                    <literal>
                        <p:greetingResponse xmlns="">
                            <return/>
                        </p:greetingResponse>
                    </literal>
                </from>
                <to variable="response" part="parameters"/>
            </copy>
            <copy>
                <from variable="participantResponse" part="parameters">
                    <query>return</query>
                </from>
                <to variable="response" part="parameters">
                    <query>return</query>
                </to>
            </copy>
        </assign>
        <reply
            name="Reply"
            partnerLink="client"
            portType="p:GreetingProcessPortType"
            operation="greeting"
            variable="response"/>
    </sequence>
</process>
```

Receive starts an instance and stores the request. Invoke calls the participant, and Reply returns its response to the original caller. The client partner link's **My Role** is the generated `GreetingProcessPortTypeRole`; the participant's **Partner Role** is `provider`. Variable `messageType` values refer to WSDL message QNames, not XML element names or Java class names.

To build a different process, first define its public and participant contracts. Declare separate input/output variables for incompatible message types, then insert **Assign** activities before and after Invoke to map the XML data. Initialize target message elements before assigning individual fields. The two Assign activities above demonstrate this boundary: the client variables use the process contract, and the participant variables use the downloaded service contract. Their XML wrappers are kept distinct even though both carry the same simple fields.

### Define the ODE deployment descriptor

Create `deploy.xml` in the project root with these contents:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<deploy
    xmlns="http://www.apache.org/ode/schemas/dd/2007/03"
    xmlns:p="urn:greeting-orchestrator"
    xmlns:g="urn:greeting">
    <process name="p:GreetingProcess">
        <active>true</active>
        <retired>false</retired>
        <provide partnerLink="client">
            <service name="p:GreetingProcessService" port="GreetingProcessPort"/>
        </provide>
        <invoke partnerLink="participant">
            <service name="g:GreetingService" port="GreetingPort"/>
        </invoke>
    </process>
</deploy>
```

Open it with **Open With → ODE Deployment Descriptor Editor** to inspect the process form. The editor is an authoring tool; deployment still uses the Docker scripts. After updating from an older environment, rebuild the IDE image to install the descriptor-editor fix (see troubleshooting).

The process QName must match the BPEL process's namespace and name. The `provide` entry binds the client partner link to the public WSDL service/port; `invoke` binds the participant partner link to its service/port. All referenced names must match their declarations exactly. XML prefix spelling is arbitrary, while the namespace URI is significant.

### Deploy on Apache ODE

Save both interface WSDLs, the local participant XSD, artifacts WSDL, completed BPEL, and deployment descriptor, then run from the repository root on your computer:

```bash
bash scripts/docker.sh deploy
docker compose logs --tail=200 ode
curl --fail --silent --show-error \
  'http://localhost:8080/ode/processes/GreetingProcess?wsdl'
```

On ODE startup, `docker/deploy.py` scans immediate subdirectories of `/processes` with a `deploy.xml`. It copies `.bpel`, `.wsdl`, `.xsd`, and `.xml` files, including nested files, into `/opt/tomcat/webapps/ode/WEB-INF/processes/<folder>`, copying the descriptor last. ODE compiles each deployment unit. This restarts ODE and interrupts in-flight requests; use it between laboratory test runs.

The Compose ODE healthcheck still checks the original Orchestrator. A successful deploy command therefore does not prove that your new process compiled: inspect ODE logs and fetch the new WSDL explicitly. A new endpoint may take a short time to appear. ODE can publish different service and port-type names from those in the source WSDL; section 4 generates Java client types from the published contract.

## 4. Test the complete orchestration

Create a **process-client** SOAP request using the public process namespace. Keep the direct-service request from section 2 unchanged; it uses the participant namespace.

```bash
cat > artifacts/greeting-process-request.xml <<'XML'
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"
            xmlns:p="urn:greeting-orchestrator">
  <s:Body>
    <p:greeting><name>Ada</name></p:greeting>
  </s:Body>
</s:Envelope>
XML
```

Send it to ODE:

```bash
curl --fail-with-body --silent --show-error \
  -H 'Content-Type: text/xml; charset=utf-8' \
  -H 'SOAPAction: ""' \
  --data-binary @artifacts/greeting-process-request.xml \
  http://localhost:8080/ode/processes/GreetingProcess
```

Expect `Hello, Ada!` again. The process keeps its own public contract and maps data to and from the participant contract using Receive, the request mapping, Invoke, the response mapping, and Reply.

For an executable assertion, save the response and parse the SOAP body:

```bash
curl --fail-with-body --silent --show-error \
  -H 'Content-Type: text/xml; charset=utf-8' -H 'SOAPAction: ""' \
  --data-binary @artifacts/greeting-process-request.xml \
  http://localhost:8080/ode/processes/GreetingProcess \
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

After deploying GreetingProcess, use the same `GreetingClients` project, but generate a **second set of client types from ODE's published WSDL**. The process has its own public request/response XML namespace. ODE publishes this endpoint as service `GreetingProcess`, with port `GreetingProcessPort` and port type `GreetingProcessPortType`. Its service name differs from the source WSDL's `GreetingProcessService`. Generate against the running endpoint rather than assuming the source names survive publication unchanged.

Run from your host terminal, in the repository root:

```bash
docker compose exec -T --user developer ide bash -c '
  cd /project/clients/greeting &&
  wsimport -keep -Xnocompile -s src \
    -p it.bpeldesigner.client.orchestrator.generated \
    http://ode:8080/ode/processes/GreetingProcess?wsdl
'
```

The separate package keeps the orchestrator's generated types apart from the participant's. In Eclipse, select `GreetingClients` → **Refresh** and let it build. The new package contains the `GreetingProcess` service class and `GreetingProcessPortType` interface.

Create `OrchestratorClient.java` in the `it.bpeldesigner.client` package:

```java
package it.bpeldesigner.client;

import java.net.URL;
import javax.xml.ws.BindingProvider;
import it.bpeldesigner.client.orchestrator.generated.GreetingProcess;
import it.bpeldesigner.client.orchestrator.generated.GreetingProcessPortType;

public class OrchestratorClient {
    public static void main(String[] args) throws Exception {
        String endpoint = "http://ode:8080/ode/processes/GreetingProcess";
        GreetingProcess service = new GreetingProcess(
            new URL(endpoint + "?wsdl"));
        GreetingProcessPortType port = service.getGreetingProcessPort();
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

Here, both the service class and port interface are generated from ODE's WSDL. Their public contract namespace is `urn:greeting-orchestrator`, which is also the namespace of this BPEL process; the participant's separate contract uses `urn:greeting`. The Java client downloads ODE's published WSDL and explicitly sets the SOAP destination to ODE; the override also avoids relying on the `localhost` address that ODE may advertise in its WSDL.

Right-click `OrchestratorClient.java` → **Run As → Java Application**. In that application's Eclipse Console, expect:

```text
Orchestrator response: Hello, Ada!
```

This is the final response from the synchronous orchestration: the Java client invokes ODE, ODE invokes GreetingService in the participant container, and the BPEL Reply sends the result back to Java. No extra polling is needed for this request/response process. Compare both Java clients to verify direct and orchestrated access independently.

The client runs inside the IDE container, so its endpoint uses `ode:8080`. To run it on your host, change the endpoint to `http://localhost:8080/ode/processes/GreetingProcess`. If a call fails, inspect both the Eclipse Console exception and `docker compose logs --tail=200 ode participants`. Test the endpoint WSDL from the IDE container when diagnosing connectivity; a successful host-browser request checks a different network path.

## 5. Develop your own contracts

Once the exercise works, replace the greeting operation with your own domain service. Start by agreeing on request/response XML with your teammates.

- For Java-first services, implement and register the endpoint, rebuild, then inspect the generated WSDL and imported XSDs. Keep the BPEL partner contract compatible with those message definitions.
- For contract-first work, define the WSDL/XSD and generate or implement the corresponding Java endpoint with the appropriate JAX-WS tooling. This repository does not automate contract-first code generation.
- Add WSDL partner-link types for BPEL roles, then create BPEL imports, message variables, Receive, Invoke, Assign, and Reply activities as needed. If client and participant messages differ, use Assign to map data rather than forwarding incompatible messages unchanged.
- Update `deploy.xml` for each provided or invoked partner link. Include all imported WSDL/XSD files in the deployment directory and use resolvable relative paths.
- Use distinct process QNames, service QNames, and endpoint paths for independent processes. A different folder name alone does not prevent service collisions.

For each new process, use **File → New → Other → BPEL 2.0 → BPEL Project**, select a location below `/project/processes`, and keep the facet's content folder for BPEL/WSDL/XSD files. Keep `deploy.xml` in the project root so the Docker script discovers the deployment unit, as shown in section 3. The Eclipse server adapter is not needed.

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
| Opening `deploy.xml` reports “Path must include project and resource name” | Rebuild/recreate the IDE using the command below; the image patches the legacy editor's project-root lookup. Then reopen the descriptor |
| Eclipse cannot see new files | Refresh or import the project; use `/project/processes/...`, without copying into the workspace |
| Eclipse edits are not on the host | Check that the project is under `/project`, rather than only under `/workspace` |
| Removing a source folder does not undeploy it | Snapshot deployment generally does not delete old units or stale files in the persistent ODE volume; the bundled HelloProcess layout migration is a targeted exception. Renaming is not undeployment |

To install the descriptor-editor fix in an existing environment, save your Eclipse files first, then run:

```bash
docker compose up -d --build --wait --wait-timeout 600 ide
```

This recreates the IDE container while keeping its named workspace volume and your mounted sources. Reopen `deploy.xml` with **Open With → ODE Deployment Descriptor Editor**. The startup check now opens the deployment descriptor's process form as well as checking the BPEL diagram. No project relocation or source renaming is required.

Useful diagnostics:

```bash
docker compose ps
docker compose logs --tail=200 participants ode
docker compose exec -T ode cat \
  /opt/tomcat/webapps/ode/WEB-INF/processes/GreetingProcess/bpelContent/GreetingProcess.wsdl
bash scripts/collect-docker-evidence.sh
```

For a completely fresh disposable lab, `docker compose down -v` removes **all** named volumes, including Eclipse workspace metadata and ODE database/state. It does not delete bind-mounted source files. Use it only when you intend to reset the whole lab, then run `bash scripts/docker.sh up` again. It is not a selective undeploy command.

## 7. Submit an exercise

Keep your Java sources, descriptors, process files, and tests under version control. Exclude `artifacts/`, Maven output, the client project's compiled `clients/greeting/bin/` directory, and workspace/database files. Add `clients/greeting/bin/` to `.gitignore` when you create the client project. In your submission, state the new service and process URLs, provide a sample SOAP request and expected response, and record the tests you ran. See the [repository contribution workflow](../README.md#github-and-acceptance-criteria).

For background, use the [Metro 2.3.x documentation linked from the official Metro site](https://eclipse-ee4j.github.io/metro-jax-ws/) and [Apache ODE WAR deployment documentation](https://ode.apache.org/war-deployment.html), together with the pinned versions and working examples in this repository.

For Java client generation options and endpoint configuration, see the official JDK 8 [`wsimport` documentation](https://docs.oracle.com/javase/8/docs/technotes/tools/unix/wsimport.html) and [`BindingProvider` API](https://docs.oracle.com/javase/8/docs/api/javax/xml/ws/BindingProvider.html).
