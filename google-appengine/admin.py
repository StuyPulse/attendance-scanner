from flask import Flask, request, redirect, url_for, render_template
from google.cloud import ndb
from werkzeug.security import generate_password_hash
from models import *
import google_auth
import google.oauth2.credentials
import googleapiclient.discovery
import os
import requests

app = Flask(__name__)
app.config['DEBUG'] = True

app.secret_key = os.environ.get("FN_FLASK_SECRET_KEY", default=False)

app.register_blueprint(google_auth.app)

@app.route("/admin/create_admin", methods=['GET', 'POST'])
def create_admin():
    if request.method == 'POST':
        client = ndb.Client()
        with client.context() as context:
            if request.form.get('email') and request.form.get('pass'):
                admin = Administrator(id=request.form['email'])
                admin.password = generate_password_hash(request.form['pass'])
                admin.put()
                return "SUCCESS: Administrator " + request.form['email'] + " was created successfully.\n"
            else:
                return "ERROR: Malformed request\n"
    else:
        info = google_auth.get_user_info()
        user_name = info['email']
        logout_url= "/admin/google/logout"
        return render_template('create_admin.html', user_name=user_name, logout_url=logout_url)

@app.route("/admin", methods=['GET', 'POST'])
def admin():
    if google_auth.is_logged_in():
        info = google_auth.get_user_info()
        return render_template('admin.html', user_name=info['given_name'], logout_url="/admin/google/logout")
    else:
        return redirect(url_for('google_auth.login'))

@app.route("/admin/settings", methods=['GET', 'POST'])
def admin_settings():
    info = google_auth.get_user_info()
    user_name = info['email']
    logout_url="/admin/google/logout"
    client = ndb.Client()
    with client.context() as context:
        config = ndb.Key(Settings, 'config').get()
        if not config:
            config = Settings(id='config')
        if request.method == 'POST':
            config.osis_url = request.form['osis-url']
            config.put()
    return render_template('settings.html', config=config, user_name=user_name, logout_url=logout_url)
