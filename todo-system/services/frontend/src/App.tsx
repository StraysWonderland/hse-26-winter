import { useCallback, useEffect, useMemo, useState, type FormEvent } from 'react'
import { api, onResponse, type Activity, type Hit, type Service, type Todo } from './api'

const POLL_MS = 2000
const MAX_HITS = 48

const EVENT_LABELS: Record<string, string> = {
  'todo.created': 'Created',
  'todo.completed': 'Completed',
  'todo.reopened': 'Reopened',
  'todo.renamed': 'Renamed',
  'todo.deleted': 'Deleted',
}

/** Stable colour per instance, so replicas are distinguishable at a glance. */
function hue(host: string): number {
  let h = 0
  for (const c of host) h = (h * 31 + c.charCodeAt(0)) % 360
  return h
}

function shortHost(host: string): string {
  return host.length > 14 ? `…${host.slice(-13)}` : host
}

function time(iso: string): string {
  return new Date(iso).toLocaleTimeString()
}

export default function App() {
  const [todos, setTodos] = useState<Todo[]>([])
  const [activity, setActivity] = useState<Activity[]>([])
  const [hits, setHits] = useState<Hit[]>([])
  const [title, setTitle] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [activityDown, setActivityDown] = useState(false)
  const [frontendVersion, setFrontendVersion] = useState<string>('…')

  useEffect(() => onResponse((hit) => setHits((prev) => [hit, ...prev].slice(0, MAX_HITS))), [])

  useEffect(() => {
    fetch('/config.json')
      .then((r) => r.json())
      .then((c: { version: string }) => setFrontendVersion(c.version))
      .catch(() => setFrontendVersion('unknown'))
  }, [])

  const refresh = useCallback(async () => {
    const [t, a] = await Promise.allSettled([api.listTodos(), api.listActivity()])
    if (t.status === 'fulfilled') setTodos(t.value)
    if (a.status === 'fulfilled') setActivity(a.value)
    // activity-service is optional (not started in the first showcases): show it in the feed, not as a page error.
    setActivityDown(a.status === 'rejected')
    setError(t.status === 'rejected' ? (t.reason as Error).message : null)
  }, [])

  useEffect(() => {
    void refresh()
    const id = setInterval(() => void refresh(), POLL_MS)
    return () => clearInterval(id)
  }, [refresh])

  async function run(action: () => Promise<unknown>) {
    try {
      await action()
      await refresh()
    } catch (e) {
      setError((e as Error).message)
    }
  }

  function add(e: FormEvent) {
    e.preventDefault()
    const value = title.trim()
    if (!value) return
    setTitle('')
    void run(() => api.createTodo(value))
  }

  const instances = useMemo(() => {
    const seen: Record<Service, Map<string, string | null>> = { todo: new Map(), activity: new Map() }
    for (const h of hits) if (h.host && !seen[h.service].has(h.host)) seen[h.service].set(h.host, h.version)
    return seen
  }, [hits])

  const open = todos.filter((t) => !t.done).length

  return (
    <div className="page">
      <header className="masthead">
        <h1>TODO system</h1>
        <p className="lede">
          A small distributed system for the lecture: a React UI, two Spring Boot services, Postgres and NATS.
        </p>
      </header>

      {error && (
        <div className="alert" role="alert">
          <strong>{error}</strong> The page retries every {POLL_MS / 1000} s. Check <code>docker compose ps</code> if
          it persists.
        </div>
      )}

      <main className="columns">
        <section className="tasks" aria-labelledby="tasks-h">
          <div className="section-head">
            <h2 id="tasks-h">Tasks</h2>
            <span className="count">{todos.length === 0 ? 'none yet' : `${open} open of ${todos.length}`}</span>
          </div>

          <form className="add" onSubmit={add}>
            <label htmlFor="title" className="sr-only">New task</label>
            <input
              id="title"
              value={title}
              maxLength={200}
              placeholder="What needs doing?"
              onChange={(e) => setTitle(e.target.value)}
            />
            <button type="submit" disabled={!title.trim()}>Add task</button>
          </form>

          {todos.length === 0 ? (
            <p className="empty">No tasks yet. Adding one publishes a <code>todo.created</code> event.</p>
          ) : (
            <ul className="todo-list">
              {todos.map((t) => (
                <li key={t.id} className={t.done ? 'done' : ''}>
                  <label>
                    <input type="checkbox" checked={t.done} onChange={() => void run(() => api.setDone(t.id, !t.done))} />
                    <span>{t.title}</span>
                  </label>
                  <button className="quiet" onClick={() => void run(() => api.deleteTodo(t.id))} aria-label={`Delete ${t.title}`}>
                    Delete
                  </button>
                </li>
              ))}
            </ul>
          )}
        </section>

        <section className="feed" aria-labelledby="feed-h">
          <div className="section-head">
            <h2 id="feed-h">Activity</h2>
            <span className="count">via NATS</span>
          </div>
          {activityDown ? (
            <p className="empty">activity-service is not reachable. Tasks still work; events are not recorded.</p>
          ) : activity.length === 0 ? (
            <p className="empty">Events show up here after a task changes.</p>
          ) : (
            <ol className="events">
              {activity.map((a) => (
                <li key={a.id}>
                  <span className={`evt evt-${a.type.split('.')[1] ?? 'other'}`}>{EVENT_LABELS[a.type] ?? a.type}</span>
                  <span className="evt-title">{a.title ?? '—'}</span>
                  <time dateTime={a.occurredAt}>{time(a.occurredAt)}</time>
                  <span className="via">
                    recorded by <code>{shortHost(a.receivedBy)}</code>
                  </span>
                </li>
              ))}
            </ol>
          )}
        </section>
      </main>

      <section className="responses" aria-labelledby="resp-h">
        <div className="section-head">
          <h2 id="resp-h">Who answered</h2>
          <span className="count">last {MAX_HITS} API responses, newest left</span>
        </div>
        <p className="hint">Tall bars: todo-service. Short bars: activity-service. Colour identifies the serving container; striped bars failed.</p>

        <ol className="hits">
          {hits.map((h) => (
            <li
              key={h.seq}
              className={`hit hit-${h.service}${h.status >= 200 && h.status < 400 ? '' : ' failed'}`}
              style={{ ['--hue' as string]: h.host ? hue(h.host) : 0 }}
              title={`${h.service}-service · ${h.host ?? 'no instance'} · HTTP ${h.status || 'network error'}`}
            />
          ))}
        </ol>

        <div className="instances">
          {(['todo', 'activity'] as Service[]).map((s) => (
            <div key={s}>
              <h3>{s}-service</h3>
              {instances[s].size === 0 ? (
                <p className="empty">No responses yet.</p>
              ) : (
                <ul>
                  {[...instances[s]].map(([host, version]) => (
                    <li key={host}>
                      <span className="swatch" style={{ ['--hue' as string]: hue(host) }} />
                      <code>{shortHost(host)}</code>
                      <span className="version">v{version ?? '?'}</span>
                    </li>
                  ))}
                </ul>
              )}
            </div>
          ))}
        </div>
      </section>

      <footer className="foot">
        Frontend v{frontendVersion}
      </footer>
    </div>
  )
}
