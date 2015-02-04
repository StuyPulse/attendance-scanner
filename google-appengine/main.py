from flask import Flask, request, redirect, url_for, render_template
from werkzeug.security import generate_password_hash, check_password_hash
from google.appengine.ext import ndb
from models import *
from httplib import HTTPException
import datetime, urllib2, logging, csv, re

app = Flask(__name__)
app.config['DEBUG'] = True

# Note: We don't need to call run() since our application is embedded within
# the App Engine WSGI application server.

def validate(email, password):
    if email == '' or password == '':
        return False
    admin = ndb.Key(Administrator, email).get()
    if not admin:
        return False
    return check_password_hash(admin.password, password)

def printDate(date):
    return str(date.month) + "/" + str(date.day) + "/" + str(date.year)

def printID(student):
    return "ID: " + student._key.id()

def printDatetimes(attendance_dates):
    retStr = "Attendances: ["
    numDates = len(attendance_dates)
    for i in range(numDates):
        date = attendance_dates[i]
        retStr += printDate(date)
        if i < numDates - 1:
            retStr += ", "
    return retStr + "]"

def printStudent(student):
    return printID(student) + "\n" + printDatetimes(student.attendance_dates) + "\n\n"

def notAlreadyScanned(student, now):
    return not presentOn(student, now.month, now.day, now.year)

def presentOn(student, month, day, year):
    for date in student.attendance_dates:
        if (date.day == day and date.month == month and date.year == year):
            return True
    return False

def getStudentsData():
    config = ndb.Key(Settings, 'config').get()
    if not config:
        return "ERROR: You need to specify the CSV file of the Google Spreadsheet with OSIS"
    url = config.osis_url
    try:
        result = urllib2.urlopen(url)
        csv_reader = csv.reader(result)
        osis_meta = csv_reader.next() # Gets the first line in the OSIS Spreadsheet with headers
        col_name = osis_meta.index("Name")
        col_id = osis_meta.index("ID")
        col_osis = osis_meta.index("OSIS")
        osis_data = {}
        for row in csv_reader:
            student_id = ''.join(re.findall(r'\b\d+\b', row[col_osis]))
            osis_data[int(student_id)] = {'Name': row[col_name], 'ID': row[col_id]}
        return osis_data
    except urllib2.URLError, e:
        logging.error(e)
        return "ERROR: URL for Google Spreadsheet with OSIS numbers is NOT VALID"
    except HTTPException, e:
        logging.error(e)
        return "ERROR: Could not fetch Google Spreadsheet with OSIS numbers"

def getDump():
    osis_data = getStudentsData()
    if "ERROR" in osis_data:
        return osis_data
    students = Student.query()
    retStr = ""
    for student in students.iter():
        if osis_data.has_key(int(student._key.id())):
            retStr += "Name: " + osis_data[int(student._key.id())]['Name'] + "\n"
        retStr += printStudent(student)
    return retStr

def getDay(month, day, year):
    students = Student.query()
    retStr = ""
    for student in students.iter():
        if presentOn(student, month, day, year):
            retStr += printID(student) + "\n"
    return retStr

def getStudent(id):
    if id == '':
        return "ERROR: Invalid ID.\n"
    student = ndb.Key(Student, id).get()
    if not student:
        return "ERROR: Student does not exist.\n"
    retStr = ""
    for date in student.attendance_dates:
        retStr += printDate(date) + "\n"
    return retStr

def getCSV():
    osis_data = getStudentsData()
    if "ERROR" in osis_data:
        return osis_data
    students = Student.query()
    retStr = "ID,Name,"
    dates = []
    # Get all valid attendance dates
    for student in students.iter():
        for date in student.attendance_dates:
            if date not in dates:
                dates.append(date)
    numDates = len(dates)
    # Add dates to csv
    dates = sorted(dates, key=lambda date: map(int, printDate(date).split('/')))
    for i in range(numDates):
        date = dates[i]
        retStr += printDate(date)
        if i < numDates - 1:
            retStr += ","
    retStr += "\n"
    for student in students.iter():
        retStr += student._key.id() + ","
        if osis_data.has_key(int(student._key.id())):
            retStr += osis_data[int(student._key.id())]['Name'] + ","
        else:
            retStr += ","
        for i in range(numDates):
            if dates[i] in student.attendance_dates:
                retStr += "Y"
            else:
                retStr += "N"
            if i < numDates - 1:
                retStr += ","
        retStr += "\n"
    return retStr

