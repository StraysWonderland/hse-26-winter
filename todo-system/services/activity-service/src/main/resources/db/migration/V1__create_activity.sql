CREATE TABLE activity (
    id          bigint       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    event_id    varchar(64)  NOT NULL UNIQUE,   -- idempotency: redelivered events are ignored
    type        varchar(64)  NOT NULL,
    todo_id     uuid         NOT NULL,
    title       varchar(200),
    source      varchar(255) NOT NULL,
    occurred_at timestamptz  NOT NULL,
    received_by varchar(255) NOT NULL,
    received_at timestamptz  NOT NULL
);
