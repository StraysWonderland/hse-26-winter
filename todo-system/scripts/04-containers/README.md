# 04 Containers — replicate the lecture demo

In the lecture we built the TODO system step by step with Docker. This guide repeats every step
with an explanation, so you can do it yourself.

You will:
1. build an image twice — naively and properly — and compare them,
2. start the system container by container and connect the containers with a network,
3. lose data and then keep it with a volume,
4. describe the same setup in a Compose file,
5. run the full system with Compose.

Plan about 1.5–2 hours. Each part builds on the previous one.

## Prerequisites

- **Docker** with Compose and BuildKit:
  - macOS / Windows: [Docker Desktop](https://docs.docker.com/desktop/) (includes everything), or on macOS [Colima](https://github.com/abiosoft/colima) + `brew install docker docker-compose docker-buildx`
  - Linux: Docker Engine + the `docker-compose-plugin` and `docker-buildx-plugin` packages
- Give Docker at least **6 GB RAM** (Docker Desktop: Settings → Resources; Colima: `colima start --cpu 4 --memory 8`).
- `git` and `curl`.
- **Windows:** run all commands in a WSL2 shell (Ubuntu). PowerShell does not understand the `\` line breaks.

Check:
```bash
docker version
docker compose version
docker buildx version
```

Get the code and go to the project folder. **All commands run from `todo-system/`** unless stated otherwise.
```bash
git clone <repo-url>
cd <repo>/todo-system
```

### The application

```
browser ─► frontend (nginx) ─┬─► todo-service ─► Postgres
                             │        │ event
                             │        ▼
                             │      NATS ─► activity-service ─► Postgres
                             └─► activity feed ───────┘
```

- **frontend** — React UI, built into static files and served by nginx. nginx forwards `/api/...` to the services.
- **todo-service** — REST API (Spring Boot) to create, complete and delete tasks. Stores them in Postgres and
  sends an event for every change.
- **activity-service** — receives the events via the NATS message broker and keeps an activity log.
- **Postgres** — database. **NATS** — message broker.

Parts 1–4 use only frontend, todo-service and Postgres. Part 5 adds the rest.

---

## Part 1 — Dockerfile: naive vs multi-stage

A Dockerfile is the recipe for an image. Each instruction creates a *layer*; Docker caches layers and reuses
them when nothing they depend on has changed.

### 1.1 The naive version

```bash
cat scripts/04-containers/Dockerfile.naive
docker build -f scripts/04-containers/Dockerfile.naive -t todo-service:naive services/todo-service
```

- `-f` selects the Dockerfile, `-t` gives the image a name (`name:tag`).
- The last argument, `services/todo-service`, is the **build context**: the only files `COPY` can see.

The first build takes a few minutes: Gradle downloads all dependencies.

### 1.2 The multi-stage version

```bash
cat services/todo-service/Dockerfile
docker build -t todo-service:1.0 services/todo-service
```

This Dockerfile has two `FROM` lines, i.e. two **stages**:
- the *build* stage has JDK and Gradle and compiles the application,
- the *runtime* stage starts from a small Java runtime image and copies only the result in.

Only the last stage becomes the image. Compilers, build tools and sources stay behind.

### 1.3 Compare

```bash
docker image ls todo-service
docker run --rm --entrypoint id todo-service:naive
docker run --rm --entrypoint id todo-service:1.0
```

What you should see:
- the multi-stage image is several times smaller → faster to pull and push, less software that can have vulnerabilities,
- the naive image runs as `root`, the multi-stage image as an unprivileged user (`uid=10001`).

### 1.4 Change code, rebuild

Simulate a code change by writing a file into the sources, then rebuild both images and time them:

```bash
date > services/todo-service/src/main/resources/build-stamp.txt
time docker build -f scripts/04-containers/Dockerfile.naive -t todo-service:naive services/todo-service
time docker build -t todo-service:1.0 services/todo-service
```

- **Naive:** `COPY . .` copies *everything* before building. Any changed file invalidates that layer and every layer
  after it — so all dependencies are downloaded again.
- **Multi-stage:** dependencies live in a *cache mount* (`RUN --mount=type=cache`) that survives between builds.
  Only the compile step and the application layer are redone.

```bash
docker history todo-service:1.0
```
Each line is a layer. After a code change only the small application layer differs — which is also all that has
to be pushed to a registry.

### 1.5 The frontend image

```bash
cat services/frontend/Dockerfile
docker build -t todo-frontend:1.0 services/frontend
```
Same idea: a Node stage builds static files, the final image is nginx with those files. No Node.js at runtime.

---

## Part 2 — Containers one by one

### 2.1 A database in one command

```bash
docker run -d --name postgres \
  -e POSTGRES_USER=todo -e POSTGRES_PASSWORD=todo -e POSTGRES_DB=todo \
  -p 5432:5432 postgres:17-alpine
docker ps
docker exec postgres psql -U todo -c 'select version()'
```

- `-d` runs the container in the background, `--name` gives it a name you can use in other commands.
- `-e` sets environment variables — the usual way to configure a container.
- `-p 5432:5432` publishes the container port on your machine (`host:container`).
- `docker exec` runs a command inside a running container.

### 2.2 The service — and why it fails

```bash
docker run -d --name todo-service -p 8081:8080 todo-service:1.0
docker ps -a
docker logs todo-service 2>&1 | grep -i refused
```

The container has exited: *Connection to localhost:5432 refused*. The service's default database address is
`localhost:5432`. But **inside a container, `localhost` is the container itself**, not your machine.
Publishing a port (`-p`) only lets your machine reach the container, not the other way round.

```bash
docker rm todo-service
```

### 2.3 Connect containers with a network

```bash
docker network create todo-net
docker network connect todo-net postgres
docker run -d --name todo-service --network todo-net -p 8081:8080 \
  -e DB_URL=jdbc:postgresql://postgres:5432/todo todo-service:1.0
docker logs -f todo-service        # wait for "Started TodoServiceApplication", then Ctrl-C
```

On a network you create yourself, Docker runs a DNS server: containers find each other **by name**. So the
database is now `postgres:5432`. We changed the configuration with an environment variable — the image stays the same.

Try the API:
```bash
curl -s -X POST localhost:8081/api/todos -H 'Content-Type: application/json' -d '{"title":"Hello from curl"}'
curl -s localhost:8081/api/todos
```

### 2.4 The frontend

```bash
docker run -d --name frontend --network todo-net -p 8080:8080 todo-frontend:1.0
```

Open http://localhost:8080 and add some tasks. The activity panel says *not reachable* — activity-service is not
running yet, that comes in part 5.

```bash
docker network inspect todo-net
```
Shows the three containers and their IP addresses on the network.

---

## Part 3 — Where does the data live?

Add two or three tasks in the UI first.

### 3.1 Stop and start

```bash
docker stop postgres
docker start postgres
```
Reload the UI: the tasks are still there. A stopped container keeps its files.

### 3.2 Remove and recreate

```bash
docker rm -f postgres
docker run -d --name postgres --network todo-net \
  -e POSTGRES_USER=todo -e POSTGRES_PASSWORD=todo -e POSTGRES_DB=todo postgres:17-alpine
```
Reload the UI: an error. The data — even the table — is gone. Everything a container writes goes into its own
*writable layer*, and `docker rm` deletes that layer with the container.

todo-service creates its tables when it starts, so restart it:
```bash
docker restart todo-service
```
The UI works again, with an empty list.

### 3.3 Keep the data in a volume

```bash
docker rm -f postgres
docker run -d --name postgres --network todo-net \
  -e POSTGRES_USER=todo -e POSTGRES_PASSWORD=todo -e POSTGRES_DB=todo \
  -v pgdata:/var/lib/postgresql/data postgres:17-alpine
docker restart todo-service
```
`-v pgdata:/var/lib/postgresql/data` mounts a **named volume** called `pgdata` at the directory where Postgres
stores its data. Add some tasks in the UI, then remove and recreate the database again — with the same volume:

```bash
docker rm -f postgres
docker run -d --name postgres --network todo-net \
  -e POSTGRES_USER=todo -e POSTGRES_PASSWORD=todo -e POSTGRES_DB=todo \
  -v pgdata:/var/lib/postgresql/data postgres:17-alpine
```
Reload the UI: the tasks survived. New container, same data.

```bash
docker volume ls
docker volume inspect pgdata
```

| | Named volume `-v name:/path` | Bind mount `-v ./dir:/path` |
|---|---|---|
| Where | managed by Docker | a directory on your machine |
| Typical use | databases, any state | config files, source code during development |

### 3.4 Clean up

```bash
docker rm -f frontend todo-service postgres
docker network rm todo-net
docker volume rm pgdata
```

---

## Part 4 — The same with Docker Compose

Parts 2 and 3 needed a lot of long commands in the right order. Compose describes the same setup in one file.

```bash
cd scripts/04-containers
cat compose.yaml
```

Compare it with your commands: `image`, `environment`, `ports` and `volumes` are the same flags, written down.
There is no `networks:` section — Compose creates one network for all services, and the service name is the DNS name.

```bash
docker compose up -d
docker compose ps
docker network ls
docker volume ls
```
Compose created the network `todo-basic_default` and the volume `todo-basic_pgdata` (prefixed with the project name).
Open http://localhost:8080 and add a task.

```bash
docker compose logs -f todo-service     # Ctrl-C to stop following
docker compose down                     # removes containers and network, keeps the volume
docker compose up -d                    # tasks are still there
docker compose down -v                  # -v also removes the volume
cd ../..
```

The file lives in git, can be reviewed, and everyone starts the exact same setup with one command.

---

## Part 5 — The full system

The `compose.yaml` in the project root runs all five components and adds what a more realistic setup needs.

```bash
docker compose up -d --build --wait
docker compose ps
```
`--wait` returns only when all services report *healthy*. Open http://localhost:8080 — the activity panel works now.

Read `compose.yaml` and look for:

| Feature | What it does | Try it |
|---|---|---|
| `networks: frontend / backend` | the frontend is not on the backend network and cannot reach the database | `docker compose exec frontend nslookup postgres` fails; `docker compose exec todo-service nslookup postgres` works |
| `healthcheck` + `depends_on: condition: service_healthy` | services start only when what they need is ready | `docker compose ps` shows `(healthy)` |
| `./infra/postgres/init` bind mount | a script creates one database per service on first start | `cat infra/postgres/init/01-create-databases.sh` |
| `deploy.resources.limits` | at most 1 CPU and 512 MB RAM per service | `docker stats --no-stream` |
| `ports: "127.0.0.1::8080"` | a random free host port per container | `docker compose port todo-service 8080` |

### Events

In a second terminal, subscribe to all task events:
```bash
docker run --rm -it --network todo-system_backend natsio/nats-box nats sub -s nats://nats:4222 'todo.>'
```
Create, complete and delete tasks in the UI. todo-service does not call activity-service directly: it publishes
an event, and activity-service (and your terminal) receive it.

### Scaling

```bash
docker compose up -d --wait --scale todo-service=3
```
Use the UI and watch the *Who answered* strip: each colour is a different container. Every response carries an
`X-Served-By` header with the container name:
```bash
for i in 1 2 3 4 5 6; do curl -s -o /dev/null -D - localhost:8080/api/todos | grep -i x-served-by; done
```
Why can todo-service be scaled like this, but not Postgres?

### What Compose does not do

```bash
docker kill $(docker compose ps -q todo-service | head -n 1)
docker compose ps -a todo-service
```
The killed container stays dead — nothing replaces it. Compose runs on one machine and does not heal or roll out
updates. That is what Kubernetes is for (lecture 07).

### Clean up

```bash
docker compose down -v
```

---

## Command summary

| Command | Purpose |
|---|---|
| `docker build -t name:tag <context>` | build an image |
| `docker image ls`, `docker history <image>` | list images, show layers |
| `docker run -d --name n -e K=V -p host:ctr -v vol:/path --network net <image>` | start a container |
| `docker ps -a`, `docker logs -f n`, `docker exec n <cmd>` | inspect containers |
| `docker stop/start/restart/rm -f n` | lifecycle |
| `docker network create/connect/inspect` | networks |
| `docker volume ls/inspect/rm` | volumes |
| `docker compose up -d [--build] [--wait] [--scale svc=N]` | start a Compose project |
| `docker compose ps/logs/exec/down [-v]` | manage it |

## Troubleshooting

- **`port is already allocated`** — something else uses 8080, 8081 or 5432. Stop it, or parts 2–4 and 5 are running at the same time: clean up first.
- **Build killed / exit code 137** — Docker has too little memory (see prerequisites).
- **`Conflict. The container name "/postgres" is already in use`** — `docker rm -f postgres`, then retry.
- **Reset everything from this guide:** `./scripts/04-containers/99-reset.sh`
