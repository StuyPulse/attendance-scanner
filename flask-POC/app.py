#!/usr/bin/python
from flask import Flask, request

app = Flask(__name__)

@app.route("/", methods=['POST'])
def index():
    if request.form.has_key('email') and request.form.has_key('pass'):
        if not validate(request.form['email'], request.form['pass']):
            return "ERROR: Invalid credentials"
        else:
            if request.form.has_key('id'):
                return "SUCCESS: Server received: " + request.form['id']
            else:
                return "SUCCESS"
    else:
        return "ERROR: Malformed request"

def validate(email, password):
    return email == "bob@gmail.com" and password == "password"

if __name__ == "__main__":
    app.debug=True
    app.run()
