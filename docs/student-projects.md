# Student projects

Goal: pick one tool from the [CNCF landscape](https://landscape.cncf.io), and implement a showcase for it.
Either by developing your own set of applications or by integrating it with this system, and show a concrete before/after.

## Ground rules

- Fork the repo. The app must still start with either `docker compose up` or preferably a Kubernetes setup.
- Document your code and architecture.
- Show the effect live: a measurable or visible difference, not only "it is installed".
- Name one limitation or trade-off of the tool you chose.

## Project ideas (non-exhaustive)

| Area | Example tools | What to demonstrate with this app |
|---|---|---|
| Packaging | Helm, Kustomize | one chart/overlay per environment, upgrade + rollback |
| GitOps | Argo CD, Flux | deploy by commit, drift detection, rollback |
| Build | Cloud Native Buildpacks | images without a Dockerfile; compare size/layers with ours |
| Supply chain | Sigstore cosign, Harbor | sign images, enforce signature on deploy, vulnerability scan |
| Policy | Kyverno, OPA Gatekeeper | reject root containers, unpinned tags, missing limits |
| Metrics | Prometheus, Grafana | RED dashboard; alert when chaos raises the error rate |
| Tracing | OpenTelemetry, Jaeger | trace browser → nginx → service → DB; propagate across NATS |
| Logs | Fluent Bit, Loki | aggregate JSON logs, correlate by event id |
| Service mesh | Linkerd, Istio | mTLS, retries/timeouts against injected failures, traffic split |
| Progressive delivery | Argo Rollouts, Flagger | canary of todo-service 0.2.0 using `X-App-Version` |
| Autoscaling | KEDA | scale activity-service on message backlog (requires JetStream) |
| Messaging | NATS JetStream, Strimzi (Kafka) | durable delivery, replay, compare to core NATS |
| Data | CloudNativePG | HA Postgres, failover while the app runs, backups |
| Chaos | Chaos Mesh, LitmusChaos | pod kill / network delay; show what breaks and why |
| Identity | Keycloak | OIDC login in the frontend, token check in the services |
| Runtime security | Falco | detect a shell spawned in a container |
| Developer portal | Backstage | catalog entries, API docs, ownership |
| App runtime | Dapr | replace the NATS client with Dapr pub/sub; compare coupling |

Check the project's maturity (sandbox / incubating / graduated) and maintenance activity before choosing.
