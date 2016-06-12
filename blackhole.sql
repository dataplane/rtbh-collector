CREATE SEQUENCE blackhole_seq;
CREATE TABLE blackhole (
    row_id BIGINT DEFAULT nextval('blackhole_seq') UNIQUE NOT NULL PRIMARY KEY,
    data_source TEXT NOT NULL,
    route INET NOT NULL,
    origin BIGINT NOT NULL,
    stamp TIMESTAMP WITHOUT TIME ZONE DEFAULT date_trunc('seconds'::text, now()) NOT NULL
);
CREATE INDEX route_index ON blackhole (route);
