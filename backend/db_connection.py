import psycopg2

def get_connection():
    return psycopg2.connect(
        host="localhost",
        database="Disease_Detection_App",
        user="postgres",
        password="admin"
    )
