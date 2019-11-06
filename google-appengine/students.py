from google.cloud import ndb
from http.client import HTTPException
from models import Settings, Student
import requests

import csv
import logging
import re
import urllib.request, urllib.parse, urllib.error

def get_osis_data():
    config = ndb.Key(Settings, 'config').get()
    if not config:
        return "ERROR: You need to specify the CSV file of the Google Spreadsheet with OSIS"
    url = config.osis_url
    try:
        result = requests.get(url)
        decoded_content = result.content.decode('utf-8')
        csv_reader = csv.reader(decoded_content.splitlines(), delimiter=',')
        osis_meta = next(csv_reader) # Gets the first line in the OSIS Spreadsheet with headers
        col_last_name = osis_meta.index("Last Name")
        col_first_name = osis_meta.index("First Name")
        col_osis = osis_meta.index("OSIS")
        if col_osis == -1:
            col_osis = osis_meta.index("OSIS Number")
        osis_data = {}
        for row in csv_reader:
            student_id = ''.join(re.findall(r'\b\d+\b', row[col_osis]))
            if len(str(student_id)) != 9:
                continue
            name = "%s %s" % (row[col_first_name], row[col_last_name])
            osis_data[int(student_id)] = name
        return osis_data
    except urllib.error.URLError as e:
        logging.error(e)
        return "ERROR: URL for Google Spreadsheet with OSIS numbers is NOT VALID"
    except HTTPException as e:
        logging.error(e)
        return "ERROR: Could not fetch Google Spreadsheet with OSIS numbers"

def dump_data():
    osis_data = get_osis_data()
    if "ERROR" in osis_data:
        return osis_data
    students = Student.query()
    retStr = ""
    for student in students.iter():
        id = student.get_id()
        if id in osis_data:
            retStr += "Name: " + osis_data[id] + "\n"
        retStr += "ID: %s\n%s\n\n" % (student.get_id(), student.get_attendance())
    return retStr

def get_day(month, day, year):
    students = Student.query()
    retStr = ""
    for student in students.iter():
        if student.present_on(month, day, year):
            retStr += "ID: %s\n" % student.get_id()
    return retStr

def get_percentage(student):
    total = float(len(get_dates()))
    attended = float(len(student.attendance_dates))
    return (attended / total) * 100

def get_dates():
    students = Student.query()
    dates = []
    for student in students.iter():
        for date in student.attendance_dates:
            if date not in dates:
                dates.append(date)
    return dates

def get_csv(dates):
    osis_data = get_osis_data()
    if "ERROR" in osis_data:
        return osis_data
    students = Student.query()
    retStr = "ID,Name,"

    numDates = len(dates)
    # Add dates to csv
    dates = sorted(dates)
    for i in range(numDates):
        date = dates[i]
        retStr += date.strftime("%-m/%-d/%Y")
        if i < numDates - 1:
            retStr += ","
    retStr += "\n"
    for student in students.iter():
        id = int(student.get_id())
        retStr += "%s," % id
        if id in osis_data:
            retStr += osis_data[id] + ","
        else:
            retStr += ","
        for i in range(numDates):
            if dates[i] in student.attendance_dates:
                retStr += "X"
            if i < numDates - 1:
                retStr += ","
        retStr += "\n"
    return retStr

def drop_database():
    students = Student.query()
    num = students.count()
    for student in students.iter():
        student.key.delete()
    return "Deleted " + str(num) + " entries.\n"
