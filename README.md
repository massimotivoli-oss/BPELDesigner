# BPELDesigner

Ambiente Docker con **Eclipse Photon/BPEL Designer nel browser**, **Apache ODE su Tomcat** e servizi SOAP **JAX-WS su un secondo Tomcat**. Java, Maven, Eclipse e server vengono installati dentro le immagini.

## Stato del collaudo

La precedente pipeline nativa ha superato il test SOAP il 14 novembre 2026: [run 43640763523](https://github.com/massimotivoli-oss/BPELDesigner/actions/runs/43640763523). Quel risultato riguarda la configurazione precedente: **non certifica Docker né Eclipse**.

**Collaudo locale superato sul Mac Apple Silicon il 14 novembre 2026**: build; tre servizi healthy; `test`, `restart-test` e `recreate-test` con exit code 0. Ogni test verifica due WSDL, quattro chiamate SOAP dirette, quattro casi orchestrati e dodici orchestrazioni concorrenti. Eclipse apre il vero editor BPEL, verifica le attività grafiche e le seleziona con Properties disponibile. Screenshot del diagramma e del pannello Reply verificato; noVNC dal Mac risponde HTTP 200. Log e screenshot sono in `artifacts/` (non versionati).

Il browser di controllo della sessione non è disponibile: non è stata eseguita una prova manuale del flusso noVNC nel browser del Mac, né di modifica/salvataggio. La verifica grafica combina il test nel workbench SWT con l'ispezione dello screenshot. La pipeline Docker sul commit pubblicato resta da verificare.

Correzioni incluse: healthcheck del processo Eclipse compatibile con Rosetta; Serializer Xalan mancante nel WAR ODE; vincoli WSDL4J dei bundle BPEL incompatibili con il qualificatore della versione Photon; blocco SWT nella ricerca stampanti GTK del desktop virtuale. `docker/patch-eclipse.py` allinea otto bundle BPEL a WSDL4J `[1.6.2,1.7.0)`, rimuovendo le firme dei soli JAR modificati. Sono derivati locali dei plugin originali, non distribuzioni Eclipse inalterate. La stampa SWT è disabilitata nel desktop virtuale per evitare il blocco della ricerca stampanti.

La pipeline aggiornata verifica build, apertura reale dell'editor BPEL, chiamate SOAP e riavvio. Salva log e screenshot nell'artifact `docker-test-evidence`. Un esito positivo documenta questa configurazione; non costituisce una certificazione generale o di idoneità alla produzione. Restano necessari il controllo visivo e delle prestazioni sul Mac, soprattutto in emulazione.

## Componenti e architettura

| Componente | Versione | Ruolo |
|---|---|---|
| Eclipse Temurin / Linux | JDK 8u472-b08 / Ubuntu Jammy | Base Docker |
| Eclipse Java EE | Photon R / 4.8, Linux x86_64 | IDE nel browser |
| BPEL Designer e runtime ODE | `1.1.2.Final-v20180514-2000` | Feature p2 fissate |
| Apache ODE | 1.3.8 WAR | Motore WS-BPEL 2.0 |
| Apache Tomcat | 8.5.100 | Due container distinti |
| Apache XML Serializer | 2.7.1, SHA-256 fissato | Dipendenza Xalan mancante nel WAR ODE |
| Metro JAX-WS | 2.3.7 | Partecipante SOAP `javax.jws` |
| Maven | 3.9.9 | Build Java |
| Xvfb/Fluxbox/x11vnc/noVNC | Pacchetti Ubuntu Jammy | Desktop virtuale |

Tutti i container usano `linux/amd64` per compatibilità con Photon/SWT. Su Apple Silicon Docker esegue l'emulazione; non viene usato Eclipse macOS legacy. Tomcat/Maven sono verificati con SHA-512, ODE con il checksum storico SHA-1, Eclipse Linux con SHA-512 fissato. Le versioni applicative e BPEL sono fissate; la base amd64 è fissata anche per digest SHA-256, mentre i pacchetti APT possono cambiare presso i distributori. Internet serve durante la build.

## Primo avvio

Installare e avviare [Docker Desktop per Mac](https://docs.docker.com/desktop/setup/install/mac-install/), oppure Docker Engine con Compose su Linux. Serve Compose recente con `up --wait`. Assegnare indicativamente almeno **4 CPU e 6 GB RAM** a Docker. La prima build scarica parecchi dati e può essere lenta in emulazione.

Dalla directory del progetto:

```bash
docker info
bash scripts/docker.sh up
bash scripts/docker.sh test
bash scripts/docker.sh restart-test
bash scripts/docker.sh recreate-test
```

`up` attende tutte le healthcheck: per Eclipse deve aprirsi il vero editor BPEL, non basta che noVNC risponda. Per la diagnosi:

```bash
bash scripts/docker.sh logs
bash scripts/collect-docker-evidence.sh
```

I file vengono esportati in `artifacts/`, esclusa da Git, incluso lo screenshot quando il desktop è disponibile.

## Accesso

| Componente | URL dal Mac | Endpoint tra container |
|---|---|---|
| Desktop Eclipse | [Apri Eclipse](http://localhost:6080/vnc.html?autoconnect=true&resize=scale) | `ide:6080` |
| Processo BPEL | [WSDL Orchestrator](http://localhost:8080/ode/processes/Orchestrator?wsdl) | `http://ode:8080/ode/processes/Orchestrator` |
| Partecipante JAX-WS | [WSDL HelloService](http://localhost:8081/participants/hello?wsdl) | `http://participants:8081/participants/hello` |

Le porte sono pubblicate solo su `127.0.0.1`. Il desktop non richiede password e accede ai sorgenti locali: non esporre queste porte su Internet. Eclipse Photon, ODE e Tomcat 8.5 sono software legacy: ambiente destinato a sviluppo e didattica locale.

Il processo riceve un nome, invoca il partecipante nell'altro container e restituisce `Ciao, <nome>!`. Lo schema document/literal usa radice qualificata e parametro `name` non qualificato. Il test verifica entrambi i WSDL, quattro chiamate dirette e quattro orchestrate (inclusi Unicode, caratteri XML e nome vuoto), poi dodici orchestrazioni concorrenti.

## Lavorare in Eclipse

Il progetto `HelloProcess` viene importato e `HelloProcess.bpel` aperto automaticamente. Il plugin incluso in `docker/eclipse-startup/` scrive `/workspace/.metadata/bpel-editor-check.ok` solo dopo l'apertura nell'editor BPEL, la verifica delle attività grafiche e la selezione con vista Properties disponibile. In caso di errore registra lo stack trace e la healthcheck fallisce.

1. Aprire il desktop nel browser e verificare che compaia il diagramma, non il solo testo XML.
2. Selezionare Receive, CallParticipant e Reply e verificarne le proprietà.
3. Modificare e salvare il processo: `/project` corrisponde alla cartella locale.
4. Per Java: **File → Import → Maven → Existing Maven Projects**, root `/project/services`.

Per nuovi processi: **File → New → Other → BPEL → BPEL Project**, posizione sotto `/project/processes`, con `deploy.xml`, BPEL, WSDL ed eventuali XSD. L'esempio viene importato come progetto di risorse e aperto esplicitamente con l'editor BPEL; non dichiara un nature inesistente. Il deploy è gestito dagli script, non dall'adapter Eclipse.

Su Linux il desktop usa UID/GID 1000: la cartella montata deve essere scrivibile dall'utente. Il container non cambia la proprietà dei sorgenti dell'host.

## Deploy e modifiche

Dopo una modifica BPEL:

```bash
bash scripts/docker.sh deploy
bash scripts/docker.sh test
```

Il deploy riavvia ODE e copia uno snapshot di ogni cartella contenente `deploy.xml`. Riscrive gli endpoint localhost usando il DNS Compose **solo nella copia dentro ODE**, preservando i sorgenti. Per processi aggiuntivi aggiungere test specifici: quelli inclusi verificano HelloProcess.

Dopo una modifica Java:

```bash
docker compose up -d --build --wait --wait-timeout 600 participants
bash scripts/docker.sh test
```

Per modifiche alle immagini o al plugin di avvio rieseguire `bash scripts/docker.sh up`. Non effettuare redeploy durante istanze importanti in esecuzione: il riavvio è una procedura di laboratorio, non un aggiornamento senza interruzioni.

## Persistenza e arresto

| Dato | Posizione | Persistenza |
|---|---|---|
| Sorgenti BPEL/Java | Bind mount `/project` e `/processes` | Cartella locale Git |
| Workspace Eclipse | Volume `eclipse-workspace` | Conservato con stop/down |
| Database e stato ODE | Volume `ode-state` su `WEB-INF/derby-jpadb` | Conservato con stop/down |
| Working directory e deploy ODE | Volumi `ode-work` e `ode-processes` | Conservati con stop/down |
| Log | `docker compose logs` | Esportare prima di rimuovere i container |

```bash
bash scripts/docker.sh stop
bash scripts/docker.sh up
bash scripts/docker.sh down
```

`down` conserva i volumi. `docker compose down -v` cancella workspace e stato ODE: usarlo solo per un reset intenzionale. `restart-test` controlla il ritorno all'operatività dopo il riavvio; `recreate-test` ricrea i container conservando i volumi; non verifica il recupero di processi lunghi o di crash del database.

## GitHub e criteri di accettazione

Repository: [massimotivoli-oss/BPELDesigner](https://github.com/massimotivoli-oss/BPELDesigner).

```bash
git add .
git commit -m "Add Docker desktop, Eclipse BPEL and orchestration checks"
git push
gh run list --limit 3
```

La pipeline costruisce tutte le immagini su Linux amd64, apre l'editor con Xvfb, controlla SOAP, riavvia e ripete i test. Salva log e screenshot anche in caso di errore. Il risultato CI non sostituisce il controllo visivo e delle prestazioni sul Mac Apple Silicon.

Per considerare collaudata la configurazione servono: build senza errori; tre servizi healthy; `test`, `restart-test` e `recreate-test` con exit code 0; diagramma e proprietà funzionanti nel browser del Mac; workflow verde sul commit contenente i container. Conservare le evidenze del commit verificato. Non versionare credenziali, binari, database, workspace o log. Nessuna licenza open source del progetto viene presunta; i componenti mantengono le proprie licenze.

## Script nativi precedenti

`setup.sh`, `start.sh`, `deploy.sh`, `smoke.sh`, `stop.sh` ed `eclipse.sh` restano disponibili per il percorso senza Docker, con JDK 8 locale. Non servono nel percorso Docker e non vanno eseguiti contemporaneamente ai container, perché occupano le stesse porte.

## Fonti ufficiali

- [Eclipse BPEL Designer](https://projects.eclipse.org/projects/soa.bpel)
- [Repository Photon fissato](https://download.eclipse.org/releases/photon/201806271001/)
- [Archivio Eclipse Photon](https://archive.eclipse.org/technology/epp/downloads/release/photon/R/)
- [ODE WAR deployment](https://ode.apache.org/war-deployment.html)
- [Archivio ODE](https://archive.apache.org/dist/ode/)
- [Archivio Tomcat](https://archive.apache.org/dist/tomcat/tomcat-8/v8.5.100/)
