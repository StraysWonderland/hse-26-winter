package demo.activity.events;

import java.time.Instant;
import java.util.UUID;

/**
 * Consumer-side copy of the producer's event contract (CloudEvents 1.0 structured JSON).
 * Duplicated on purpose: shared schemas / contract testing are a student-project topic.
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
}
