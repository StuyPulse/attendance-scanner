# Attendance ID Scanner

Run the scanner by executing `./scanner.sh`

An optional `--offline` flag can be passed to the scanner to run it without an Internet connection.

Alternatively, an experimental Python version of the scanner is available (`scanner.py`) with the same features. Please note that there's a bug that causes the program to crash if the terminal window is resized.

## Setting up a local development environment
#### Download and install the Google App Engine SDK
Select the SDK for Python
#### Install dependencies
Install the dependencies listed in `google-appengine/requirements.txt`
#### Running the development web server (default port 8080)
`dev_appserver.py google-appengine/`
#### Configure scanner.sh to use localhost:8080
`SERVER_ADDR=localhost:8080`
#### Create an administrator
Visit `localhost:8080/admin/create_admin` to create an administrator
#### Deploying to Google App Engine
Run `appcfg.py update google-appengine/`
