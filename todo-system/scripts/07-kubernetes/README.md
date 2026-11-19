# 07 Kubernetes — deploy and operate the TODO system

In the containers lecture, Docker Compose described the whole system and scaled a service, but a killed
container stayed dead. This lecture moves the same images to Kubernetes and builds the missing operational
behaviour step by step.

You will:

1. create a local Kubernetes cluster and run a bare Pod,
2. let a Deployment maintain replicas and put a stable Service in front of them,
3. provide configuration and secrets, and persist Postgres data,
4. deploy the complete TODO system from declarative manifests,
5. scale, self-heal, inspect, roll out and roll back the application.

Plan about 1.5–2 hours. Each part builds on the previous one. The numbered scripts reproduce the live lecture;
the commands below let you repeat it manually.

## Prerequisites

- Docker with at least 6 GB RAM available
- [`kubectl`](https://kubernetes.io/docs/tasks/tools/)
- [`kind`](https://kind.sigs.k8s.io/docs/user/quick-start/)
- `curl`
- macOS, Linux, or a WSL2 shell on Windows

Check the tools:

```bash
docker version
kind version
kubectl version --client
```

All commands run from `todo-system/` unless stated otherwise. The setup uses a dedicated kind cluster named
`todo-lecture`; every supplied script explicitly selects its context (`kind-todo-lecture`).

### Repository layout

Deployment resources live with the component they deploy, not in this lecture folder:

```text
todo-system/
├── kustomization.yaml                 # composes the complete system
├── k8s/
│   ├── namespace.yaml
│   └── local/kind-config.yaml         # local-cluster concern
├── services/
│   ├── frontend/k8s/                  # Deployment, Service, kustomization
│   ├── todo-service/k8s/
│   └── activity-service/k8s/
└── infra/
    ├── postgres/k8s/                  # StatefulSet, Service, config and credentials
    └── nats/k8s/                      # third-party message broker
```

Each component can evolve with its source and can be applied independently. The root Kustomization is the
application-level bundle, analogous to the root `compose.yaml`. The files under `scripts/07-kubernetes/` only
pace the lecture and are not required to deploy the application.

### The target system

```text
browser :8080
    │
    ▼ NodePort Service
frontend Deployment (2 Pods)
    ├──► todo-service Service ─► Deployment (2 Pods) ─┐
    │                                                ├──► postgres Service ─► StatefulSet + PVC
    └──► activity-service Service ─► Deployment ─────┘
                       ▲                    (2 Pods)
                       │
                       └──── NATS Service ◄── todo events
```

A **Pod** runs one application instance. A **Deployment** keeps the requested number of replaceable Pods alive.
A **Service** gives those changing Pods one stable DNS name and virtual IP. Postgres is different: its
**StatefulSet** gives it stable identity, while a **PersistentVolumeClaim** keeps its files outside the Pod.

---

## Preparation — local cluster and images

The application images are not published to a registry. Build them with Docker and load them directly into
kind's node:

```bash
./scripts/07-kubernetes/00-prepare.sh
```

The script:

- creates `todo-lecture` from `k8s/local/kind-config.yaml` if it does not exist,
- maps the cluster's frontend NodePort to http://localhost:8080,
- builds version `0.1.0` of all services and version `0.2.0` of todo-service for the rollout exercise,
- copies those images into kind's container runtime.

Unlike Docker, Kubernetes does not automatically see images in the host's image store. A real CI/CD pipeline
would push them to a registry and the cluster would pull them. `kind load docker-image` is the local equivalent.

Inspect the cluster:

```bash
kubectl --context kind-todo-lecture cluster-info
kubectl --context kind-todo-lecture get nodes -o wide
```

The control plane stores desired state and makes scheduling decisions. The node's kubelet turns assigned Pods
into running containers. In this small learning cluster both roles happen in one Docker container.

---

## Part 1 — the smallest workload: a Pod

Create the namespace and one Pod imperatively:

```bash
kubectl --context kind-todo-lecture apply -f k8s/namespace.yaml
kubectl --context kind-todo-lecture -n todo run frontend-pod \
  --image=todo-system/frontend:0.1.0 \
  --image-pull-policy=IfNotPresent \
  --port=8080 \
  --env=NGINX_RESOLVER=10.96.0.10
kubectl --context kind-todo-lecture -n todo wait \
  --for=condition=Ready pod/frontend-pod --timeout=60s
```

- A namespace groups and scopes the demo's resources.
- `run` sends a Pod specification to the API server; it does not start the container directly.
- The scheduler selects a node; its kubelet pulls or finds the image and starts the container.
- `Ready` means the Pod may receive traffic. `Running` alone does not guarantee that.

Inspect it:

```bash
kubectl --context kind-todo-lecture -n todo get pod frontend-pod -o wide
kubectl --context kind-todo-lecture -n todo describe pod frontend-pod
kubectl --context kind-todo-lecture -n todo logs frontend-pod
```

`get` is the overview, `describe` combines specification, current status and events, and `logs` shows container
output. These three commands are the start of most investigations.

Delete the Pod:

```bash
kubectl --context kind-todo-lecture -n todo delete pod frontend-pod
kubectl --context kind-todo-lecture -n todo get pods
```

It stays deleted. A bare Pod has no controller maintaining it. This is why applications normally create Pods
through a Deployment, Job, DaemonSet or StatefulSet.

Live-demo equivalent:

```bash
./scripts/07-kubernetes/1-pod.sh
```

---

## Part 2 — desired state with a Deployment and Service

Read and apply the frontend manifest:

```bash
cat services/frontend/k8s/deployment.yaml
cat services/frontend/k8s/service.yaml
kubectl --context kind-todo-lecture apply -k services/frontend/k8s
kubectl --context kind-todo-lecture -n todo rollout status deployment/frontend
```

Look at the ownership chain:

```bash
kubectl --context kind-todo-lecture -n todo get deployment,replicaset,pod \
  -l app.kubernetes.io/name=frontend
```

```text
Deployment (desired replicas and update strategy)
    └── ReplicaSet (maintains this template revision)
            └── Pods (replaceable runtime instances)
```

The manifest says `replicas: 2`; controllers continuously reconcile actual state toward that desired state.
Delete either Pod and watch:

```bash
kubectl --context kind-todo-lecture -n todo delete pod \
  -l app.kubernetes.io/name=frontend --wait=false
kubectl --context kind-todo-lecture -n todo get pods \
  -l app.kubernetes.io/name=frontend --watch
```

Press Ctrl-C after the replacement is ready.

### Stable networking

Pod names and IPs change when replicas are replaced. The Service selects ready frontend Pods by label:

```bash
kubectl --context kind-todo-lecture -n todo get service frontend
kubectl --context kind-todo-lecture -n todo get endpointslice \
  -l kubernetes.io/service-name=frontend
curl http://localhost:8080/healthz
```

`frontend` is a `NodePort` Service. The kind configuration maps its port 30080 to host port 8080 so the browser
can enter the cluster. Internal services remain `ClusterIP`: they are reachable only inside the cluster as
`todo-service:8080`, `activity-service:8080`, `postgres:5432` and `nats:4222`.

The frontend page loads now, but API requests return 502 because its backend Services do not exist yet. That is
intentional; the next parts add them.

Live-demo equivalent:

```bash
./scripts/07-kubernetes/2-deployment-service.sh
```

---

## Part 3 — configuration, secrets and state

Apply the platform resources:

```bash
cat infra/postgres/k8s/statefulset.yaml
cat infra/nats/k8s/deployment.yaml
kubectl --context kind-todo-lecture apply -k infra/postgres/k8s
kubectl --context kind-todo-lecture apply -k infra/nats/k8s
kubectl --context kind-todo-lecture -n todo rollout status statefulset/postgres
kubectl --context kind-todo-lecture -n todo rollout status deployment/nats
```

### Configuration and credentials

The Postgres init script is a ConfigMap mounted as a file. Passwords are a Secret exposed to containers through
`secretKeyRef`. Both separate environment-specific configuration from the image.

```bash
kubectl --context kind-todo-lecture -n todo get configmap,secret
kubectl --context kind-todo-lecture -n todo describe configmap postgres-init
kubectl --context kind-todo-lecture -n todo describe secret database-credentials
```

`describe secret` deliberately hides values. Kubernetes Secrets are base64-encoded, not inherently encrypted;
production clusters also need narrowly scoped RBAC, encryption at rest and usually an external secret manager.
The values here are intentionally disposable lecture credentials.

### Probes and resource management

The manifests define:

- **startup probes** for slow-starting Java processes,
- **readiness probes** to remove an unhealthy Pod from Service endpoints,
- **liveness probes** to restart a stuck container,
- resource **requests** for scheduling and **limits** for isolation.

Inspect the effective configuration and recent probe events:

```bash
kubectl --context kind-todo-lecture -n todo describe pod postgres-0
kubectl --context kind-todo-lecture -n todo get events --sort-by=.lastTimestamp
```

### Persistent data

```bash
kubectl --context kind-todo-lecture -n todo get statefulset,pod,pvc
kubectl --context kind-todo-lecture -n todo describe pvc data-postgres-0
```

The StatefulSet's `volumeClaimTemplates` creates `data-postgres-0`. Delete the Pod and the controller creates a
new `postgres-0`, mounting the same claim:

```bash
kubectl --context kind-todo-lecture -n todo delete pod postgres-0
kubectl --context kind-todo-lecture -n todo rollout status statefulset/postgres
kubectl --context kind-todo-lecture -n todo get pod,pvc
```

Why not scale Postgres by changing `replicas`? Multiple database processes cannot safely share an ordinary
filesystem. Database replication requires database-aware configuration, separate volumes and failover logic,
usually supplied by an operator or a managed database service.

Live-demo equivalent:

```bash
./scripts/07-kubernetes/3-state-configuration.sh
```

---

## Part 4 — deploy the complete system

The root `kustomization.yaml` groups the co-located component resources as one deployable unit:

```bash
cat kustomization.yaml
kubectl --context kind-todo-lecture apply -k .
```

Wait for the workloads:

```bash
kubectl --context kind-todo-lecture -n todo rollout status statefulset/postgres
for name in nats todo-service activity-service frontend; do
  kubectl --context kind-todo-lecture -n todo rollout status deployment/$name
done
kubectl --context kind-todo-lecture -n todo get all
kubectl --context kind-todo-lecture -n todo get pvc
```

Open http://localhost:8080, create tasks, complete one and delete one. The activity feed is populated by events:
todo-service publishes to NATS and the activity-service queue group records each event once.

From the command line:

```bash
curl -s -X POST localhost:8080/api/todos \
  -H 'Content-Type: application/json' \
  -d '{"title":"Hello Kubernetes"}'
curl -s localhost:8080/api/todos
curl -s localhost:8080/api/activity
```

### How service discovery works

```bash
kubectl --context kind-todo-lecture -n todo exec deploy/frontend -- \
  getent hosts todo-service
kubectl --context kind-todo-lecture -n todo get endpointslice \
  -l kubernetes.io/service-name=todo-service
```

CoreDNS resolves the Service name. Most clients can use the short name `todo-service`; the frontend manifest uses
`todo-service.todo.svc.cluster.local` because nginx resolves variable-based proxy targets itself and does not add
the Pod's DNS search suffix. The Service's EndpointSlice contains only Pods that match its selector and are ready.
Applications depend on the stable name, not a Pod address.

Live-demo equivalent:

```bash
./scripts/07-kubernetes/4-full-system.sh
```

---

## Part 5 — operate the application

### Scale

Stateless Pods can share Postgres and carry no local application state, so scaling is only a desired-state edit:

```bash
kubectl --context kind-todo-lecture -n todo scale deployment todo-service --replicas=3
kubectl --context kind-todo-lecture -n todo rollout status deployment/todo-service
kubectl --context kind-todo-lecture -n todo get pods \
  -l app.kubernetes.io/name=todo-service -o wide
```

Send repeated requests. `X-Served-By` identifies the Pod behind each response:

```bash
for i in 1 2 3 4 5 6; do
  curl -s -o /dev/null -D - localhost:8080/api/todos | grep -i x-served-by
done
```

### Self-heal

```bash
kubectl --context kind-todo-lecture -n todo get pods \
  -l app.kubernetes.io/name=todo-service
kubectl --context kind-todo-lecture -n todo delete pod <one-pod-name>
kubectl --context kind-todo-lecture -n todo get pods \
  -l app.kubernetes.io/name=todo-service --watch
```

The Service keeps routing to ready replicas while the Deployment replaces the deleted one. This is the direct
answer to the final limitation in the Docker lecture.

### Roll out a version

The preparation script loaded a second todo-service image. A patch changes its image and visible version in one
Pod-template revision:

```bash
kubectl --context kind-todo-lecture -n todo patch deployment todo-service \
  --type=strategic \
  -p '{"spec":{"template":{"spec":{"containers":[{"name":"todo-service","image":"todo-system/todo-service:0.2.0","env":[{"name":"APP_VERSION","value":"0.2.0"}]}]}}}}'
kubectl --context kind-todo-lecture -n todo rollout status deployment/todo-service
kubectl --context kind-todo-lecture -n todo rollout history deployment/todo-service
curl -s -o /dev/null -D - localhost:8080/api/todos | \
  grep -Ei 'x-app-version|x-served-by'
```

The Deployment uses `maxUnavailable: 0` and `maxSurge: 1`: it starts a new Pod, waits for readiness, then removes
an old Pod. Watch it in another terminal with `kubectl -n todo get pods -w`.

Undo the revision:

```bash
kubectl --context kind-todo-lecture -n todo rollout undo deployment/todo-service
kubectl --context kind-todo-lecture -n todo rollout status deployment/todo-service
```

Live-demo equivalent:

```bash
./scripts/07-kubernetes/5-operate.sh
```

---

## Declarative changes versus teaching commands

`kubectl scale`, `patch` and `rollout undo` make the operating concepts visible during a lecture. In a managed
environment, commit lasting changes to the manifests and let CI/CD apply the reviewed version. Otherwise the
next `kubectl apply -k ...` will restore the repository's declared replica count, image and configuration.

The manifests intentionally stay as plain YAML, one resource per file, so every Kubernetes object is easy to
find and review. Each component has a small Kustomization, and the root Kustomization composes the application;
later environments can add overlays without templating the base files.

## Command summary

| Command | Purpose |
|---|---|
| `kubectl get ...` | list current resource state |
| `kubectl describe ...` | specification, status and related events |
| `kubectl logs ... [-f]` | read or follow container output |
| `kubectl exec ... -- command` | run a diagnostic command in a container |
| `kubectl apply -f file` / `-k dir` | reconcile declarative YAML / Kustomize resources |
| `kubectl rollout status/history/undo` | observe or control Deployment revisions |
| `kubectl scale deployment name --replicas=N` | change desired replica count |
| `kubectl get events --sort-by=.lastTimestamp` | inspect recent cluster decisions and failures |
| `kubectl get endpointslice` | see ready Service backends |

## Clean up

Delete all application resources and their persistent data, but keep the cluster for the next run:

```bash
./scripts/07-kubernetes/99-reset.sh
```

Delete the complete dedicated kind cluster:

```bash
DELETE_CLUSTER=1 ./scripts/07-kubernetes/99-reset.sh
```

Deleting the namespace removes its PVC and data. Deleting the cluster also removes every image loaded into it.

## Troubleshooting

- **`cluster ... is missing`** — run `./scripts/07-kubernetes/00-prepare.sh`.
- **`ImagePullBackOff` for `todo-system/...`** — local images were not loaded; rerun `00-prepare.sh`. The manifests
  use `IfNotPresent` so Kubernetes uses images loaded into kind.
- **localhost:8080 does not answer** — the cluster may have been created without this lecture's port mapping.
  Delete only the dedicated cluster with `kind delete cluster --name todo-lecture`, then rerun `00-prepare.sh`.
- **A Pod is `Pending`** — use `kubectl --context kind-todo-lecture -n todo describe pod <name>`; common causes
  appear at the bottom under Events, including insufficient memory or an unbound PVC.
- **A Pod is `CrashLoopBackOff`** — inspect `logs <pod> --previous` and `describe pod <pod>`.
- **The frontend returns 502** — check backend Pods and Service endpoints:
  `kubectl --context kind-todo-lecture -n todo get pods,endpointslice`.
- **Postgres init changes do not take effect** — scripts in `/docker-entrypoint-initdb.d` run only for an empty
  data directory. Run `99-reset.sh` to remove the namespace and PVC, then redeploy.
- **Docker build is killed / exit 137** — give Docker more memory (for Colima:
  `colima start --cpu 4 --memory 8`).

