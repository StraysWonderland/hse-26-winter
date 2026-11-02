package demo.todo.todo;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.net.URI;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/todos")
class TodoController {

    record CreateTodoRequest(@NotBlank @Size(max = 200) String title) {}

    record UpdateTodoRequest(@Size(max = 200) String title, Boolean done) {}

    record TodoResponse(UUID id, String title, boolean done, Instant createdAt, Instant updatedAt) {
        static TodoResponse from(Todo t) {
            return new TodoResponse(t.getId(), t.getTitle(), t.isDone(), t.getCreatedAt(), t.getUpdatedAt());
        }
    }

    private final TodoService service;

    TodoController(TodoService service) {
        this.service = service;
    }

    @GetMapping
    List<TodoResponse> list() {
        return service.list().stream().map(TodoResponse::from).toList();
    }

    @GetMapping("/{id}")
    TodoResponse get(@PathVariable UUID id) {
        return TodoResponse.from(service.get(id));
    }

    @PostMapping
    ResponseEntity<TodoResponse> create(@Valid @RequestBody CreateTodoRequest request) {
        Todo todo = service.create(request.title());
        return ResponseEntity.created(URI.create("/api/todos/" + todo.getId())).body(TodoResponse.from(todo));
    }

    @PatchMapping("/{id}")
    TodoResponse update(@PathVariable UUID id, @Valid @RequestBody UpdateTodoRequest request) {
        return TodoResponse.from(service.update(id, request.title(), request.done()));
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    void delete(@PathVariable UUID id) {
        service.delete(id);
    }
}
