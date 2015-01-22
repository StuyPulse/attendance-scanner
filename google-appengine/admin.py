from flask import Flask, request, redirect, url_for, render_template
from google.appengine.api import users
from werkzeug.security import generate_password_hash
from models import Administrator

app = Flask(__name__)
app.config['DEBUG'] = True

@app.route("/admin/create_admin", methods=['GET', 'POST'])
def create_admin():
    if request.method == 'POST':
        if request.form.has_key('email') and request.form.has_key('pass'):
            admin = Administrator(id=request.form['email'])
            admin.password = generate_password_hash(request.form['pass'])
            admin.put()
            return "SUCCESS: Administrator " + request.form['email'] + " was created successfully.\n"
        else:
            return "ERROR: Malformed request\n"
    else:
        user_name = users.get_current_user().nickname()
        logout_url=users.create_logout_url('/')
        return render_template('create_admin.html', user_name=user_name, logout_url=logout_url)

@app.route("/admin", methods=['GET', 'POST'])
def admin():
    create_admin_url = url_for('create_admin')
    user_name = users.get_current_user().nickname()
    logout_url=users.create_logout_url('/')
    return render_template('admin.html', user_name=user_name, logout_url=logout_url, create_admin_url=create_admin_url)
