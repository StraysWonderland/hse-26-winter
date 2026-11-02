package demo.todo.todo;

import static org.springframework.http.HttpStatus.BAD_REQUEST;
import static org.springframework.http.HttpStatus.NOT_FOUND;

import demo.todo.events.TodoCloudEvent;
import java.util.List;
import java.util.UUID;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

/**
 * Domain events are published in-process and forwarded to NATS only after the DB commit
 * (see NatsEventPublisher). Deliberate teaching gap: commit succeeds + publish fails = lost
 * event (dual write). Fix: transactional outbox.
 */
@Service
@Transactional
public class TodoService {

    private final TodoRepository repository;
    private final ApplicationEventPublisher events;

    public TodoService(TodoRepository repository, ApplicationEventPublisher events) {
        this.repository = repository;
        this.events = events;
    }

    @Transactional(readOnly = true)
    public List<Todo> list() {
        return repository.findAllByOrderByCreatedAtDesc();
    }

    @Transactional(readOnly = true)
    public Todo get(UUID id) {
        return repository.findById(id)
                .orElseThrow(() -> new ResponseStatusException(NOT_FOUND, "todo " + id + " not found"));
    }

    public Todo create(String title) {
        Todo todo = repository.save(new Todo(title.strip()));
        publish("todo.created", todo);
        return todo;
    }

    public Todo update(UUID id, String title, Boolean done) {
        Todo todo = get(id);
        if (title != null) {
            if (title.isBlank()) throw new ResponseStatusException(BAD_REQUEST, "title must not be blank");
            if (!title.strip().equals(todo.getTitle())) {
                todo.rename(title.strip());
                publish("todo.renamed", todo);
            }
        }
        if (done != null && done != todo.isDone()) {
            todo.markDone(done);
            publish(done ? "todo.completed" : "todo.reopened", todo);
        }
        return todo;
    }

    public void delete(UUID id) {
        Todo todo = get(id);
        repository.delete(todo);
        publish("todo.deleted", todo);
    }

    private void publish(String type, Todo todo) {
        events.publishEvent(TodoCloudEvent.of(type, todo.getId(), todo.getTitle(), todo.isDone()));
    }
}
