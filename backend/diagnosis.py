from .db_connection import get_connection

def get_diagnosis(user_id):
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM get_diagnosis(%s);", (user_id,))
    rows = cursor.fetchall()
    columns = [desc[0] for desc in cursor.description]
    results = [dict(zip(columns, row)) for row in rows]
    cursor.close()
    conn.close()
    return results
