import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.Enumeration;
import java.util.jar.JarEntry;
import java.util.jar.JarFile;
import java.util.jar.JarOutputStream;
import org.objectweb.asm.ClassReader;
import org.objectweb.asm.ClassWriter;
import org.objectweb.asm.Opcodes;
import org.objectweb.asm.tree.ClassNode;
import org.objectweb.asm.tree.InsnNode;
import org.objectweb.asm.tree.MethodInsnNode;
import org.objectweb.asm.tree.MethodNode;
import org.objectweb.asm.tree.VarInsnNode;

/** Replace only the broken project traversal, retaining the rest of the pinned plugin. */
public final class PatchOdeDeploy {
    public static void main(String[] args) throws Exception {
        Path plugin = Paths.get(args[0]);
        Path helper = Paths.get(args[1]);
        Path output = Files.createTempFile(plugin.getParent(), "ode-deploy-", ".jar");
        String utils = "org/eclipse/bpel/apache/ode/deploy/ui/util/DeployUtils.class";
        String helperName = "org/eclipse/bpel/apache/ode/deploy/ui/util/ProjectFiles";
        int patched = 0;
        try (JarFile source = new JarFile(plugin.toFile());
                JarOutputStream target = new JarOutputStream(Files.newOutputStream(output))) {
            if (source.getEntry(helperName + ".class") != null) {
                throw new IllegalStateException("ODE project traversal patch already installed");
            }
            Enumeration<JarEntry> entries = source.entries();
            while (entries.hasMoreElements()) {
                JarEntry entry = entries.nextElement();
                String name = entry.getName();
                if (name.matches("(?i)META-INF/.*\\.(SF|RSA|DSA|EC)")) {
                    continue;
                }
                byte[] bytes;
                try (java.io.InputStream input = source.getInputStream(entry)) {
                    java.io.ByteArrayOutputStream buffer = new java.io.ByteArrayOutputStream();
                    byte[] chunk = new byte[8192];
                    int count;
                    while ((count = input.read(chunk)) != -1) {
                        buffer.write(chunk, 0, count);
                    }
                    bytes = buffer.toByteArray();
                }
                if (name.equals(utils)) {
                    ClassNode type = new ClassNode(Opcodes.ASM6);
                    new ClassReader(bytes).accept(type, 0);
                    for (MethodNode method : type.methods) {
                        if (!method.name.equals("getAllFilesInProject")
                                || !method.desc.equals("(Lorg/eclipse/core/resources/IProject;)Ljava/util/List;")) {
                            continue;
                        }
                        method.instructions.clear();
                        method.tryCatchBlocks.clear();
                        method.localVariables = null;
                        method.instructions.add(new VarInsnNode(Opcodes.ALOAD, 0));
                        method.instructions.add(new MethodInsnNode(Opcodes.INVOKESTATIC,
                            helperName, "collect", method.desc, false));
                        method.instructions.add(new InsnNode(Opcodes.ARETURN));
                        method.maxStack = 1;
                        method.maxLocals = 1;
                        patched++;
                    }
                    ClassWriter writer = new ClassWriter(0);
                    type.accept(writer);
                    bytes = writer.toByteArray();
                }
                // Preserve OSGi headers but discard digest sections for the modified JAR.
                if (name.equalsIgnoreCase("META-INF/MANIFEST.MF")) {
                    String manifest = new String(bytes, "UTF-8");
                    bytes = (manifest.split("\\r?\\n\\r?\\n", 2)[0] + "\r\n\r\n").getBytes("UTF-8");
                }
                target.putNextEntry(new JarEntry(name));
                target.write(bytes);
                target.closeEntry();
            }
            target.putNextEntry(new JarEntry(helperName + ".class"));
            target.write(Files.readAllBytes(helper));
            target.closeEntry();
        }
        if (patched != 1) {
            Files.delete(output);
            throw new IllegalStateException("Expected one ODE traversal method; found " + patched);
        }
        Files.move(output, plugin, java.nio.file.StandardCopyOption.REPLACE_EXISTING);
        System.out.println("Patched ODE descriptor editor for plain BPEL and WTP projects");
    }
}
