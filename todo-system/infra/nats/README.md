# NATS

NATS is the TODO system's message broker. `todo-service` publishes task-change events to NATS and
`activity-service` consumes them to build the activity feed. It is third-party runtime infrastructure,
so its Kubernetes Deployment and Service live here rather than under an application service.

- `k8s/deployment.yaml` runs the broker and defines health probes and resource limits.
- `k8s/service.yaml` gives clients the stable cluster address `nats:4222`.

