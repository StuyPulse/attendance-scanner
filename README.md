# Attendance ID Scanner

Run the scanner by executing `./scanner.sh`

An optional `--offline` flag can be passed to the scanner to run it without an Internet connection.

Alternatively, an experimental Python version of the scanner is available (`scanner.py`) with the same features.

## Setting up a local development environment
#### Installing the SDK
1) Download and install the [Google App Engine SDK for Python](https://cloud.google.com/appengine/docs/standard/python/download)
#### Install dependencies
1) Install python-pip with `sudo apt-get install python-pip`
2) Install all dependencies by running `mkdir google-appengine/libs; pip install -t google-appengine/libs -r google-appengine/requirements.txt`
#### Running the development web server
1) Run `dev_appserver.py google-appengine/`
2) Go to [localhost:8080](http://localhost:8080) in a browser
#### Configure the scanner
1) Open `scanner.sh` and change the line `SERVER_ADDR=https://stuypulse-attendance.appspot.com/` to `SERVER_ADDR=localhost:8080`
2) For the experimental Python version, change the contents of the `SERVER_ADDRESS` variable to `localhost:8080`
#### Create an administrator
Visit `localhost:8080/admin/create_admin` to create an administrator
#### Deploying to Google App Engine
Run `appcfg.py update google-appengine/`
