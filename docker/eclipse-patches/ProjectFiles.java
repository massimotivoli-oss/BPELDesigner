package org.eclipse.bpel.apache.ode.deploy.ui.util;

import java.util.ArrayList;
import java.util.List;
import org.eclipse.core.resources.IContainer;
import org.eclipse.core.resources.IFile;
import org.eclipse.core.resources.IProject;
import org.eclipse.core.resources.IResource;
import org.eclipse.core.runtime.CoreException;
import org.eclipse.core.runtime.IPath;

/** Resolve both plain BPEL projects and WTP web-content folders. */
public final class ProjectFiles {
    private ProjectFiles() {
    }

    public static List<IFile> collect(IProject project) {
        List<IFile> files = new ArrayList<>();
        IPath webRoot = DeployUtils.getWebContentRootPath(project);
        IContainer container = project;
        // An absent or empty WTP root means the project itself, not getFolder("").
        if (webRoot != null && webRoot.segmentCount() > 0) {
            container = project.getFolder(webRoot);
        }
        try {
            container.accept(resource -> {
                if (resource.getType() == IResource.FILE) {
                    files.add((IFile) resource);
                }
                return true;
            });
        } catch (CoreException error) {
            throw new IllegalStateException("Cannot scan BPEL project " + project.getName(), error);
        }
        return files;
    }
}
