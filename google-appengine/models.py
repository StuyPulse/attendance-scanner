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

class Administrator(ndb.Model):
    password = ndb.StringProperty()

class Settings(ndb.Expando):
    pass
