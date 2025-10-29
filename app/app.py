import os
import psycopg2
from flask import Flask, jsonify
from google.cloud import secretmanager

app = Flask(__name__)

# Configuration from environment variables
DB_HOST = os.getenv('DB_HOST')
DB_PORT = os.getenv('DB_PORT')
DB_NAME = os.getenv('DB_NAME')
DB_USER = os.getenv('DB_USER')
PROJECT_ID = os.getenv('GCP_PROJECT_ID')

# Get password from Secret Manager
def get_db_password():
    client = secretmanager.SecretManagerServiceClient()
    secret_path = f"projects/{PROJECT_ID}/secrets/dev-db-password/versions/latest"
    response = client.access_secret_version(request={"name": secret_path})
    return response.payload.data.decode('UTF-8')

DB_PASSWORD = get_db_password()


def get_db_connection():
    return psycopg2.connect(
        host=DB_HOST,
        port=DB_PORT,
        database=DB_NAME,
        user=DB_USER,
        password=DB_PASSWORD
    )

def init_database():
    conn = get_db_connection()
    cur = conn.cursor()

    # Create table
    cur.execute("""
        CREATE TABLE IF NOT EXISTS greetings (
            id SERIAL PRIMARY KEY,
            message TEXT NOT NULL,
            language TEXT NOT NULL
        )
    """)

    # Add sample data if empty
    cur.execute("SELECT COUNT(*) FROM greetings")
    if cur.fetchone()[0] == 0:
        greetings = [
            ("Hello, World!", "English"),
            ("Bonjour, le monde!", "French"),
            ("Hola, Mundo!", "Spanish"),
            ("Hallo, Welt!", "German"),
            ("Ciao, Mondo!", "Italian")
        ]
        cur.executemany("INSERT INTO greetings (message, language) VALUES (%s, %s)", greetings)
        conn.commit()

    cur.close()
    conn.close()


@app.route('/')
def home():
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("SELECT message, language FROM greetings ORDER BY RANDOM() LIMIT 1")
    row = cur.fetchone()
    cur.close()
    conn.close()

    return f"""
    <html>
    <head><title>Hello World</title></head>
    <body style="font-family: Arial; text-align: center; padding: 50px;">
        <h1>{row[0]}</h1>
        <p>Language: {row[1]}</p>
        <p>Database: PostgreSQL on GCP</p>
    </body>
    </html>
    """

@app.route('/api')
def api():
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("SELECT message, language FROM greetings ORDER BY RANDOM() LIMIT 1")
    row = cur.fetchone()
    cur.close()
    conn.close()

    return jsonify({
        "message": row[0],
        "language": row[1],
        "database": "PostgreSQL"
    })


@app.route('/health')
def health():
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute("SELECT 1")
        cur.close()
        conn.close()
        return "ok", 200
    except Exception as e:
        return f"unhealthy: {str(e)}", 503

# Initialize database on startup
init_database()

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
