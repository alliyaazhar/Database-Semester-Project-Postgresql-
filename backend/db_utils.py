def add_patient_and_symptoms(conn, name, age, gender, symptom_ids):
    try:
        with conn.cursor() as cur:
            # Check if patient exists
            cur.execute("SELECT user_id FROM patients WHERE name = %s", (name,))
            result = cur.fetchone()

            if result:
                user_id = result[0]
            else:
                cur.execute(
                    "INSERT INTO patients (name, age, gender) VALUES (%s, %s, %s) RETURNING user_id",
                    (name, age, gender)
                )
                user_id = cur.fetchone()[0]

            for sid in symptom_ids:
                cur.execute(
                    "INSERT INTO user_symptom_inputs (user_id, symptom_id) VALUES (%s, %s)",
                    (user_id, sid)
                )

        conn.commit()
        return user_id

    except Exception as e:
        conn.rollback()
        raise e
def fetch_symptoms(conn):
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT symptom_id, symptom_name FROM symptoms ORDER BY symptom_name;")
            return cur.fetchall()  # Returns list of tuples like: [(1, 'Fever'), (2, 'Cough'), ...]
    except Exception as e:
        raise e
