package demo.activity.config;

import io.nats.client.Connection;
import io.nats.client.Nats;
import io.nats.client.Options;
import java.io.IOException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
class NatsConfig {
    private static final Logger log = LoggerFactory.getLogger(NatsConfig.class);

    @Bean(destroyMethod = "close")
    Connection natsConnection(AppProperties props) throws IOException, InterruptedException {
        Options options = new Options.Builder()
                .server(props.natsUrl())
                .connectionName("activity-service/" + Instance.HOSTNAME)
                .maxReconnects(-1)
                .connectionListener((conn, type) -> log.info("NATS connection event: {}", type))
                .build();
        // Keeps retrying instead of failing startup when NATS is not reachable yet.
        return Nats.connectReconnectOnConnect(options);
    }
}
