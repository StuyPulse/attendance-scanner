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

def printDatetimes(attendance_dates):
    retStr = "["
    numDates = len(attendance_dates)
    for i in range(numDates):
        date = attendance_dates[i]
        retStr += str(date.month) + "/" + str(date.day) + "/" + str(date.year)
        if i < numDates - 1:
            retStr += ", "
    return retStr + "]"

def printStudent(student):
    return "ID: " + student._key.id() + "\nAttendances: " + printDatetimes(student.attendance_dates) + "\n\n"

def notAlreadyScanned(now, attendance_dates):
    for date in attendance_dates:
        if (now.day == date.day and now.month == date.month and now.year == date.year):
            return False
    return True

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
                if notAlreadyScanned(datetime.datetime.now(), student.attendance_dates):
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
