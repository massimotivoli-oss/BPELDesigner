"""Deploy a snapshot of sources. Never rewrite the host's WSDL endpoints."""
import shutil
import sys
from pathlib import Path

source = Path(sys.argv[1]) if len(sys.argv) > 1 else Path('/processes')
destination = Path(sys.argv[2]) if len(sys.argv) > 2 else Path('/opt/tomcat/webapps/ode/WEB-INF/processes')
for project in sorted(source.iterdir()):
    if not project.is_dir() or not (project / 'deploy.xml').is_file():
        continue
    target = destination / project.name
    target.mkdir(parents=True, exist_ok=True)
    # One-time migration of the bundled example from project-root sources.
    # Leave other deployments and the ODE database untouched.
    migrated = False
    if (project.name == 'HelloProcess'
            and (project / 'bpelContent/HelloProcess.bpel').is_file()
            and not (project / 'HelloProcess.bpel').exists()):
        for name in ['HelloProcess.bpel', 'Hello.wsdl', 'HelloProcess.cbp']:
            legacy = target / name
            if legacy.is_file():
                legacy.unlink()
                migrated = True
    # Copy the descriptor last, so ODE sees a complete deployment unit.
    for path in project.rglob('*'):
        if any(part.startswith('.') for part in path.relative_to(project).parts):
            continue
        if path.is_file() and path.suffix in ('.bpel', '.wsdl', '.xsd', '.xml') and path.name != 'deploy.xml':
            output = target / path.relative_to(project)
            output.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(path, output)
            if path.suffix == '.wsdl':
                # Keep namespace declarations used by WSDL QName attributes.
                text = output.read_text()
                output.write_text(text.replace('http://localhost:8081/', 'http://participants:8081/')
                                  .replace('http://localhost:8080/', 'http://ode:8080/'))
    shutil.copy2(project / 'deploy.xml', target / 'deploy.xml')
    if migrated:
        # Make the migrated unit visible to ODE even if the source descriptor is unchanged.
        (target / 'deploy.xml').touch()
    print('Deployed ' + project.name)
