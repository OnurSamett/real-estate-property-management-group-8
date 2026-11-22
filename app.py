import os
from functools import wraps

import bcrypt
import psycopg2
from psycopg2 import errors
from psycopg2.extras import RealDictCursor
from flask import Flask, render_template, request, redirect, url_for, session, flash

app = Flask(__name__)
app.secret_key = os.environ.get('SECRET_KEY', 'cmpe341_fallback_secret_key')

DB_HOST = os.environ.get('DB_HOST', 'localhost')
DB_PORT = os.environ.get('DB_PORT', '5432')
DB_NAME = os.environ.get('DB_NAME', 'realestate_db')
DB_USER = os.environ.get('DB_USER', 'postgres')
DB_PASS = os.environ.get('DB_PASSWORD', 'adminpassword123')

PROPERTY_TYPES = ['Apartment', 'Villa', 'Office', 'Commercial']
STATUSES = ['Available', 'Rented', 'Sold']


def get_db():
    return psycopg2.connect(
        host=DB_HOST,
        port=DB_PORT,
        dbname=DB_NAME,
        user=DB_USER,
        password=DB_PASS,
        cursor_factory=RealDictCursor,
    )


def login_required(view):
    @wraps(view)
    def wrapped(*args, **kwargs):
        if 'user_id' not in session:
            return redirect(url_for('login'))
        return view(*args, **kwargs)
    return wrapped


def read_property_form():
    """Read the property form; empty amounts become 0 (columns are NOT NULL DEFAULT 0)."""
    f = request.form
    return (
        f['status'],
        f['address'].strip(),
        f['city'].strip(),
        f['postal_code'].strip(),
        f['property_type'],
        f.get('rent_amount') or 0,
        f.get('sale_amount') or 0,
        f['agent_id'],
        f['o_id'],
    )


def load_people(cur):
    cur.execute("SELECT O_id, Fname || ' ' || L_name AS Name FROM Owner ORDER BY O_id;")
    owners = cur.fetchall()
    cur.execute("SELECT Agent_id, Fname || ' ' || L_name AS Name FROM Agent ORDER BY Agent_id;")
    agents = cur.fetchall()
    return owners, agents


def render_form(action, prop, form=None):
    with get_db() as conn, conn.cursor() as cur:
        owners, agents = load_people(cur)
    conn.close()
    return render_template('property_form.html', action=action, property=prop, form=form,
                           owners=owners, agents=agents,
                           property_types=PROPERTY_TYPES, statuses=STATUSES)


@app.route('/')
def index():
    if 'user_id' in session:
        return redirect(url_for('dashboard'))
    return redirect(url_for('login'))


@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        username = request.form['username']
        password = request.form['password']

        conn = get_db()
        with conn.cursor() as cur:
            cur.execute("SELECT * FROM Users WHERE username = %s;", (username,))
            user = cur.fetchone()
        conn.close()

        if user and bcrypt.checkpw(password.encode('utf-8'), user['password_hash'].encode('utf-8')):
            session['user_id'] = user['user_id']
            session['username'] = user['username']
            session['role'] = user['role']
            flash('Login successful!', 'success')
            return redirect(url_for('dashboard'))
        flash('Invalid username or password.', 'danger')

    return render_template('login.html')


@app.route('/logout')
def logout():
    session.clear()
    flash('Logged out successfully.', 'info')
    return redirect(url_for('login'))


@app.route('/dashboard')
@login_required
def dashboard():
    conn = get_db()
    with conn.cursor() as cur:
        cur.execute("""
            SELECT p.Property_id, p.Status, p.Property_address, p.City, p.Postal_code,
                   p.Property_type, p.Rent_amount, p.Sale_amount,
                   o.Fname || ' ' || o.L_name AS Owner_Name,
                   a.Fname || ' ' || a.L_name AS Agent_Name
            FROM Property p
            JOIN Owner o ON p.O_id = o.O_id
            JOIN Agent a ON p.Agent_id = a.Agent_id
            ORDER BY p.Property_id ASC;
        """)
        properties = cur.fetchall()
    conn.close()
    return render_template('dashboard.html', properties=properties)


@app.route('/property/add', methods=['GET', 'POST'])
@login_required
def add_property():
    if request.method == 'POST':
        values = read_property_form()
        conn = get_db()
        try:
            with conn, conn.cursor() as cur:
                cur.execute("""
                    INSERT INTO Property (Status, Property_address, City, Postal_code, Property_type,
                                          Rent_amount, Sale_amount, Agent_id, O_id)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
                    RETURNING Property_id;
                """, values)
                new_id = cur.fetchone()['property_id']
        except psycopg2.Error as e:
            flash(f'Property could not be added: {e.diag.message_primary}', 'danger')
            return render_form('Add', None, request.form)
        finally:
            conn.close()
        flash(f'Property #{new_id} added successfully!', 'success')
        return redirect(url_for('dashboard'))

    return render_form('Add', None)


@app.route('/property/edit/<int:id>', methods=['GET', 'POST'])
@login_required
def edit_property(id):
    conn = get_db()
    with conn.cursor() as cur:
        cur.execute("SELECT * FROM Property WHERE Property_id = %s;", (id,))
        prop = cur.fetchone()
    if prop is None:
        conn.close()
        flash(f'Property #{id} does not exist.', 'warning')
        return redirect(url_for('dashboard'))

    if request.method == 'POST':
        values = read_property_form()
        try:
            with conn, conn.cursor() as cur:
                cur.execute("""
                    UPDATE Property
                    SET Status = %s, Property_address = %s, City = %s, Postal_code = %s,
                        Property_type = %s, Rent_amount = %s, Sale_amount = %s,
                        Agent_id = %s, O_id = %s
                    WHERE Property_id = %s;
                """, values + (id,))
        except psycopg2.Error as e:
            flash(f'Property could not be updated: {e.diag.message_primary}', 'danger')
            return render_form('Edit', prop, request.form)
        finally:
            conn.close()
        flash(f'Property #{id} updated successfully!', 'success')
        return redirect(url_for('dashboard'))

    conn.close()
    return render_form('Edit', prop)


@app.route('/property/delete/<int:id>', methods=['POST'])
@login_required
def delete_property(id):
    if session.get('role') != 'admin':
        flash('Permission denied. Only admins can delete properties.', 'danger')
        return redirect(url_for('dashboard'))

    conn = get_db()
    try:
        with conn, conn.cursor() as cur:
            cur.execute("DELETE FROM Property WHERE Property_id = %s;", (id,))
            deleted = cur.rowcount
    except (errors.RestrictViolation, errors.ForeignKeyViolation):
        flash(f'Property #{id} cannot be deleted because it has lease/sale agreements '
              '(ON DELETE RESTRICT).', 'danger')
        return redirect(url_for('dashboard'))
    finally:
        conn.close()

    if deleted:
        flash(f'Property #{id} deleted successfully!', 'success')
    else:
        flash(f'Property #{id} does not exist.', 'warning')
    return redirect(url_for('dashboard'))


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=os.environ.get('FLASK_DEBUG') == '1')
