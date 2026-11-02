package demo.activity.activity;

import demo.activity.events.TodoCloudEvent;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "activity")
public class Activity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "event_id", nullable = false, unique = true, length = 64)
    private String eventId;

    @Column(nullable = false, length = 64)
    private String type;

    @Column(name = "todo_id", nullable = false)
    private UUID todoId;

    @Column(length = 200)
    private String title;

    @Column(nullable = false)
    private String source;

    @Column(name = "occurred_at", nullable = false)
    private Instant occurredAt;

    @Column(name = "received_by", nullable = false)
    private String receivedBy;

    @Column(name = "received_at", nullable = false)
    private Instant receivedAt;

    protected Activity() {}

    public static Activity from(TodoCloudEvent event, String receivedBy) {
        Activity a = new Activity();
        a.eventId = event.id();
        a.type = event.type();
        a.todoId = event.data().todoId();
        a.title = event.data().title();
        a.source = event.source();
        a.occurredAt = event.time();
        a.receivedBy = receivedBy;
        a.receivedAt = Instant.now();
        return a;
    }

    public Long getId() { return id; }
    public String getEventId() { return eventId; }
    public String getType() { return type; }
    public UUID getTodoId() { return todoId; }
    public String getTitle() { return title; }
    public String getSource() { return source; }
    public Instant getOccurredAt() { return occurredAt; }
    public String getReceivedBy() { return receivedBy; }
    public Instant getReceivedAt() { return receivedAt; }
}
