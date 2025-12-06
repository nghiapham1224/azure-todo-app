import json
import logging
import os

import azure.functions as func
import pyodbc

app = func.FunctionApp(http_auth_level=func.AuthLevel.ANONYMOUS)


def get_db_connection():
    # Use the connection string from local.settings.json
    conn_str = os.environ["MSSQL_CONNECTION_STRING"]
    conn = pyodbc.connect(conn_str)
    return conn


def init_db():
    """Initialize SQL Server database table"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("""
            IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='todos' AND xtype='U')
            CREATE TABLE todos (
                id INT IDENTITY(1,1) PRIMARY KEY,
                title NVARCHAR(MAX) NOT NULL,
                description NVARCHAR(MAX),
                completed BIT DEFAULT 0,
                created_time DATETIME DEFAULT GETDATE()
            )
        """)
        conn.commit()
        conn.close()
    except Exception as e:
        logging.error(f"Failed to initialize DB: {str(e)}")


# Health check function
@app.route(route="health")
def health_check(req: func.HttpRequest) -> func.HttpResponse:
    logging.info("Health check triggered.")
    return func.HttpResponse("Azure Function is up and running.", status_code=200)


# GET all todos
@app.route(route="todos", methods=["GET"])
def get_todos(req: func.HttpRequest) -> func.HttpResponse:
    logging.info("Processing todos request.")
    init_db()  # Ensure table exists
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT * from todos ORDER by created_time ASC")

        # Convert rows to list of dicts
        col_header = [col[0] for col in cursor.description]
        todos = []
        for row in cursor.fetchall():
            todo_dict = dict(zip(col_header, row))
            todo_dict["completed"] = bool(
                todo_dict["completed"]
            )  # Convert BIT to boolean
            todos.append(todo_dict)

        conn.close()

        return func.HttpResponse(
            json.dumps(todos, default=str), status_code=200, mimetype="application/json"
        )
    except Exception as e:
        logging.error(f"Error in get_todos: {str(e)}")
        return func.HttpResponse(f"Error: {str(e)}", status_code=500)


# GET a specific todo by ID
@app.route(route="todos/{id}", methods=["GET"])
def get_todo_id(req: func.HttpRequest) -> func.HttpResponse:
    logging.info("Processing GET todo by ID.")
    init_db()
    try:
        todo_id = req.route_params.get("id")
        if not todo_id:
            return func.HttpResponse("Todo ID is required", status_code=400)

        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM todos WHERE id = ?", todo_id)

        todo_row = cursor.fetchone()

        conn.close()

        if not todo_row:
            return func.HttpResponse(f"Todo ID {todo_id} not found", status_code=404)

        col_header = [col[0] for col in cursor.description]
        todo_dict = dict(zip(col_header, todo_row))
        todo_dict["completed"] = bool(todo_dict["completed"])

        return func.HttpResponse(
            json.dumps(todo_dict, default=str),
            status_code=200,
            mimetype="application/json",
        )

    except Exception as e:
        logging.error(f"Error in get_todo_id: {str(e)}")
        return func.HttpResponse(f"Error: {str(e)}", status_code=500)


# POST a new todo
@app.route(route="todos", methods=["POST"])
def add_todo(req: func.HttpRequest) -> func.HttpResponse:
    logging.info("Processing todos request (POST).")
    init_db()
    try:
        req_body = req.get_json()
        title = req_body.get("title")
        description = req_body.get("description", "")

        if not title:
            return func.HttpResponse("Title is required", status_code=400)

        conn = get_db_connection()
        cursor = conn.cursor()

        query = """
            INSERT INTO todos (title, description, completed, created_time)
            OUTPUT INSERTED.id, INSERTED.title, INSERTED.description, INSERTED.completed, INSERTED.created_time
            VALUEs (?, ?, 0, GETDATE())
        """
        cursor.execute(query, (title, description))

        # Fetch the newly inserted row to return it
        new_todo_row = cursor.fetchone()
        if new_todo_row:
            new_todo = {
                column[0]: new_todo_row[i]
                for i, column in enumerate(cursor.description)
            }
            new_todo["completed"] = bool(new_todo["completed"])
        else:
            new_todo = None

        conn.commit()
        conn.close()

        return func.HttpResponse(
            json.dumps(new_todo, default=str),  # default=str handles datetime objects
            status_code=201,
            mimetype="application/json",
        )

    except Exception as e:
        logging.error(f"Error in add_todo: {str(e)}")
        return func.HttpResponse(f"Error: {str(e)}", status_code=500)


# PUT update a specific todo ID
@app.route(route="todos/{id}", methods=["PUT"])
def update_todo(req: func.HttpRequest) -> func.HttpResponse:
    logging.info("Processing todo update request (PUT).")
    init_db()
    try:
        todo_id = req.route_params.get("id")
        if not todo_id:
            return func.HttpResponse("Todo ID is required", status_code=400)
        try:
            req_body = req.get_json()
        except ValueError:
            return func.HttpResponse("Invalid JSON body", status_code=400)

        conn = get_db_connection()
        cursor = conn.cursor()

        # 1. Check if todo exists and get current values
        cursor.execute("SELECT * FROM todos where id = ?", todo_id)
        row = cursor.fetchone()

        if not row:
            conn.close()
            return func.HttpResponse(f"Todo ID {todo_id} not found", status_code=404)

        # Map existing DB row to a dictionary
        col_header = [col[0] for col in cursor.description]
        current_todo = dict(zip(col_header, row))

        # 2. Prepare updated values
        # Use the values from the request if provided, otherwise keep the existing DB values
        new_title = req_body.get("title", current_todo["title"])
        new_description = req_body.get("description", current_todo["description"])

        # Handle 'completed' since it's a boolean
        if "completed" in req_body:
            new_completed = bool(req_body["completed"])
        else:
            new_completed = bool(current_todo["completed"])

        # 3. Update in database
        query = """
            UPDATE todos
            SET title = ?, description = ?, completed = ?
            OUTPUT INSERTED.id, INSERTED.title, INSERTED.description, INSERTED.completed, INSERTED.created_time
            WHERE id = ?
        """
        cursor.execute(query, (new_title, new_description, new_completed, todo_id))

        updated_row = cursor.fetchone()
        conn.commit()
        conn.close()

        if updated_row:
            # Convert updated_row to a dictionary
            updated_todo = {
                col_header[0]: updated_row[i]
                for i, col_header in enumerate(cursor.description)
            }
            updated_todo["completed"] = bool(updated_todo["completed"])

            return func.HttpResponse(
                json.dumps(updated_todo, default=str),
                status_code=200,
                mimetype="application/json",
            )
        else:
            return func.HttpResponse(
                f"Error updating todo ID {todo_id}", status_code=500
            )

    except Exception as e:
        logging.error(f"Error in update_todo: {str(e)}")
        return func.HttpResponse(f"Error: {str(e)}", status_code=500)


# DELETE a specific todo ID
@app.route(route="todos/{id}", methods=["DELETE"])
def delete_todo(req: func.HttpRequest) -> func.HttpResponse:
    logging.info("Processing todo delete request (DELETE)")
    init_db()
    init_db()
    try:
        todo_id = req.route_params.get("id")
        if not todo_id:
            return func.HttpResponse("Todo ID is required", status_code=400)

        conn = get_db_connection()
        cursor = conn.cursor()

        # Check if the todo exists before attempting to delete
        cursor.execute("SELECT * FROM todos WHERE id = ?", todo_id)
        if not cursor.fetchone():
            conn.close()
            return func.HttpResponse(f"Todo ID {todo_id} not found", status_code=404)

        cursor.execute("DELETE FROM todos WHERE id = ?", todo_id)
        conn.commit()
        conn.close()

        return func.HttpResponse(
            f"Todo ID {todo_id} deleted successfully", status_code=200
        )

    except Exception as e:
        logging.error(f"Error in delete_todo: {str(e)}")
        return func.HttpResponse(f"Error: {str(e)}", status_code=500)
