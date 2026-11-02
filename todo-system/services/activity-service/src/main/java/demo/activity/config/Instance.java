package demo.activity.config;

import java.net.InetAddress;

/** Identity of this running instance: container ID under Docker, pod name under Kubernetes. */
public final class Instance {
    public static final String HOSTNAME = resolve();

    private Instance() {}

    private static String resolve() {
        String env = System.getenv("HOSTNAME");
        if (env != null && !env.isBlank()) return env;
        try {
            return InetAddress.getLocalHost().getHostName();
        } catch (Exception e) {
            return "unknown";
        }
    }
}
