package demo.activity.activity;

import static org.junit.jupiter.api.Assertions.assertEquals;

import demo.activity.events.TodoCloudEvent;
import java.time.Instant;
import java.util.UUID;
import org.junit.jupiter.api.Test;

class ActivityTest {

    @Test
    void mapsEventToActivity() {
        UUID todoId = UUID.randomUUID();
        Instant time = Instant.parse("2026-10-29T10:00:00Z");
        TodoCloudEvent event = new TodoCloudEvent("1.0", "evt-1", "/todo-service/abc", "todo.completed",
                time, "application/json", new TodoCloudEvent.Data(todoId, "Write slides", true));

        Activity activity = Activity.from(event, "activity-1");

        assertEquals("evt-1", activity.getEventId());
        assertEquals("todo.completed", activity.getType());
        assertEquals(todoId, activity.getTodoId());
        assertEquals("Write slides", activity.getTitle());
        assertEquals(time, activity.getOccurredAt());
        assertEquals("activity-1", activity.getReceivedBy());
    }
}
