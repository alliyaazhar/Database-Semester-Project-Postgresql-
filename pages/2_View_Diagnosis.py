import streamlit as st
from backend.db_connection import get_connection

def get_diagnosis(user_id):
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT * FROM get_diagnosis(%s);", (user_id,))
            results = cur.fetchall()
        return results
    finally:
        conn.close()

def main():
    st.title("View Diagnosis Results")

    user_id = st.number_input("Enter your User ID", min_value=1, step=1)

    if st.button("Get Diagnosis"):
        results = get_diagnosis(user_id)

        if not results:
            st.warning("No diagnosis found for this User ID.")
            return

        for disease_id, disease_name, match_percentage, p1, p2, p3, p4 in results:
            st.subheader(f"Disease: {disease_name} ({match_percentage}%)")
            st.write("Precautions:")
            precautions = [p for p in (p1, p2, p3, p4) if p]
            for p in precautions:
                st.write(f"- {p}")

if __name__ == "__main__":
    main()
