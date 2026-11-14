# BPELDesigner

Ambiente legacy riproducibile per sviluppare WS-BPEL 2.0 con Eclipse e distribuire su Apache ODE. Sorgenti di un partecipante SOAP JAX-WS e di un processo di esempio inclusi.

## Stato del collaudo

Verificati localmente: XML, sintassi shell, compilazione Java del partecipante con JDK 8. **Installazione Eclipse, risoluzione p2, avvio Tomcat/ODE e test SOAP non ancora eseguiti**: la sessione di preparazione non dispone di rete per i download. La pipeline GitHub esegue il test di integrazione dopo il push. Il progetto è una base da collaudare, non un ambiente già certificato stabile.

## Versioni fissate

| Componente | Versione | Ruolo |
|---|---|---|
| Eclipse IDE for Java EE Developers | Photon R / 4.8 | Editor legacy x86_64 |
| BPEL Designer | 1.1.2 da repository Photon 201806271001 | Editor WS-BPEL e runtime ODE |
| JDK | 8 | Eclipse e server; impostare JAVA_HOME |
| Apache ODE | 1.3.8 WAR | Orchestratore |
| Apache Tomcat | 8.5.100, due CATALINA_BASE | ODE 8080, partecipanti 8081 |
| Metro JAX-WS | 2.3.7 | Implementazione javax.jws nel WAR |
| Maven | 3.9.9 | Build del partecipante |

Le versioni dei JAR applicativi sono fissate nel POM. Le distribuzioni non sono nel repository: setup scarica dagli archivi ufficiali e verifica SHA-512 per Tomcat/Maven e SHA-1 storico per ODE. Il JDK 8 è un prerequisito locale, non viene scaricato. Tomcat 8.5 e ODE sono componenti legacy: usare questo ambiente solo per sviluppo locale. Connector HTTP e shutdown legati a 127.0.0.1.

## Installazione e avvio

Prerequisiti: JDK 8 completo (javac), Python 3, curl recente, tar, bash; accesso HTTPS ad archive.apache.org, archive.eclipse.org, download.eclipse.org e Maven Central. Linux: librerie GTK compatibili con Eclipse Photon e desktop grafico. macOS Apple Silicon: Eclipse e JDK 8 sono x86_64 e richiedono Rosetta 2; non usare il JDK 21 arm64 per l'editor. L'avvio grafico su macOS recente deve essere verificato; in caso di incompatibilità usare una VM Linux x86_64 con desktop e l'intero progetto al suo interno.

Dalla directory del repository:

```bash
export JAVA_HOME=$(/usr/libexec/java_home -v 1.8) # solo macOS
bash scripts/setup.sh
bash scripts/start.sh
bash scripts/deploy.sh
bash scripts/smoke.sh
```

L'ultimo comando deve stampare `PASS: client -> ODE :8080 -> JAX-WS :8081 -> client`. Attende fino a circa due minuti per endpoint prima dell'invocazione. Il test è riuscito solo con exit code 0. I server restano attivi finché si esegue `bash scripts/stop.sh`.

- Partecipante: http://localhost:8081/participants/hello?wsdl
- Processo: http://localhost:8080/ode/processes/Orchestrator?wsdl
- Log: `.runtime/ode/logs/catalina.out` e `.runtime/participants/logs/catalina.out`.

Il processo usa uno schema document/literal compatibile con il servizio Java: elemento radice qualificato e parametro `name` non qualificato. Il servizio restituisce `Ciao, <nome>!`. La differenza fra le due porte verifica che l'invocazione attraversi realmente i due server.

## Eclipse

```bash
bash scripts/setup-eclipse.sh
bash scripts/eclipse.sh
```

Lo script installa BPEL Designer e il runtime ODE via p2 dalla release Photon fissata. Il pacchetto Linux ha SHA-512 fissato nello script; quello macOS viene scaricato via HTTPS senza checksum locale fissato. L'installazione accetta le licenze delle feature Eclipse richieste.

In Eclipse: File → Import → General → Existing Projects into Workspace → selezionare `processes/HelloProcess`. Aprire `HelloProcess.bpel` con il BPEL Designer. Per il servizio: File → Import → Maven → Existing Maven Projects → `services`. Se l'editor non riconosce il progetto importato, creare un BPEL Project e copiarvi i tre file BPEL/WSDL/deploy.xml. Il funzionamento del nature/builder del progetto deve essere verificato nella GUI.

Il deploy autorevole è `scripts/deploy.sh`, che copia i file nella directory monitorata da ODE; non richiede l'adapter server di Eclipse. Per una modifica Java: arrestare i server, rieseguire setup (ricompila e copia il WAR), riavviare. Per evitare WAR precedentemente espansi, dopo lo stop rimuovere soltanto `.runtime/participants/webapps/participants` prima del riavvio. Non cancellare la cartella del processo durante istanze in esecuzione. Il riavvio conserva il database ODE locale; `.runtime/` contiene stato e log da non versionare.

## GitHub

La directory di destinazione richiesta è `/Users/massimotivoli/Development/Codex/BPELDesigner`. Se i sorgenti sono stati preparati altrove, copiarli in questa directory e aprirla come progetto prima di lavorare con Git.

Con GitHub CLI installata e autenticata:

```bash
gh auth login
bash scripts/publish.sh
# oppure, per renderlo pubblicamente visibile:
# bash scripts/publish.sh --public
```

Lo script crea un repository privato `BPELDesigner` nell'account autenticato e invia il commit iniziale; con origin esistente esegue push su quel remote. Verificare origin prima dell'uso. Non sono inclusi credenziali, binari, workspace Eclipse o database. Nessuna licenza del codice del progetto viene presunta: sceglierla prima di redistribuirlo come open source. I componenti scaricati conservano le rispettive licenze.

## Verifiche e limiti

`python3 scripts/check.py` controlla sintassi e collegamenti statici. GitHub Actions compila il WAR, installa i server e prova l'orchestrazione; conserva i log anche se il job fallisce. La GUI Eclipse non viene collaudata dalla pipeline. Problemi di p2, SWT/macOS, download degli archivi, compilazione BPEL o avvio database restano possibili fino al primo collaudo completo.

## Fonti ufficiali

- https://projects.eclipse.org/projects/soa.bpel
- https://download.eclipse.org/releases/photon/201806271001/buildInfo/reporeports/reports/bundleNames.html
- https://www.eclipse.org/downloads/packages/file/51981
- https://ode.apache.org/getting-ode.html
- https://ode.apache.org/war-deployment.html
- https://archive.apache.org/dist/ode/
- https://archive.apache.org/dist/tomcat/tomcat-8/v8.5.100/
