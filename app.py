from flask import Flask, request, jsonify, render_template
from flask_cors import CORS
import sqlite3
from datetime import datetime

app = Flask(__name__)
app.json.sort_keys = False
CORS(app) # Allow requests from frontend

# Database setup
def init_db():
    """Initialize SQLite database"""
    conn = sqlite3.connect('todos.db')
    cursor = conn.cursor()
    cursor.execute('''
                   CREATE TABLE IF NOT EXISTS todos (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        title TEXT NOT NULL,
                        description TEXT,
                        completed INTEGER DEFAULT 0,
                        created_time TEXT DEFAULT CURRENT_TIMESTAMP
                        )
                   ''')
    conn.commit()
    conn.close()

def get_db():
    """Get database connection"""
    conn = sqlite3.connect('todos.db')
    conn.row_factory = sqlite3.Row # Return rows as dictionaries
    return conn

# GET api/todos - Get all todos
@app.route('/api/todos', methods=['GET'])
def get_todos():
    try:
        conn = get_db()
        cursor = conn.cursor()
        cursor.execute('SELECT * FROM todos ORDER BY created_time ASC')
        todos = [dict(row) for row in cursor.fetchall()]
        conn.close()

        # Convert completed to boolean
        for todo in todos:
            todo['completed'] = bool(todo['completed'])
        
        return jsonify(todos), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

# GET api/todos/<id> - Get a specific todo
@app.route('/api/todos/<int:todo_id>', methods=['GET'])
def get_todo(todo_id):
    try:
        conn = get_db()
        cursor = conn.cursor()
        cursor.execute('SELECT * FROM todos WHERE id = ?', (todo_id,))
        todo = cursor.fetchone()
        conn.close()

        if todo:
            todo_dict = dict(todo)
            todo_dict['completed'] = bool(todo_dict['completed'])
            return jsonify(todo_dict), 200
        else:
            return jsonify({'error': 'toto not found'}), 404

    except Exception as e:
        return jsonify({'error:': str(e)}), 500

# POST api/todos - Create a new todo
@app.route('/api/todos', methods=['POST'])
def create_todo():
    try:
        data = request.get_json()
        title = data.get('title')
        description = data.get('description', '')

        if not title:
            return jsonify({'error': 'title is required'}), 400
        
        conn = get_db()
        cursor = conn.cursor()
        cursor.execute(
            'INSERT INTO todos (title, description, completed) VALUES (?, ?, 0)',
            (title, description)
        )
        conn.commit()
        new_id = cursor.lastrowid
        conn.close()

        return jsonify({
            'id': new_id,
            'title': title,
            'description': description,
            'completed': False,
            'message': 'todo created successfully'
        }), 201
    except Exception as e:
        return jsonify({'error': str(e)}), 500

# PUT /api/todos/<id> - Update a todo
@app.route('/api/todos/<int:todo_id>', methods=['PUT'])
def update_todo(todo_id):
    try:
        data = request.get_json()
        title = data.get('title')
        description = data.get('description')
        completed = data.get('completed')

        conn = get_db()
        cursor = conn.cursor()

        # Build dynamic update query
        updates = []
        params = []

        if title is not None:
            updates.append('title = ?')
            params.append(title)
        if description is not None:
            updates.append('description = ?')
            params.append(description)
        if completed is not None:
            updates.append('completed = ?')
            params.append(1 if completed else 0)
        
        if not updates:
            return jsonify({'error': 'no fields to update'}), 400
        
        params.append(todo_id)
        query = f"UPDATE todos SET {', '.join(updates)} WHERE id = ?"

        cursor.execute(query, params)
        conn.commit()

        if cursor.rowcount == 0:
            conn.close()
            return jsonify({'error': 'todo not found'}), 404
        
        conn.close()
        return jsonify({'message': 'todo updated successfully'}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

# DELETE /api/todos/<id> - Delete a todo
@app.route('/api/todos/<int:todo_id>', methods=['DELETE'])
def delete_todo(todo_id):
    try:
        conn = get_db()
        cursor = conn.cursor()
        cursor.execute('DELETE FROM todos WHERE id = ?', (todo_id,))
        conn.commit()

        if cursor.rowcount == 0:
            conn.close()
            return jsonify({'error': 'todo not found'}), 404
        
        conn.close()
        return jsonify({'message': 'todo deleted successfully'}), 200
    
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    
# Health check endpoint@app.route('/api/health')
def health():
    return jsonify({'status': 'ok'}), 200

# Serve the frontend
@app.route('/')
def index():
    return render_template('index.html')

if __name__ == '__main__':
    init_db()
    app.run(debug=True)