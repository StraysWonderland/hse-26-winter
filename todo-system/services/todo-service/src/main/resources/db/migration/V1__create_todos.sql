CREATE TABLE todos (
    id         uuid         PRIMARY KEY,
    title      varchar(200) NOT NULL,
    done       boolean      NOT NULL DEFAULT false,
    created_at timestamptz  NOT NULL,
    updated_at timestamptz  NOT NULL
);
