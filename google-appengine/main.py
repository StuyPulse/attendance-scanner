from flask import Flask, request, redirect, url_for, render_template
from functools import wraps
from werkzeug.security import check_password_hash
from google.appengine.ext import ndb
from models import Administrator, Student

import students

app = Flask(__name__)
app.config['DEBUG'] = False

# Note: We don't need to call run() since our application is embedded within
# the App Engine WSGI application server.

def authenticate(f):
    @wraps(f)
    def wrapper(*args, **kwargs):
        if request.method == "POST":
            email = request.form.get("email")
            password = request.form.get("pass")
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
        if request.form.has_key('month') and\
            request.form.has_key('day') and\
            request.form.has_key('year'):

            # If ID is supplied, update attendance for ID
            if request.form.has_key('id'):
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

@app.route("/day", methods=['POST'])
@authenticate
def day():
    if request.form.has_key('day') and request.form.has_key('month')\
    and request.form.has_key('year'):
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
    if request.form.has_key('id'):
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
    if request.form.has_key('month') and\
        request.form.has_key('day') and\
        request.form.has_key('year') and\
        request.form.has_key('id'):
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
    if request.form.has_key("id"):
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

        dates = filter(lambda d: d.month == month, dates)
    return students.get_csv(dates)

@app.route("/dropdb", methods=['POST'])
@authenticate
def dropdb():
    return students.drop_database()

@app.route("/webconsole", methods=['GET', 'POST'])
@authenticate
def webconsole():
    if request.method == 'POST':
        if request.form.has_key('student') and\
            request.form.has_key('month') and \
            request.form.has_key('day') and \
            request.form.has_key('year') and \
            request.form.has_key('action'):

            action = request.form['action']
            if action == 'dump':
                osis_data = students.get_osis_data()
                if "ERROR" in osis_data:
                    return osis_data
                s = Student.query()
                retStr = "<table><th>ID</th><th>Name</th><th>Dates</th>"
                for student in s.iter():
                    retStr += "<tr>"
                    retStr += "<td>%s</td>" % student._key.id()
                    id = int(student.get_id())
                    if id in osis_data:
                        retStr += "<td>%s</td>" % osis_data[id]['Name']
                    else:
                        retStr += "<td></td>"
                    retStr += "<td>%s</td>" % student.get_attendance()
                    retStr += "</tr>"
                return retStr + "</table"
            elif action == 'csv':
                dates = students.get_dates()
                return students.get_csv(dates).replace('\n', '<br/>')
            elif action == 'day':
                retStr = "Attendance for " + request.form['month'] + "/" +\
                            request.form['day'] + "/" + request.form['year'] + "<br/>"
                retStr += students.get_day(int(request.form['month']),\
                                    int(request.form['day']),\
                                    int(request.form['year'])).replace('\n', '<br/>')
                return retStr
            elif action == 'student':
                id = request.form["student"]
                retStr = "Attendance for " + id + "<br/>"
                try:
                    int(id)
                except ValueError:
                    return "ERROR: ID must be a number\n"

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
