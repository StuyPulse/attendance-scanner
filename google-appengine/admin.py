from flask import Flask, request, redirect, url_for, render_template

app = Flask(__name__)
app.config['DEBUG'] = True

@app.route("/admin/create_admin", methods=['GET', 'POST'])
def create_admin():
    if request.method == 'GET':
        return render_template('create_admin.html')

    elif request.method == 'POST':
        if request.form.has_key('email') and request.form.has_key('pass'):
            admin = Administrator(id=request.form['email'])
            admin.password = generate_password_hash(request.form['pass'])
            admin.put()
            return "SUCCESS: Administrator " + request.form['email'] + " was created successfully.\n"
        else:
            return "ERROR: Malformed request\n"
