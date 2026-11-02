package demo.todo.events;

import demo.todo.config.NatsClient;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;
import tools.jackson.databind.json.JsonMapper;

/** Core NATS: at-most-once, fire-and-forget. JetStream would add persistence and replay. */
@Component
class NatsEventPublisher {
    private static final Logger log = LoggerFactory.getLogger(NatsEventPublisher.class);

    private final NatsClient nats;
    private final JsonMapper json;

    NatsEventPublisher(NatsClient nats, JsonMapper json) {
        this.nats = nats;
        this.json = json;
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    public void publish(TodoCloudEvent event) {
        nats.connection().ifPresentOrElse(conn -> {
            try {
                conn.publish(event.type(), json.writeValueAsBytes(event));
                log.info("published {} id={} todo={}", event.type(), event.id(), event.data().todoId());
            } catch (RuntimeException e) {
                log.error("could not publish {} id={}: {}", event.type(), event.id(), e.toString());
            }
        }, () -> log.info("NATS not connected, dropped {} id={}", event.type(), event.id()));
    }
}
