-- TABLES

CREATE TABLE patients (
    user_id SERIAL PRIMARY KEY,
    name TEXT,
    age INT,
    gender TEXT,
    email TEXT,
    last_activity TIMESTAMP
);

CREATE TABLE symptoms (
    symptom_id SERIAL PRIMARY KEY,
    symptom_name TEXT NOT NULL
);

CREATE TABLE diseases (
    disease_id SERIAL PRIMARY KEY,
    disease_name TEXT NOT NULL
);

CREATE TABLE user_symptom_inputs (
    input_id SERIAL PRIMARY KEY,
    user_id INT REFERENCES patients(user_id),
    symptom_id INT REFERENCES symptoms(symptom_id),
    input_date DATE DEFAULT CURRENT_DATE
);

CREATE TABLE disease_symptom (
    disease_id INT REFERENCES diseases(disease_id),
    symptom_id INT REFERENCES symptoms(symptom_id),
    PRIMARY KEY (disease_id, symptom_id)
);

CREATE TABLE precautions (
    disease_id INT PRIMARY KEY REFERENCES diseases(disease_id),
    precaution1 TEXT,
    precaution2 TEXT,
    precaution3 TEXT,
    precaution4 TEXT
);

-- INDEXES

CREATE INDEX idx_user_symptom ON user_symptom_inputs(user_id, symptom_id);
CREATE INDEX idx_disease_symptom ON disease_symptom(disease_id, symptom_id);

-- FUNCTION: Diagnosis Logic

CREATE OR REPLACE FUNCTION get_diagnosis(user_input_user_id INT)
RETURNS TABLE (
    disease_id INT,
    disease_name TEXT,
    match_percentage FLOAT,
    precaution1 TEXT,
    precaution2 TEXT,
    precaution3 TEXT,
    precaution4 TEXT
)
AS $$
BEGIN
    RETURN QUERY
    SELECT
        d.disease_id,
        d.disease_name,
        ROUND((
            100.0 * COUNT(DISTINCT ds.symptom_id)::FLOAT /
            NULLIF(
                (SELECT COUNT(*) FROM disease_symptom ds2 WHERE ds2.disease_id = d.disease_id),
                0
            )
        )::NUMERIC, 2)::FLOAT AS match_percentage,
        p.precaution1,
        p.precaution2,
        p.precaution3,
        p.precaution4
    FROM diseases d
    JOIN disease_symptom ds ON d.disease_id = ds.disease_id
    JOIN user_symptom_inputs ui ON ds.symptom_id = ui.symptom_id
    JOIN precautions p ON d.disease_id = p.disease_id
    WHERE ui.user_id = user_input_user_id
    GROUP BY d.disease_id, d.disease_name, p.precaution1, p.precaution2, p.precaution3, p.precaution4
    ORDER BY match_percentage DESC;
END;
$$ LANGUAGE plpgsql;


-- SAMPLE DATA

INSERT INTO symptoms (symptom_name) VALUES ('fever'), ('cough'), ('headache');
INSERT INTO diseases (disease_name) VALUES ('Flu'), ('COVID-19');

-- VIEWS

CREATE OR REPLACE VIEW vw_patient_info AS
SELECT user_id, name AS patient_name, age, gender FROM patients;

CREATE OR REPLACE VIEW vw_symptom_diseases AS
SELECT s.symptom_name, d.disease_name
FROM disease_symptom ds
JOIN symptoms s ON ds.symptom_id = s.symptom_id
JOIN diseases d ON ds.disease_id = d.disease_id;

CREATE OR REPLACE VIEW vw_user_symptoms AS
SELECT u.user_id, p.name AS patient_name, s.symptom_name, u.input_date
FROM user_symptom_inputs u
JOIN symptoms s ON u.symptom_id = s.symptom_id
JOIN patients p ON u.user_id = p.user_id;

CREATE OR REPLACE VIEW vw_disease_symptom_count AS
SELECT d.disease_name, COUNT(ds.symptom_id) AS symptom_count
FROM diseases d
JOIN disease_symptom ds ON d.disease_id = ds.disease_id
GROUP BY d.disease_name;

CREATE OR REPLACE VIEW vw_disease_precautions AS
SELECT d.disease_name, p.precaution1, p.precaution2, p.precaution3, p.precaution4
FROM diseases d
JOIN precautions p ON d.disease_id = p.disease_id;

-- MATERIALIZED VIEWS (keep these for analysis, not user input)

