package it.bpeldesigner;

import java.io.PrintWriter;
import java.nio.file.Files;
import java.nio.file.Paths;
import org.eclipse.core.resources.*;
import org.eclipse.core.runtime.Path;
import org.eclipse.core.runtime.Platform;
import org.eclipse.ui.forms.editor.FormEditor;
import org.eclipse.ui.*;
import org.eclipse.ui.ide.IDE;
import org.eclipse.bpel.ui.BPELMultipageEditorPart;
import org.eclipse.bpel.ui.BPELEditor;
import org.eclipse.bpel.model.Activity;
import org.eclipse.bpel.model.Sequence;
import org.eclipse.gef.GraphicalViewer;
import org.eclipse.ui.views.properties.PropertySheet;

/** Run inside the real workbench, including SWT and the BPEL graphical editor. */
public class Startup implements IStartup {
    public void earlyStartup() {
        PlatformUI.getWorkbench().getDisplay().asyncExec(() -> {
            try {
                IWorkspace workspace = ResourcesPlugin.getWorkspace();
                IProjectDescription description = workspace.loadProjectDescription(
                    new Path("/project/processes/HelloProcess/.project"));
                description.setLocation(new Path("/project/processes/HelloProcess"));
                IProject project = workspace.getRoot().getProject(description.getName());
                if (!project.exists()) project.create(description, null);
                project.open(null);
                // Re-read versioned natures/builders when upgrading an existing workspace.
                project.setDescription(description, null);
                project.refreshLocal(IResource.DEPTH_INFINITE, null);
                for (String nature : project.getDescription().getNatureIds()) {
                    if (workspace.getNatureDescriptor(nature) == null)
                        throw new IllegalStateException("Unknown project nature: " + nature);
                }
                org.eclipse.wst.common.project.facet.core.IFacetedProject faceted =
                    org.eclipse.wst.common.project.facet.core.ProjectFacetsManager.create(project);
                org.eclipse.wst.common.project.facet.core.IProjectFacetVersion bpelFacet =
                    org.eclipse.wst.common.project.facet.core.ProjectFacetsManager
                        .getProjectFacet("bpel.facet.core").getVersion("2.0");
                if (faceted == null || !faceted.hasProjectFacet(bpelFacet)) {
                    throw new IllegalStateException("HelloProcess is missing the BPEL 2.0 facet");
                }
                Class<?> deployLookup = Platform.getBundle("org.eclipse.bpel.apache.ode.deploy.ui")
                    .loadClass("org.eclipse.bpel.apache.ode.deploy.ui.util.DeployUtils");
                org.eclipse.core.runtime.IPath contentRoot = (org.eclipse.core.runtime.IPath) deployLookup
                    .getMethod("getWebContentRootPath", IProject.class).invoke(null, project);
                if (contentRoot == null || !"bpelContent".equals(contentRoot.makeRelative().toString())) {
                    throw new IllegalStateException("Unexpected BPEL content folder: " + contentRoot);
                }
                IWorkbenchWindow window = PlatformUI.getWorkbench().getActiveWorkbenchWindow();
                IWorkbenchPage page = window.getActivePage();
                IViewPart intro = page.findView("org.eclipse.ui.internal.introview");
                if (intro != null) page.hideView(intro);
                // The legacy ODE bundle does not export its implementation packages.
                Class<?> deployUtils = Platform.getBundle("org.eclipse.bpel.apache.ode.deploy.ui")
                    .loadClass("org.eclipse.bpel.apache.ode.deploy.ui.util.DeployUtils");
                java.util.List<?> projectFiles = (java.util.List<?>) deployUtils
                    .getMethod("getAllFilesInProject", IProject.class).invoke(null, project);
                if (!projectFiles.contains(project.getFile("bpelContent/Hello.wsdl"))
                        || !projectFiles.contains(project.getFile("bpelContent/HelloProcessArtifacts.wsdl"))) {
                    throw new IllegalStateException("ODE descriptor editor cannot discover BPEL content-folder WSDL");
                }
                IEditorPart deployment = IDE.openEditor(page, project.getFile("deploy.xml"),
                    "org.eclipse.bpel.apache.ode.deploy.ui.editors.ODEDeployMultiPageEditor", true);
                if (!(deployment instanceof FormEditor)
                        || !deployment.getClass().getName().endsWith(".ODEDeployMultiPageEditor")) {
                    throw new IllegalStateException("ODE descriptor editor did not open");
                }
                FormEditor descriptor = (FormEditor) deployment;
                if (descriptor.getActivePageInstance() == null
                        || !descriptor.getActivePageInstance().getClass().getName().endsWith(".ProcessPage")
                        || descriptor.getActivePageInstance().getPartControl() == null) {
                    throw new IllegalStateException("ODE deployment process form is unavailable");
                }
                page.closeEditor(deployment, false);
                IEditorPart editor = IDE.openEditor(page, project.getFile("bpelContent/HelloProcess.bpel"),
                    "org.eclipse.bpel.ui.bpeleditor", true);
                if (editor == null) throw new IllegalStateException("BPEL editor creation failed; inspect workspace log");
                if (!editor.getClass().getName().startsWith("org.eclipse.bpel."))
                    throw new IllegalStateException("Unexpected editor: " + editor.getClass().getName());
                BPELMultipageEditorPart bpel = (BPELMultipageEditorPart) editor;
                BPELEditor design = (BPELEditor) bpel.getActiveEditor();
                GraphicalViewer viewer = design.getGraphicalViewer();
                if (viewer.getControl().isDisposed() || viewer.getContents() == null)
                    throw new IllegalStateException("Graphical viewer is unavailable");
                PropertySheet properties = (PropertySheet) page.showView("org.eclipse.ui.views.PropertySheet");
                Sequence sequence = (Sequence) bpel.getProcess().getActivity();
                for (Activity activity : sequence.getActivities()) {
                    if (!viewer.getEditPartRegistry().containsKey(activity))
                        throw new IllegalStateException("Missing graphical activity: " + activity.getName());
                    design.selectModelObject(activity);
                    if (design.getSelection().isEmpty() || properties.getCurrentPage() == null)
                        throw new IllegalStateException("Selection/properties unavailable: " + activity.getName());
                }
                Files.write(Paths.get("/workspace/.metadata/bpel-editor-check.ok"),
                    ("PASS: " + editor.getClass().getName() + " opened bpelContent/HelloProcess.bpel; BPEL 2.0 facet, artifacts WSDL, content mapping, graphical activities, properties and ODE deployment descriptor checked\n").getBytes("UTF-8"));
            } catch (Throwable error) {
                error.printStackTrace();
                try (PrintWriter out = new PrintWriter("/workspace/.metadata/bpel-editor-check.error", "UTF-8")) {
                    error.printStackTrace(out);
                } catch (Exception ignored) { }
            }
        });
    }
}
