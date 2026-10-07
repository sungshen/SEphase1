-- Schema for PlanItem. The table starts empty;
-- the app inserts rows as the user creates plans.

DROP TABLE IF EXISTS plans;

CREATE TABLE plans (
    id          TEXT    PRIMARY KEY,
    task        TEXT    NOT NULL,
    date        TEXT    NOT NULL,
    start_time  INTEGER NOT NULL CHECK (start_time BETWEEN 0 AND 1439),
    end_time    INTEGER NOT NULL CHECK (end_time BETWEEN 0 AND 1440),
    priority    INTEGER NOT NULL,
    CHECK (end_time > start_time)
);

CREATE INDEX idx_plans_date ON plans (date);

