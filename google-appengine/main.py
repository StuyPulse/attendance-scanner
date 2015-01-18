from flask import Flask, request
from google.appengine.ext import ndb
from models import Student
import datetime

app = Flask(__name__)
app.config['DEBUG'] = True

# Note: We don't need to call run() since our application is embedded within
# the App Engine WSGI application server.

def validate(email, password):
    return email == "bob@gmail.com" and password == "password"

def printStudent(student):
    return "ID: " + str(student._key) + "\nAttendances: " + str(student.attendance_dates) + "\n\n"

@app.route("/", methods=['POST'])
def index():
    if request.form.has_key('email') and request.form.has_key('pass'):
        if not validate(request.form['email'], request.form['pass']):
            return "ERROR: Invalid credentials\n"
        else:
            if request.form.has_key('id'):
                student = ndb.Key(Student, request.form['id']).get()
                if not student:
                    student = Student(id=request.form['id'])
                student.attendance_dates += [datetime.datetime.now()]
                student.put()
                return "SUCCESS: Server received: " + request.form['id'] + "\n"
            else:
                return "SUCCESS\n"
    else:
        return "ERROR: Malformed request\n"

@app.route("/dump", methods=['POST'])
def dump():
    if request.form.has_key('email') and request.form.has_key('pass'):
        if not validate(request.form['email'], request.form['pass']):
            return "ERROR: Invalid credentials\n"
        else:
            students = Student.query()
            retStr = ""
            for result in students.iter():
                retStr += printStudent(result)
            return retStr
    else:
        return "ERROR: Malformed request\n"

@app.route("/dropdb", methods=['POST'])
def dropdb():
    if request.form.has_key('email') and request.form.has_key('pass'):
        if not validate(request.form['email'], request.form['pass']):
            return "ERROR: Invalid credentials\n"
        else:
            students = Student.query()
            num = students.count()
            retStr = ""
            for result in students.iter():
                retStr += printStudent(result)
                result.key.delete()
            return retStr + "Deleted " + str(num) + " entries.\n"
    else:
        return "ERROR: Malformed request\n"

@app.errorhandler(404)
def page_not_found(e):
    """Return a custom 404 error."""
    return 'Sorry, nothing at this URL.', 404
