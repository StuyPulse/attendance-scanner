# Attendance ID Scanner

## Setting up a local development environment
#### Download and install the Google App Engine SDK
Select the SDK for Python
#### Running the development web server (default port 8080)
`dev_appserver.py google-appengine/`
#### Configure scanner.sh to use localhost:8080
`SERVER_ADDR=localhost:8080`
#### Deploying to Google App Engine
`appcfg.py update google-appengine/`
