# BPELDesigner

A Docker laboratory for developing **JAX-WS SOAP services** and **WS-BPEL 2.0 processes**, with **Eclipse Photon/BPEL Designer in your browser**, **Apache ODE on Tomcat**, and SOAP participants on a **separate Tomcat**. Java, Maven, Eclipse, and both servers run inside the images.

Designed for master's students: you can edit the mounted sources, build a service, deploy an orchestration, and test the complete SOAP call chain without installing the legacy Java toolchain on your computer.

## Tutorials

Start with [First launch](#first-launch), then follow the [student development tutorial](docs/TUTORIAL.md):

1. [Understand the example and container addresses](docs/TUTORIAL.md#1-understand-the-running-example).
2. [Create and deploy a new JAX-WS service](docs/TUTORIAL.md#2-create-a-new-jax-ws-service).
3. [Create and deploy a new BPEL process](docs/TUTORIAL.md#3-create-a-new-bpel-process).
4. [Test the complete orchestration](docs/TUTORIAL.md#4-test-the-complete-orchestration).
5. [Develop your own contracts and troubleshoot](docs/TUTORIAL.md#5-develop-your-own-contracts).

## Components and architecture

```text
Browser → Eclipse desktop (:6080) → mounted project sources
SOAP client → ODE / Tomcat (:8080) → JAX-WS / Tomcat (:8081)
```

| Component | Version | Role |
|---|---|---|
| Eclipse Temurin / Linux | JDK 8u472-b08 / Ubuntu Jammy | Docker base |
| Eclipse Java EE | Photon R / 4.8, Linux x86_64 | Browser IDE |
| BPEL Designer and ODE runtime | `1.1.2.Final-v20180514-2000` | Pinned p2 features |
| Apache ODE | 1.3.8 WAR | WS-BPEL 2.0 engine |
| Apache Tomcat | 8.5.100 | Two separate containers |
| Apache XML Serializer | 2.7.1, pinned SHA-256 | Xalan dependency missing from the ODE WAR |
| Metro JAX-WS | 2.3.7 | SOAP services using `javax.jws` |
| Maven | 3.9.9 | Java build |
| Xvfb/Fluxbox/x11vnc/noVNC | Ubuntu Jammy packages | Virtual desktop |

All containers use `linux/amd64` for Photon/SWT compatibility. Docker emulates this architecture on Apple Silicon; legacy macOS Eclipse is not used. Tomcat and Maven downloads are checked with SHA-512, ODE with its historical SHA-1 checksum, and Eclipse Linux with a pinned SHA-512. Application/BPEL versions and the base image's SHA-256 digest are pinned; distributor APT packages can change. Building requires Internet access.

## First launch

Install and start [Docker Desktop for Mac](https://docs.docker.com/desktop/setup/install/mac-install/), or Docker Engine with Compose on Linux. Use a recent Compose version supporting `up --wait`. Allocate approximately **4 CPUs and 6 GB RAM** to Docker. The first build downloads substantial data and can be slow under emulation.

From the project directory:

```bash
docker info
bash scripts/docker.sh up
bash scripts/docker.sh test
bash scripts/docker.sh restart-test
bash scripts/docker.sh recreate-test
```

`up` builds the images and waits for all healthchecks. The Eclipse check requires the actual BPEL editor to open; a working noVNC HTTP endpoint alone is insufficient. For diagnostics:

```bash
bash scripts/docker.sh logs
bash scripts/collect-docker-evidence.sh
```

Evidence is exported to the Git-ignored `artifacts/` directory, including a screenshot when the desktop is available.

## Access

| Component | URL on your computer | Container endpoint |
|---|---|---|
| Eclipse desktop | [Open Eclipse](http://localhost:6080/vnc.html?autoconnect=true&resize=scale) | `ide:6080` |
| BPEL process | [Orchestrator WSDL](http://localhost:8080/ode/processes/Orchestrator?wsdl) | `http://ode:8080/ode/processes/Orchestrator` |
| JAX-WS participant | [HelloService WSDL](http://localhost:8081/participants/hello?wsdl) | `http://participants:8081/participants/hello` |

Ports are bound to `127.0.0.1` only. The desktop has no password and can access local sources: do not expose these ports to the Internet. Eclipse Photon, ODE, and Tomcat 8.5 are legacy software intended here for local development and teaching.

The example receives a name, invokes the participant in the other container, and returns `Hello, <name>!`. The document/literal schema has a qualified wrapper element and an unqualified `name` parameter. Tests check both WSDLs, four direct calls, four orchestrated cases (including Unicode, XML characters, and an empty name), and twelve concurrent orchestrations. Earlier revisions returned `Ciao, <name>!`; rebuild the participant image after updating this checkout.

## Working in Eclipse

`HelloProcess` is imported as a BPEL 2.0 project and `bpelContent/HelloProcess.bpel` opens automatically. Its facet is visible under **Project → Properties → Project Facets**. The startup check verifies the installed BPEL facet and content-folder mapping, including in an existing workspace. The startup plugin in `docker/eclipse-startup/` writes `/workspace/.metadata/bpel-editor-check.ok` only after opening the BPEL editor, checking graphical activities, selecting them with the Properties view available, and opening the ODE deployment descriptor process form. An error records a stack trace and fails the healthcheck.

1. Open the browser desktop and check that a diagram appears, rather than just XML text.
2. Select Receive, CallParticipant, and Reply and inspect their properties.
3. Edit and save: `/project` maps to the local repository directory.
4. For Java, choose **File → Import → Maven → Existing Maven Projects**, with `/project/services` as the root.

For new processes, choose **File → New → Other → BPEL 2.0 → BPEL Project**, under `/project/processes`. Keep the default `bpelContent` folder for BPEL, WSDL, and any XSD files, and place `deploy.xml` in the project root for discovery by the Docker deployment script. The bundled HelloProcess is also a faceted BPEL 2.0 project: `.project` registers the WTP natures and BPEL validation builder, `.settings` declares the facet and content mapping, and `bpelContent` holds its BPEL/WSDL files. Scripts handle deployment rather than the Eclipse server adapter. See the [tutorial](docs/TUTORIAL.md) for a complete second process.

On Linux, the desktop uses UID/GID 1000: the mounted directory must be writable by that user. The container does not change ownership of host sources.

## Build and deploy

After changing BPEL, WSDL, XSD, or the deployment descriptor:

```bash
bash scripts/docker.sh deploy
bash scripts/docker.sh test
```

Deployment restarts ODE and copies a snapshot of each immediate subdirectory of `processes/` containing `deploy.xml`. It rewrites the exact `http://localhost:8081/` and `http://localhost:8080/` prefixes to Compose DNS names **in the deployed WSDL copies only**. Host sources are preserved. Included tests cover HelloProcess; add specific tests for additional processes. Deployment does not generally remove old deployment directories or stale files when you delete or rename sources. The HelloProcess layout upgrade has a targeted migration: it removes only the former root `HelloProcess.bpel`, `Hello.wsdl`, and `HelloProcess.cbp` before deploying the files under `bpelContent`; the relocated process is compiled before ODE restores its process registry, while other files and the ODE database are retained.

After changing Java or the participant's deployment descriptors:

```bash
docker compose up -d --build --wait --wait-timeout 600 participants
bash scripts/docker.sh test
```

Maven builds `participants.war` inside Docker and the image installs it on the participant Tomcat. A Java source save alone does not update the running WAR. Re-run `bash scripts/docker.sh up` after changing images or the startup plugin. Avoid redeploying while important instances are running: restarting is a laboratory procedure that interrupts execution.

## Updating an existing HelloProcess workspace

Save any open Eclipse files before updating. HelloProcess now uses the same BPEL 2.0 facet and `bpelContent` layout as projects created through the BPEL Project wizard. After pulling this change, run:

```bash
docker compose up -d --build --wait --wait-timeout 600 ide ode
bash scripts/docker.sh test
```

The updated startup plugin refreshes HelloProcess's versioned project description in the retained Eclipse workspace and opens the new BPEL path. ODE's startup deployment migrates the previous root files, including its compiled `.cbp`, without deleting named volumes. Reopen the process from `HelloProcess/bpelContent` if an old editor tab refers to the removed root path. Do not save an obsolete root editor tab back to its old location.

## Persistence and shutdown

| Data | Location | Persistence |
|---|---|---|
| BPEL/Java sources | Bind mounts `/project` and `/processes` | Local Git directory |
| Eclipse workspace | `eclipse-workspace` volume | Retained on stop/down |
| ODE database and state | `ode-state` at `WEB-INF/derby-jpadb` | Retained on stop/down |
| ODE working directory and deployments | `ode-work` and `ode-processes` volumes | Retained on stop/down |
| Logs | `docker compose logs` | Export before removing containers |

```bash
bash scripts/docker.sh stop
bash scripts/docker.sh up
bash scripts/docker.sh down
```

`down` retains volumes. `docker compose down -v` deletes the workspace and ODE state: use it only for an intentional reset. `restart-test` checks service recovery after restart; `recreate-test` recreates containers while retaining volumes. Neither verifies recovery of long-running processes or database crashes.

## Validation history

HelloProcess's BPEL 2.0 conversion was checked on November 15, 2026 using an existing plain-project Eclipse workspace and an existing ODE database/deployment in isolated volumes. The upgraded workbench verified the installed facet and `bpelContent` mapping, opened both BPEL and deployment editors, and passed the desktop healthcheck. ODE recompiled the relocated process before restoring its registry; the migrated process passed the SOAP integration suite with the database retained. Static checks also cover facet metadata and removal of obsolete root files while preserving unrelated files.

The follow-up tutorial/editor update was checked on November 15, 2026: an isolated Eclipse workbench opened the actual ODE deployment process form and BPEL diagram, then passed its desktop healthcheck. The new process was created from the tutorial's complete WSDL/BPEL/descriptor listings and deployed in separate containers. Both Java clients returned `Hello, Ada!`; original and new processes passed WSDL, direct/orchestrated SOAP, Unicode/XML/empty-input and concurrent-call checks. XML formatting was checked to preserve elements, attributes, namespaces, and values.

The English-language update and the tutorial were validated locally on November 15, 2026 in an isolated Docker Compose project. The tutorial snippets produced a second JAX-WS endpoint and BPEL deployment. Maven packaging and ODE deployment passed; both the original and tutorial examples passed two WSDL checks, four direct SOAP calls, four orchestrated cases, and twelve concurrent orchestrations each, using the English response. XML/shell syntax and the namespace-preserving deployment checks also passed. This update did not repeat the Eclipse browser, restart, or recreation checks.

The previous native pipeline passed its SOAP test on November 14, 2026: [run 43640763523](https://github.com/massimotivoli-oss/BPELDesigner/actions/runs/43640763523). That result applies to the earlier configuration and does not validate Docker or Eclipse.

Local Docker validation passed on an Apple Silicon Mac on November 14, 2026: build, three healthy services, and exit code 0 for `test`, `restart-test`, and `recreate-test`. Each test checks two WSDLs, four direct SOAP calls, four orchestrated cases, and twelve concurrent orchestrations. Eclipse opened the actual BPEL editor, checked graphical activities, and selected them with Properties available. Diagram and Reply-property screenshots were inspected; noVNC responded HTTP 200 from the Mac. Local evidence is in the untracked `artifacts/` directory.

The session's browser-control tool was unavailable: the noVNC browser workflow on the Mac, including editing and saving, was not manually tested. Graphical verification combined an SWT workbench check with screenshot inspection. The [Docker pipeline for commit `6b6233a`](https://github.com/massimotivoli-oss/BPELDesigner/actions/runs/43647197856) passed a clean Linux amd64 build, editor/property checks, SOAP, restart, and recreation with retained volumes. CI evidence is in that run's `docker-test-evidence` artifact. These historical results predate the English greeting introduced with this documentation update.

Compatibility fixes include an Eclipse process healthcheck compatible with Rosetta, the ODE descriptor editor's invalid project-root folder lookup, the missing Xalan serializer in the ODE WAR, BPEL bundles whose WSDL4J constraints rejected Photon's version qualifier, and an SWT stall during GTK printer discovery. `docker/patch-eclipse.py` aligns eight BPEL bundles with WSDL4J `[1.6.2,1.7.0)` and removes signatures only from modified JARs. The build also patches the ODE deployment editor to scan plain BPEL project roots or configured WTP web-content folders, using the ASM library already included in Photon. Startup checks open the actual deployment process form as well as the BPEL diagram. These are local derivatives of the original plugins, not unmodified Eclipse distributions. SWT printing is disabled in the virtual desktop to avoid printer-discovery stalls.

The workflow checks build, actual BPEL editor startup, SOAP, restart, and recreation, saving logs and screenshots even on failure. A passing run validates this configuration; it is not a general production-readiness certification. Mac visual and performance checks remain necessary, especially under emulation.

## GitHub and acceptance criteria

Repository: [massimotivoli-oss/BPELDesigner](https://github.com/massimotivoli-oss/BPELDesigner).

For a student contribution, review and commit only the files relevant to your exercise, then push your branch:

```bash
git switch -c exercise/my-service
# Edit, deploy, and test your changes first.
git status --short
git add services/src processes docs README.md
git commit -m "Add a SOAP service and BPEL orchestration"
git push -u origin HEAD
gh run list --limit 3
```

Use your own fork if you do not have write access to the course repository. The pipeline builds on Linux amd64, opens the editor with Xvfb, checks SOAP, restarts, and repeats the tests. It saves logs and screenshots on failure as well. CI does not replace visual and performance checks on Apple Silicon.

Acceptance requires a successful build, three healthy services, exit code 0 from all three test commands, a working diagram and Properties view in the Mac browser, and a green workflow for the container commit. Retain evidence for the verified commit. Do not commit credentials, binaries, databases, workspaces, or logs. No open-source license for this project is assumed; dependencies retain their own licenses.

## Earlier native scripts

`setup.sh`, `start.sh`, `deploy.sh`, `smoke.sh`, `stop.sh`, and `eclipse.sh` remain available for the non-Docker path with a local JDK 8. They are unnecessary for the Docker workflow and must not run alongside the containers because they use the same ports. In particular, native `scripts/deploy.sh` only copies HelloProcess; use `scripts/docker.sh deploy` for the multi-process Docker workflow.

## Official references

- [Eclipse BPEL Designer](https://projects.eclipse.org/projects/soa.bpel)
- [Pinned Photon repository](https://download.eclipse.org/releases/photon/201806271001/)
- [Eclipse Photon archive](https://archive.eclipse.org/technology/epp/downloads/release/photon/R/)
- [ODE WAR deployment](https://ode.apache.org/war-deployment.html)
- [ODE archive](https://archive.apache.org/dist/ode/)
- [Tomcat archive](https://archive.apache.org/dist/tomcat/tomcat-8/v8.5.100/)
- [Metro documentation, including the 2.3.x guides used by this project](https://eclipse-ee4j.github.io/metro-jax-ws/)
