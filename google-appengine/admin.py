from flask import Flask, request, redirect, url_for, render_template
from google.appengine.api import users
from google.appengine.ext import ndb
from werkzeug.security import generate_password_hash
from models import *

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
    user_name = users.get_current_user().nickname()
    logout_url=users.create_logout_url('/')
    return render_template('admin.html', user_name=user_name, logout_url=logout_url)

@app.route("/admin/settings", methods=['GET', 'POST'])
def admin_settings():
    user_name = users.get_current_user().nickname()
    logout_url=users.create_logout_url('/')
    config = ndb.Key(Settings, 'config').get()
    if not config:
        config = Settings(id='config')
    if request.method == 'POST':
        config.osis_url = request.form['osis-url']
        config.put()
    return render_template('settings.html', config=config, user_name=user_name, logout_url=logout_url)
