from google.appengine.ext import ndb

class Student(ndb.Model):
    attendance_dates = ndb.DateProperty(repeated=True)
