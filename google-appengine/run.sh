export FN_AUTH_REDIRECT_URI=http://localhost:5000/admin/google/auth
export FN_BASE_URI=http://localhost:8040
export FN_CLIENT_ID= THE CLIENT ID
export FN_CLIENT_SECRET= THE CLIENT SECRET

# Change the following lines based on what you want to test
# export FLASK_APP=main.py
export FLASK_APP=admin.py

export FLASK_DEBUG=1
export FN_FLASK_SECRET_KEY=SOMETHING RANDOM AND SECRET

python -m flask run -p 5000
