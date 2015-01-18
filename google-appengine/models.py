from google.appengine.ext import ndb

class Student(ndb.Model):
    attendance_dates = ndb.DateProperty(repeated=True)

class Administrator(ndb.Model):
    password = ndb.StringProperty()
