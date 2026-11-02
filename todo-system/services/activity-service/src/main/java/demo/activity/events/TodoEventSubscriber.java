package demo.activity.events;

import demo.activity.activity.ActivityRecorder;
import demo.activity.config.AppProperties;
import io.nats.client.Connection;
import io.nats.client.Dispatcher;
import io.nats.client.Message;
import jakarta.annotation.PreDestroy;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Component;
import tools.jackson.databind.json.JsonMapper;

/** Starts consuming once the app is ready; stops consuming first on shutdown. */
@Component
class TodoEventSubscriber {
    private static final Logger log = LoggerFactory.getLogger(TodoEventSubscriber.class);

    private final Connection nats;
    private final JsonMapper json;
    private final ActivityRecorder recorder;
    private final AppProperties props;
    private Dispatcher dispatcher;

    TodoEventSubscriber(Connection nats, JsonMapper json, ActivityRecorder recorder, AppProperties props) {
        this.nats = nats;
        this.json = json;
        this.recorder = recorder;
        this.props = props;
    }

    @EventListener(ApplicationReadyEvent.class)
    void start() {
        dispatcher = nats.createDispatcher(this::handle);
        dispatcher.subscribe(props.natsSubject(), props.natsQueueGroup());
        log.info("subscribed to '{}' in queue group '{}'", props.natsSubject(), props.natsQueueGroup());
    }

    private void handle(Message message) {
        try {
            TodoCloudEvent event = json.readValue(message.getData(), TodoCloudEvent.class);
            recorder.record(event);
        } catch (RuntimeException e) {
            log.error("could not process message on '{}': {}", message.getSubject(), e.toString());
        }
    }

    @PreDestroy
    void stop() {
        if (dispatcher != null) {
            nats.closeDispatcher(dispatcher);
            log.info("unsubscribed");
        }
    }
}
