import streamlit as st
import traceback
from backend.db_connection import get_connection
from backend.db_utils import add_patient_and_symptoms, fetch_symptoms

def main():
    st.title("Symptom Input")

    name = st.text_input("Name")
    age = st.number_input("Age", min_value=0, max_value=120, step=1)
    gender = st.selectbox("Gender", ["Male", "Female", "Other"])

    conn = None
    symptom_dict = {}

    try:
        conn = get_connection()
        symptoms = fetch_symptoms(conn)
        symptom_dict = {sid: sname for sid, sname in symptoms}
    except Exception as e:
        st.error("Failed to load symptoms from database.")
        st.text(traceback.format_exc())

    selected_symptoms = st.multiselect(
        "Select your symptoms",
        list(symptom_dict.values())
    )

    if st.button("Submit"):
        selected_ids = [sid for sid, sname in symptom_dict.items() if sname in selected_symptoms]

        if not name.strip():
            st.error("Please enter your name")
            return
        if not selected_ids:
            st.error("Please select at least one symptom")
            return

        try:
            if not conn:
                conn = get_connection()
            user_id = add_patient_and_symptoms(conn, name.strip(), age, gender, selected_ids)
            st.success(f"Symptoms recorded for user ID: {user_id}")
        except Exception as e:
            st.error(f"Failed to record symptoms: {e}")
            st.text(traceback.format_exc())
        finally:
            if conn:
                conn.close()

if __name__ == "__main__":
    main()
