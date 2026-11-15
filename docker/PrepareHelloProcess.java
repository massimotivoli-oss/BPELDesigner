package org.apache.ode.store;

import java.io.File;

/** Compile the bundled example before ODE restores its persistent process registry. */
public final class PrepareHelloProcess {
    public static void main(String[] args) {
        File directory = new File(args[0]);
        File source = new File(directory, "bpelContent/HelloProcess.bpel");
        File compiled = new File(directory, "bpelContent/HelloProcess.cbp");
        if (source.isFile()) {
            // Use the pinned engine's compiler and deployment-unit resource resolution.
            new DeploymentUnitDir(directory).compile();
            if (!compiled.isFile()) {
                throw new IllegalStateException("HelloProcess migration did not produce a compiled process");
            }
            System.out.println("Prepared HelloProcess and its WSDL imports before restoring ODE state");
        }
    }
}
