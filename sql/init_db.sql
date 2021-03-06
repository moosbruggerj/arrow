CREATE ROLE arrow;
ALTER ROLE arrow WITH LOGIN PASSWORD '14b8330c76fe611f9a62618f7dd37cd4';
ALTER DATABASE arrow OWNER TO arrow;
GRANT USAGE ON SCHEMA public TO arrow;
GRANT SELECT,INSERT,UPDATE ON ALL TABLES IN SCHEMA public TO arrow;

CREATE OR REPLACE FUNCTION update_trigger() RETURNS trigger AS $$
DECLARE
BEGIN
  PERFORM pg_notify('update', TG_TABLE_NAME || ',' || (select string_agg(id::text, ',' ORDER BY id) from new_table));
  RETURN new;
END;
$$ LANGUAGE plpgsql;
ALTER FUNCTION update_trigger() OWNER TO arrow;

CREATE TABLE bow (
	id SERIAL PRIMARY KEY,
	name CHARACTER VARYING(256) UNIQUE NOT NULL,
	max_draw_distance REAL NOT NULL,
	remainder_arrow_length REAL NOT NULL
);
ALTER TABLE bow OWNER TO arrow;
CREATE TRIGGER on_insert_bow AFTER INSERT ON bow REFERENCING NEW TABLE AS new_table EXECUTE PROCEDURE update_trigger();
CREATE TRIGGER on_update_bow AFTER UPDATE ON bow REFERENCING NEW TABLE AS new_table EXECUTE PROCEDURE update_trigger();

CREATE TABLE measure_series (
	id SERIAL PRIMARY KEY,
	name CHARACTER VARYING(256) UNIQUE NOT NULL,
	rest_position REAL NOT NULL,
	draw_distance REAL,
	draw_force REAL,
	time TIMESTAMPTZ NOT NULL,
	bow_id INTEGER NOT NULL REFERENCES bow(id) ON UPDATE CASCADE
	CONSTRAINT chk_end_condition CHECK (draw_distance IS NOT NULL OR draw_force IS NOT NULL)

);
ALTER TABLE measure_series OWNER TO arrow;
CREATE TRIGGER on_insert_measure_series AFTER INSERT ON measure_series REFERENCING NEW TABLE AS new_table EXECUTE PROCEDURE update_trigger();
CREATE TRIGGER on_update_measure_series AFTER UPDATE ON measure_series REFERENCING NEW TABLE AS new_table EXECUTE PROCEDURE update_trigger();

CREATE TABLE arrow (
	id SERIAL PRIMARY KEY,
	name CHARACTER VARYING(128),
	head_weight REAL,
	spline REAL,
	feather_length REAL,
	feather_type CHARACTER VARYING(128),
	length REAL NOT NULL,
	weight REAL NOT NULL,
	--measure_series_id INTEGER NOT NULL REFERENCES measure_series(id) ON UPDATE CASCADE,
	bow_id INTEGER NOT NULL REFERENCES bow(id) ON UPDATE CASCADE ON DELETE CASCADE
);
ALTER TABLE arrow OWNER TO arrow;
CREATE TRIGGER on_insert_arrow AFTER INSERT ON arrow REFERENCING NEW TABLE AS new_table EXECUTE PROCEDURE update_trigger();
CREATE TRIGGER on_update_arrow AFTER UPDATE ON arrow REFERENCING NEW TABLE AS new_table EXECUTE PROCEDURE update_trigger();

CREATE TABLE measure (
	id SERIAL PRIMARY KEY,
	measure_interval REAL NOT NULL,
	measure_series_id INTEGER NOT NULL REFERENCES measure_series(id) ON UPDATE CASCADE ON DELETE CASCADE,
	arrow_id INTEGER NOT NULL REFERENCES arrow(id) ON UPDATE CASCADE
);
ALTER TABLE measure OWNER TO arrow;
CREATE TRIGGER on_insert_measure AFTER INSERT ON measure REFERENCING NEW TABLE AS new_table EXECUTE PROCEDURE update_trigger();
CREATE TRIGGER on_update_measure AFTER UPDATE ON measure REFERENCING NEW TABLE AS new_table EXECUTE PROCEDURE update_trigger();

CREATE TABLE measure_point (
	id SERIAL PRIMARY KEY,
	time BIGINT NOT NULL,
	draw_distance DOUBLE PRECISION NOT NULL,
	force DOUBLE PRECISION NOT NULL,
	measure_id INTEGER NOT NULL REFERENCES measure(id) ON UPDATE CASCADE ON DELETE CASCADE
);
ALTER TABLE measure_point OWNER TO arrow;
CREATE TRIGGER on_insert_measure_point AFTER INSERT ON measure_point REFERENCING NEW TABLE AS new_table EXECUTE PROCEDURE update_trigger();
CREATE TRIGGER on_update_measure_point AFTER UPDATE ON measure_point REFERENCING NEW TABLE AS new_table EXECUTE PROCEDURE update_trigger();