def getDropDatabase():
    students = Student.query()
    num = students.count()
    retStr = ""
    for student in students.iter():
        retStr += printStudent(student)
        student.key.delete()
    return retStr + "Deleted " + str(num) + " entries.\n"

@app.route("/", methods=['GET', 'POST'])
def index():
    if request.method == 'POST':
        if request.form.has_key('email') and\
           request.form.has_key('pass') and\
           request.form.has_key('month') and\
           request.form.has_key('day') and\
           request.form.has_key('year'):
            if not validate(request.form['email'], request.form['pass']):
                return "ERROR: Invalid credentials\n"
            else:
                if request.form.has_key('id'):
		    try:
			int(request.form['id'])
		    except ValueError:
			return "ERROR: ID must be a number\n"
                    student = ndb.Key(Student, request.form['id']).get()
                    if not student:
                        student = Student(id=request.form['id'])
                    now = datetime.date(int(request.form['year']),\
                                        int(request.form['month']),\
                                        int(request.form['day']))
                    if notAlreadyScanned(student, now):
                        student.attendance_dates += [now]
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
            return getDump()
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
            return getDay(int(request.form['month']), int(request.form['day']),\
                    int(request.form['year']))
    else:
        return "ERROR: Malformed request\n"

@app.route("/student", methods=['POST'])
def student():
    if request.form.has_key('email') and request.form.has_key('pass')\
    and request.form.has_key('id'):
        if not validate(request.form['email'], request.form['pass']):
            return "ERROR: Invalid credentials\n"
        else:
            return getStudent(request.form['id'])
    else:
        return "ERROR: Malformed request\n"

@app.route("/csv", methods=['POST'])
def csvDump():
    if request.form.has_key('email') and request.form.has_key('pass'):
        if not validate(request.form['email'], request.form['pass']):
            return "ERROR: Invalid credentials\n"
        else:
            return getCSV()
    else:
        return "ERROR: Malformed request\n"

@app.route("/dropdb", methods=['POST'])
def dropdb():
    if request.form.has_key('email') and request.form.has_key('pass'):
        if not validate(request.form['email'], request.form['pass']):
            return "ERROR: Invalid credentials\n"
        else:
            return getDropDatabase()
    else:
        return "ERROR: Malformed request\n"

@app.route("/webconsole", methods=['GET', 'POST'])
def webconsole():
    if request.method == 'POST':
        # DEBUG
        #retStr = ""
        #for field in request.form:
        #    retStr += str(field) + " : " + str(request.form[field]) + "<br>"
        #return retStr
        if request.form.has_key('email') and\
           request.form.has_key('pass') and\
           request.form.has_key('student') and\
           request.form.has_key('month') and \
           request.form.has_key('day') and \
           request.form.has_key('year') and \
           request.form.has_key('action'):
            if validate(request.form['email'], request.form['pass']):
                action = request.form['action']
                if action == 'dump':
                    osis_data = getStudentsData()
                    if "ERROR" in osis_data:
                        return osis_data
                    students = Student.query()
                    retStr = "<table><th>ID</th><th>Name</th><th>Dates</th>"
                    for student in students.iter():
                        retStr += "<tr>"
                        retStr += "<td>" + student._key.id() + "</td>"
                        if osis_data.has_key(int(student._key.id())):
                            retStr += "<td>" + osis_data[int(student._key.id())]['Name'] + "</td>"
                        else:
                            retStr += "<td></td>"
                        retStr += "<td>" + printDatetimes(student.attendance_dates) + "</td>"
                        retStr += "</tr>"
                    return retStr + "</table"
                elif action == 'csv':
                    return getCSV().replace('\n', '<br/>')
                elif action == 'day':
                    retStr = "Attendance for " + request.form['month'] + "/" +\
                                request.form['day'] + "/" + request.form['year'] + "<br/>"
                    retStr += getDay(int(request.form['month']),\
                                     int(request.form['day']),\
                                     int(request.form['year'])).replace('\n', '<br/>')
                    return retStr
                elif action == 'student':
                    retStr = "Attendance for " + request.form['student'] + "<br/>"
                    retStr += getStudent(request.form['student']).replace('\n', '<br/>')
                    return retStr
            else:
                return "Invalid login credentials"
        else:
            return "ERROR: Malformed request"
    else:
        return render_template("login.html")

@app.errorhandler(404)
def page_not_found(e):
    """Return a custom 404 error."""
    return 'Sorry, nothing at this URL.', 404
