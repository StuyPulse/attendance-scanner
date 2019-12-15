from google.cloud import ndb

import datetime

class Student(ndb.Model):
    attendance_dates = ndb.DateProperty(repeated=True)

    def scan(self, month, day, year):
        if not self.present_on(month, day, year):
            now = datetime.date(year, month, day)
            self.attendance_dates += [now]
            self.put()

    def present_on(self, month, day, year):
        for date in self.attendance_dates:
            if (date.day == day and date.month == month and date.year == year):
                return True
        return False

    def delete_date(self, month, day, year):
        date = datetime.date(year, month, day)
        if date in self.attendance_dates:
            self.attendance_dates.remove(date)
        self.put()

    def get_id(self):
        return self._key.id()

    def get_attendance(self):
        attendance = []
        for date in self.attendance_dates:
            attendance.append(date.strftime("%-m/%-d/%Y"))
        return attendance

    def get_month(self, month, year):
        attendance = []
        for date in self.attendance_dates:
            if (date.month == month and date.year == year):
                attendance.append(date)
        return attendance

class Administrator(ndb.Model):
    password = ndb.StringProperty()

class Settings(ndb.Model):
  name = ndb.StringProperty()
  value = ndb.StringProperty()

  @staticmethod
  def get(name):
    NOT_SET_VALUE = "NOT SET"
    with ndb.Client().context() as context:
        retval = Settings.query(Settings.name == name).get()
    if not retval:
      retval = Settings()
      retval.name = name
      retval.value = NOT_SET_VALUE
      retval.put()
    if retval.value == NOT_SET_VALUE:
      raise Exception(('Setting %s not found in the database. A placeholder ' +
        'record has been created. Go to the Developers Console for your app ' +
        'in App Engine, look up the Settings record with name=%s and enter ' +
        'its value in that record\'s value field.') % (name, name))
    return retval.value

  @staticmethod
  def push(name, value):
    client = ndb.Client()
    with client.context() as context:
        retval = Settings.query(Settings.name == name).get()
        if not retval:
            retval = Settings()
            retval.name = name
            retval.value = value
            retval.put()
        else:
            retval.value = value
            retval.put(retval.value)
        

