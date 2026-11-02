package demo.todo.events;

import demo.todo.config.Instance;
import java.time.Instant;
import java.util.UUID;

/**
 * Event envelope in CloudEvents 1.0 structured JSON format.
 * The NATS subject equals {@code type}, e.g. todo.completed; consumers subscribe to "todo.>".
 */
public record TodoCloudEvent(
        String specversion,
        String id,
        String source,
        String type,
        Instant time,
        String datacontenttype,
        Data data) {

    public record Data(UUID todoId, String title, boolean done) {}

    public static TodoCloudEvent of(String type, UUID todoId, String title, boolean done) {
        return new TodoCloudEvent("1.0", UUID.randomUUID().toString(), "/todo-service/" + Instance.HOSTNAME,
                type, Instant.now(), "application/json", new Data(todoId, title, done));
    }
}
