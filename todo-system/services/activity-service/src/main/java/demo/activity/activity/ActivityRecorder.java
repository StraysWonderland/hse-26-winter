package demo.activity.activity;

import demo.activity.config.Instance;
import demo.activity.events.TodoCloudEvent;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class ActivityRecorder {
    private static final Logger log = LoggerFactory.getLogger(ActivityRecorder.class);

    private final ActivityRepository repository;

    ActivityRecorder(ActivityRepository repository) {
        this.repository = repository;
    }

    /** Idempotent consumer: an event id is stored at most once (also enforced by a unique constraint). */
    @Transactional
    public void record(TodoCloudEvent event) {
        if (repository.existsByEventId(event.id())) {
            log.info("duplicate event {} ignored", event.id());
            return;
        }
        repository.save(Activity.from(event, Instance.HOSTNAME));
        log.info("recorded {} id={} todo={}", event.type(), event.id(), event.data().todoId());
    }
}
