export type Todo = {
  id: string
  title: string
  done: boolean
  createdAt: string
  updatedAt: string
}

export type Activity = {
  id: number
  type: string
  todoId: string
  title: string | null
  source: string
  occurredAt: string
  receivedBy: string
  receivedAt: string
}

export type Service = 'todo' | 'activity'

/** One API response, with the instance that produced it (X-Served-By). */
export type Hit = {
  seq: number
  service: Service
  host: string | null
  version: string | null
  status: number
  at: number
}

export class ApiError extends Error {
  constructor(public service: Service, public status: number) {
    super(
      status === 0
        ? `${service}-service is unreachable.`
        : `${service}-service answered ${status}.`,
    )
  }
}

type Listener = (hit: Hit) => void
const listeners = new Set<Listener>()
let seq = 0

export function onResponse(listener: Listener): () => void {
  listeners.add(listener)
  return () => listeners.delete(listener)
}

function report(service: Service, res: Response | null) {
  const hit: Hit = {
    seq: ++seq,
    service,
    host: res?.headers.get('X-Served-By') ?? null,
    version: res?.headers.get('X-App-Version') ?? null,
    status: res?.status ?? 0,
    at: Date.now(),
  }
  listeners.forEach((l) => l(hit))
}

async function call<T>(service: Service, url: string, init?: RequestInit): Promise<T> {
  let res: Response
  try {
    res = await fetch(url, { ...init, headers: { 'Content-Type': 'application/json', ...init?.headers } })
  } catch {
    report(service, null)
    throw new ApiError(service, 0)
  }
  report(service, res)
  if (!res.ok) throw new ApiError(service, res.status)
  return (res.status === 204 ? undefined : await res.json()) as T
}

export const api = {
  listTodos: () => call<Todo[]>('todo', '/api/todos'),
  createTodo: (title: string) =>
    call<Todo>('todo', '/api/todos', { method: 'POST', body: JSON.stringify({ title }) }),
  setDone: (id: string, done: boolean) =>
    call<Todo>('todo', `/api/todos/${id}`, { method: 'PATCH', body: JSON.stringify({ done }) }),
  deleteTodo: (id: string) => call<void>('todo', `/api/todos/${id}`, { method: 'DELETE' }),
  listActivity: () => call<Activity[]>('activity', '/api/activity'),
}
