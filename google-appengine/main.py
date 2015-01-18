from flask import Flask, request, redirect, url_for, render_template
from werkzeug.security import generate_password_hash, check_password_hash
from google.appengine.ext import ndb
from models import Student, Administrator
import datetime

app = Flask(__name__)
app.config['DEBUG'] = True

# Note: We don't need to call run() since our application is embedded within
# the App Engine WSGI application server.

def validate(email, password):
    admin = ndb.Key(Administrator, email).get()
    if not admin:
        return False
    return check_password_hash(admin.password, password)

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

def notAlreadyScanned(student, now):
    return not presentOn(student, now.month, now.day, now.year)

def presentOn(student, month, day, year):
    for date in student.attendance_dates:
        if (date.day == day and date.month == month and date.year == year):
            return True
    return False

@app.route("/", methods=['GET', 'POST'])
def index():
    if request.method == 'POST':
        if request.form.has_key('email') and request.form.has_key('pass'):
            if not validate(request.form['email'], request.form['pass']):
                return "ERROR: Invalid credentials\n"
            else:
                if request.form.has_key('id'):
                    student = ndb.Key(Student, request.form['id']).get()
                    if not student:
                        student = Student(id=request.form['id'])
                    if notAlreadyScanned(student, datetime.datetime.now()):
                        student.attendance_dates += [datetime.datetime.now()]
                    student.put()
                    return "SUCCESS: Server received: " + request.form['id'] + "\n"
                else:
                    return "SUCCESS\n"
        else:
            return "ERROR: Malformed request\n"
    else:
        return redirect(url_for('webconsole'))

@app.route("/dump", methods=['POST'])
def dump():
    if request.form.has_key('email') and request.form.has_key('pass'):
        if not validate(request.form['email'], request.form['pass']):
            return "ERROR: Invalid credentials\n"
        else:
            students = Student.query()
            retStr = ""
            for student in students.iter():
                retStr += printStudent(student)
            return retStr
    else:
        return "ERROR: Malformed request\n"

@app.route("/day", methods=['POST'])
def day():
    if request.form.has_key('email') and request.form.has_key('pass')\
    and request.form.has_key('day') and request.form.has_key('month')\
    and request.form.has_key('year'):
        if not validate(request.form['email'], request.form['pass']):
            return "ERROR: Invalid credentials\n"
        else:
            students = Student.query()
            retStr = ""
            for student in students.iter():
                if presentOn(student, int(request.form['month']),\
                             int(request.form['day']), int(request.form['year'])):
                    retStr += "ID: " + student._key.id() + "\n"
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
            for student in students.iter():
                retStr += printStudent(student)
                student.key.delete()
            return retStr + "Deleted " + str(num) + " entries.\n"
    else:
        return "ERROR: Malformed request\n"

@app.route("/webconsole", methods=['GET', 'POST'])
def webconsole():
    if request.method == 'POST':
        if request.form.has_key('email') and request.form.has_key('pass'):
            if not validate(request.form['email'], request.form['pass']):
                return "Invalid login credentials"
            students = Student.query()
            retStr = "<table><th>ID</th><th>Dates</th>"
            for student in students.iter():
                retStr += "<tr>"
                retStr += "<td>" + student._key.id() + "</td>"
                retStr += "<td>" + printDatetimes(student.attendance_dates) + "</td>"
                retStr += "</tr>"
            return retStr + "</table"
        else:
            return render_template("login.html")
    else:
        return render_template("login.html")

@app.errorhandler(404)
def page_not_found(e):
    """Return a custom 404 error."""
    return 'Sorry, nothing at this URL.', 404

#@app.route("/create_admin", methods=['POST'])
#def create_admin():
#    if request.form.has_key('email') and request.form.has_key('pass'):
#        admin = Administrator(id=request.form['email'])
#        admin.password = generate_password_hash(request.form['pass'])
#        admin.put()
#        return "SUCCESS: Administrator " + request.form['email'] + " was created successfully.\n"
#    else:
#        return "ERROR: Malformed request\n"

