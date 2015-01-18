# Attendance ID Scanner

## Setting up a local development environment
#### Download and install the Google App Engine SDK
Select the SDK for Python
#### Running the development web server (default port 8080)
`dev_appserver.py google-appengine/`
#### Configure scanner.sh to use localhost:8080
`SERVER_ADDR=localhost:8080`
#### Create an administrator
1. Enable the `/create_admin` route in main.py by uncommenting it  
2. Run `curl localhost:8080/create_admin -d "email=bob@email.com&pass=password"` to create an admin with email "bob@email.com" and password "password"

#### Deploying to Google App Engine
1. Ensure that the `/create_admin` route is **DISABLED**
2. Run `appcfg.py update google-appengine/`
