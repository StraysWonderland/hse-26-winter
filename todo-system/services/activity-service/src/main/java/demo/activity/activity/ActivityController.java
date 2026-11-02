package demo.activity.activity;

import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/activity")
class ActivityController {

    record ActivityResponse(Long id, String type, UUID todoId, String title, String source,
                            Instant occurredAt, String receivedBy, Instant receivedAt) {
        static ActivityResponse from(Activity a) {
            return new ActivityResponse(a.getId(), a.getType(), a.getTodoId(), a.getTitle(), a.getSource(),
                    a.getOccurredAt(), a.getReceivedBy(), a.getReceivedAt());
        }
    }

    private final ActivityRepository repository;

    ActivityController(ActivityRepository repository) {
        this.repository = repository;
    }

    /** Latest 50 events, newest first. */
    @GetMapping
    List<ActivityResponse> latest() {
        return repository.findTop50ByOrderByIdDesc().stream().map(ActivityResponse::from).toList();
    }
}
