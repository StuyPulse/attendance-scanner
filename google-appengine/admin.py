from flask import Blueprint, request, redirect, url_for, render_template
from google.cloud import ndb
from werkzeug.security import generate_password_hash
from models import *
import google_auth
import google.oauth2.credentials
import googleapiclient.discovery
import os
import requests

app = Blueprint('admin', __name__)
app.secret_key = Settings.get("FN_FLASK_SECRET_KEY")

@app.route("/admin/create_admin", methods=['GET', 'POST'])
def create_admin():
    if google_auth.is_logged_in():
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
            user_name = info['given_name']
            logout_url= "/admin/google/logout"
            return render_template('create_admin.html', user_name=user_name, logout_url=logout_url)
    else:
        return redirect(url_for('google_auth.login'))

@app.route("/admin", methods=['GET', 'POST'])
def admin():
    if google_auth.is_logged_in():
        info = google_auth.get_user_info()
        return render_template('admin.html', user_name=info['given_name'], logout_url="/admin/google/logout")
    else:
        return redirect(url_for('google_auth.login'))

@app.route("/admin/settings", methods=['GET', 'POST'])
def admin_settings():
    if google_auth.is_logged_in():
        info = google_auth.get_user_info()
        user_name = info['given_name']
        logout_url="/admin/google/logout"
        client = ndb.Client()
        config = Settings.get('config')
        if request.method == 'POST':
            Settings.push('config', request.form['osis-url'])
            config = Settings.get('config')
        return render_template('settings.html', config=config, user_name=user_name, logout_url=logout_url)
    else:
        return redirect(url_for('google_auth.login'))