CREATE MATERIALIZED VIEW mv_patient_symptom_count AS
SELECT user_id, COUNT(symptom_id) AS total_symptoms
FROM user_symptom_inputs
GROUP BY user_id;

CREATE MATERIALIZED VIEW mv_disease_popularity AS
SELECT ds.disease_id, d.disease_name, COUNT(*) AS match_count
FROM user_symptom_inputs usi
JOIN disease_symptom ds ON usi.symptom_id = ds.symptom_id
JOIN diseases d ON ds.disease_id = d.disease_id
GROUP BY ds.disease_id, d.disease_name;

CREATE MATERIALIZED VIEW mv_gender_distribution AS
SELECT gender, COUNT(*) AS total_patients
FROM patients
GROUP BY gender;

CREATE MATERIALIZED VIEW mv_symptom_frequency AS
SELECT s.symptom_name, COUNT(*) AS times_selected
FROM user_symptom_inputs usi
JOIN symptoms s ON usi.symptom_id = s.symptom_id
GROUP BY s.symptom_name;

-- LOGGING TABLES

CREATE TABLE patient_logs (
    log_id SERIAL PRIMARY KEY,
    patient_id INT,
    action TEXT,
    log_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE symptom_input_logs (
    log_id SERIAL PRIMARY KEY,
    input_id INT,
    user_id INT,
    log_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- TRIGGERS & FUNCTIONS

-- Log patient insertion
CREATE OR REPLACE FUNCTION log_patient_insert()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO patient_logs(patient_id, action) VALUES (NEW.user_id, 'INSERT');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_log_patient_insert
AFTER INSERT ON patients
FOR EACH ROW EXECUTE FUNCTION log_patient_insert();

-- Log patient deletion
CREATE OR REPLACE FUNCTION log_patient_delete()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO patient_logs(patient_id, action) VALUES (OLD.user_id, 'DELETE');
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_log_patient_delete
AFTER DELETE ON patients
FOR EACH ROW EXECUTE FUNCTION log_patient_delete();

-- Log symptom input
CREATE OR REPLACE FUNCTION log_symptom_input()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO symptom_input_logs(input_id, user_id) VALUES (NEW.input_id, NEW.user_id);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_log_symptom_input
AFTER INSERT ON user_symptom_inputs
FOR EACH ROW EXECUTE FUNCTION log_symptom_input();

-- Prevent duplicate symptom entry per day
CREATE OR REPLACE FUNCTION prevent_duplicate_symptom()
RETURNS TRIGGER AS $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM user_symptom_inputs
        WHERE user_id = NEW.user_id AND symptom_id = NEW.symptom_id AND input_date = CURRENT_DATE
    ) THEN
        RAISE EXCEPTION 'Duplicate symptom input not allowed on the same day';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_prevent_duplicate_symptom
BEFORE INSERT ON user_symptom_inputs
FOR EACH ROW EXECUTE FUNCTION prevent_duplicate_symptom();

-- Update last activity on symptom input
CREATE OR REPLACE FUNCTION update_last_activity()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE patients SET last_activity = CURRENT_TIMESTAMP WHERE user_id = NEW.user_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_last_activity
AFTER INSERT ON user_symptom_inputs
FOR EACH ROW EXECUTE FUNCTION update_last_activity();

-- STORED PROCEDURES

CREATE OR REPLACE PROCEDURE add_new_patient(p_name TEXT, p_age INT, p_gender TEXT, p_email TEXT)
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO patients(name, age, gender, email)
    VALUES (p_name, p_age, p_gender, p_email);
END;
$$;

CREATE OR REPLACE PROCEDURE add_symptom_to_disease(p_disease_id INT, p_symptom_id INT)
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO disease_symptom(disease_id, symptom_id)
    VALUES (p_disease_id, p_symptom_id);
END;
$$;

CREATE OR REPLACE PROCEDURE clear_user_symptoms(p_user_id INT)
LANGUAGE plpgsql AS $$
BEGIN
    DELETE FROM user_symptom_inputs WHERE user_id = p_user_id;
END;
$$;

CREATE OR REPLACE PROCEDURE insert_user_symptom(p_user_id INT, p_symptom_id INT)
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO user_symptom_inputs(user_id, symptom_id)
    VALUES (p_user_id, p_symptom_id);
END;
$$;

CREATE OR REPLACE PROCEDURE delete_disease_by_name(p_disease_name TEXT)
LANGUAGE plpgsql AS $$
BEGIN
    DELETE FROM diseases WHERE disease_name = p_disease_name;
END;
$$;
