package demo.todo.config;

import io.nats.client.Connection;
import io.nats.client.Nats;
import io.nats.client.Options;
import java.io.IOException;
import java.util.Optional;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * NATS is optional for todo-service: the service starts and serves requests without it
 * (first lecture showcases run without a broker). A background thread connects as soon as NATS
 * is reachable; after that, the client reconnects on its own.
 */
public class NatsClient implements AutoCloseable {
    private static final Logger log = LoggerFactory.getLogger(NatsClient.class);
    private static final long RETRY_MS = 5_000;

    private final String url;
    private final Options options;
    private final Thread connector;
    private volatile Connection connection;
    private volatile boolean closed;

    public NatsClient(String url, String connectionName) {
        this.url = url;
        this.options = new Options.Builder()
                .server(url)
                .connectionName(connectionName)
                .maxReconnects(-1)
                .connectionListener((conn, type) -> log.info("NATS connection event: {}", type))
                .build();
        this.connector = Thread.ofVirtual().name("nats-connect").start(this::connectLoop);
    }

    private void connectLoop() {
        boolean warned = false;
        while (!closed) {
            try {
                connection = Nats.connect(options);
                log.info("connected to NATS at {}", url);
                if (closed) connection.close();
                return;
            } catch (IOException e) {
                if (!warned) {
                    log.warn("NATS not reachable at {}, events are dropped until it is; retrying every {} s",
                            url, RETRY_MS / 1000);
                    warned = true;
                }
            } catch (InterruptedException e) {
                return;
            }
            try {
                Thread.sleep(RETRY_MS);
            } catch (InterruptedException e) {
                return;
            }
        }
    }

    public Optional<Connection> connection() {
        return Optional.ofNullable(connection);
    }

    @Override
    public void close() throws InterruptedException {
        closed = true;
        connector.interrupt();
        Connection c = connection;
        if (c != null) c.close();
    }
}
