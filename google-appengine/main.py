from flask import Flask, request, redirect, url_for, render_template
from functools import wraps
from werkzeug.security import check_password_hash
from google.cloud import ndb
from models import Administrator, Student
import os

import students
import admin
import google_auth

app = Flask(__name__)
app.config['DEBUG'] = False

app.register_blueprint(admin.app)
app.register_blueprint(google_auth.app)

app.secret_key = admin.app.secret_key
# Note: We don't need to call run() since our application is embedded within
# the App Engine WSGI application server.

def authenticate(f):
    @wraps(f)
    def wrapper(*args, **kwargs):
        client = ndb.Client()
        if request.method == "POST":
            email = request.form["email"]
            password = request.form.get("pass") 
            with client.context() as context:
                admin = ndb.Key(Administrator, email).get()
            if not admin:
                return "ERROR: Invalid credentials\n"
            if not check_password_hash(admin.password, password):
                return "ERROR: Invalid credentials\n"
        return f(*args, **kwargs)
    return wrapper

@app.route("/", methods=['GET', 'POST'])
@authenticate
def index():
    if request.method == 'POST':
        if 'month' in request.form and\
            'day' in request.form and\
            'year' in request.form:

            # If ID is supplied, update attendance for ID
            if 'id' in request.form:
                id = request.form["id"]
                try:
                    int(id)
                except ValueError:
                    return "ERROR: ID must be a number\n"

                try:
                    day = int(request.form["day"])
                    month = int(request.form["month"])
                    year = int(request.form["year"])
                except ValueError:
                    return "ERROR: Invalid date\n"

                student = ndb.Key(Student, id).get()
                if not student:
                    student = Student(id=id)
                student.scan(month, day, year)

                return "SUCCESS: Server received: " + id + "\n"
            # Otherwise, acknowledge successful sign in
            else:
                return "SUCCESS\n"
        else:
            return "ERROR: Malformed request\n"
    else:
        return redirect(url_for('webconsole'))

@app.route("/dump", methods=['POST'])
@authenticate
def dump():
    return students.dump_data()

@app.route("/month", methods=['POST'])
@authenticate
def month():
    if 'month' in request.form and 'year' in request.form:
        try:
            month = int(request.form["month"])
            year = int(request.form["year"])
        except ValueError:
            return "ERROR: Invalid Date"
        return students.get_month(month, year)
    else:
        return "ERROR: Malformed request\n"

@app.route("/day", methods=['POST'])
@authenticate
def day():
    if 'day' in request.form and 'month' in request.form\
    and 'year' in request.form:
        try:
            day = int(request.form["day"])
            month = int(request.form["month"])
            year = int(request.form["year"])
        except ValueError:
            return "ERROR: Invalid date\n"

        return students.get_day(month, day, year)
    else:
        return "ERROR: Malformed request\n"

@app.route("/student", methods=['POST'])
@authenticate
def student():
    if 'id' in request.form:
        id = request.form["id"]
        try:
            int(id)
        except ValueError:
            return "ERROR: ID must be a number\n"

        student = ndb.Key(Student, id).get()
        if not student:
            return "ERROR: Student does not exist\n"
        return "\n".join(student.get_attendance())
    else:
        return "ERROR: Malformed request\n"

@app.route("/delete", methods=['POST'])
@authenticate
def delete():
    if 'month' in request.form and\
        'day' in request.form and\
        'year' in request.form and\
        'id' in request.form:
        id = request.form["id"]
        try:
            int(id)
        except ValueError:
            return "ERROR: ID must be a number\n"

        try:
            day = int(request.form["day"])
            month = int(request.form["month"])
            year = int(request.form["year"])
        except ValueError:
            return "ERROR: Invalid date\n"

        student = ndb.Key(Student, id).get()
        if student:
            student.delete_date(month, day, year)
        else:
            return "ERROR: Student does not exist\n"
        return "SUCCESS: Date deleted for %s" % id
    else:
        return "ERROR: Malformed request\n"

@app.route("/percent", methods=["POST"])
@authenticate
def percent():
    if "id" in request.form:
        id = request.form["id"]
        try:
            int(id)
        except ValueError:
            return "ERROR: ID must be a number\n"

        student = ndb.Key(Student, id).get()
        if student:
            return str(students.get_percentage(student))
        else:
            return "ERROR: Student does not exist\n"
    else:
        return "ERROR: Malformed request\n"


@app.route("/csv", methods=['POST'])
@authenticate
def csv_dump():
    month = request.form.get("month")
    dates = students.get_dates()
    if month:
        try:
            month = int(month)
        except ValueError:
            return "ERROR: Month must be a number\n"

        dates = [d for d in dates if d.month == month]
    return students.get_csv(dates)

@app.route("/dropdb", methods=['POST'])
@authenticate
def dropdb():
    return students.drop_database()

@app.route("/importcsv", methods=['GET', 'POST'])
@authenticate
def importcsv():
    osis_data = students.get_osis_data()
    student_csv = "osis, name\n"
    for osis in osis_data:
            student_csv += str(osis) + "," + osis_data[osis] + "\n"
    return student_csv

@app.route("/webconsole", methods=['GET', 'POST'])
@authenticate
def webconsole():
    client = ndb.Client()
    if request.method == 'POST':
        if request.form.get('action'):
            action = request.form['action']
            if action == 'dump':
                osis_data = students.get_osis_data()
                if "ERROR" in osis_data:
                    return osis_data
                s = Student.query()
                retStr = "<table><th>ID</th><th>Name</th><th>Dates</th>"
                with client.context() as context:
                    for student in s.iter():
                        retStr += "<tr>"
                        retStr += "<td>%s</td>" % student._key.id()
                        id = int(student.get_id())
                        if id in osis_data:
                            retStr += "<td>%s</td>" % osis_data[id]
                        else:
                            retStr += "<td></td>"
                        retStr += "<td>%s</td>" % student.get_attendance()
                        retStr += "</tr>"
                return retStr + "</table"
            elif action == 'csv':
                dates = students.get_dates()
                return students.get_csv(dates).replace('\n', '<br/>')
            elif action == 'day' and request.form['year'] == '':
                return "ERROR: Invalid Year"
            elif action == 'day':
                retStr = "Attendance for " + request.form['month'] + "/" +\
                            request.form['day'] + "/" + request.form['year'] + "<br/>"
                retStr += students.get_day(int(request.form['month']),\
                                    int(request.form['day']),\
                                    int(request.form['year'])).replace('\n', '<br/>')
                return retStr
            elif action == 'month' and request.form['year'] == '':
                return "ERROR: Invalid Year"
            elif action == 'month':
                dates = students.get_month(int(request.form['month']), int(request.form['year']))
                return students.get_csv(dates).replace('\n', '<br/>')
            elif action == 'student':
                id = request.form["student"]
                retStr = "Attendance for " + id + "<br/>"
                try:
                    int(id)
                except ValueError:
                    return "ERROR: ID must be a number\n"
                with client.context() as context:
                    student = ndb.Key(Student, id).get()
                if not student:
                    return "ERROR: Student does not exist.\n"
                retStr += "<br>".join(student.get_attendance())
                return retStr
        else:
            return "ERROR: Malformed request"
    else:
        return render_template("login.html")

@app.errorhandler(404)
def page_not_found(e):
    """Return a custom 404 error."""
    return 'Sorry, nothing at this URL.', 404
