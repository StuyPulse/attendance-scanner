#!/bin/bash

# Configuration
VALID_BARCODE_LENGTH=2
SERVER_ADDR=127.0.0.1:5000

# Log of all IDs
LOG=$(date +barcode-%m-%d-%Y.log)
# Log of pending IDs that failed to send
FAILED_LOG=$LOG.FAILED

# Verification credentials
ADMIN_EMAIL=""
ADMIN_PASS=""

# ANSI Escape Codes
RED="\033[1;31m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
MAGENTA="\033[1;35m"
RESET="\033[m"

# Counter for number of successful IDs
count=0

function login() {
    # Read login credentials and validate with server
    echo -n "Attendance Administrator Email: "
    read email
    ADMIN_EMAIL=$email
    echo -n "Attendance Administrator Password: "
    read -s pass
    echo ""
    ADMIN_PASS=$pass
    response=$(curl -s $SERVER_ADDR -d "email=${ADMIN_EMAIL}&pass=${ADMIN_PASS}")
    if [[ ${#response} == 0 ]]; then
        printf "${RED}ERROR: Could not contact server${RESET}\n"
        exit 1
    elif [[ $response =~ "SUCCESS" ]]; then
        printf "${GREEN}Validation successful${RESET}\n"
    else
        # Print out error message
        printf "${RED}${response}${RESET}\n"
        exit 1
    fi
}

function show_prompt() {
    echo "============================="
    # If there are pending IDs that failed to send, display a warning
    num_failed=$(get_num_failed)
    if [[ $num_failed != "" ]]; then
        printf "${YELLOW}(!) ${num_failed} IDs failed to send to server${RESET}\n"
    fi
    echo -n "[${count}] Swipe card: " 
}

function post_data() {
    # Send ID to server
    if [[ $# != 1 ]]; then
        return -1;
    fi
    response=$(curl -s $SERVER_ADDR -d "id=$1&email=${ADMIN_EMAIL}&pass=${ADMIN_PASS}")
    if [[ ${#response} == 0 ]]; then
        # Log any IDs that failed to send to the server
        printf "\n${RED}ERROR: Could not contact server${RESET}\n"
        echo $1 >> $FAILED_LOG
        show_prompt
    elif [[ $response =~ "ERROR" ]]; then
        printf "\n${RED}${response}${RESET}\n"
        show_prompt
    else
        # Increment count of the number of successful IDs
        let count=$count+1
        # The most recent connection was successful, so check if we have any
        # pending IDs that failed to send
        # Use a lock file to prevent this from being performed
        # concurrently
        if [[ ! -f $LOG.lock ]]; then
            num_failed=$(get_num_failed)
            if [[ $num_failed != "" ]]; then
                touch $LOG.lock
                printf "\n${MAGENTA}(!) I'm preparing to dump ${num_failed} pending IDs to the server!${RESET}\n"
                show_prompt
                # Iterate through each failed ID and try to send it to the
                # server
                while read line; do
                    response=$(curl -s $SERVER_ADDR -d "id=$line&email=${ADMIN_EMAIL}&pass=${ADMIN_PASS}")
                    # If still unsuccessful, append to a new log
                    if [[ ${#response} == 0 || $response =~ "ERROR" ]]; then
                        echo $line >> $FAILED_LOG.new
                    fi
                done < $FAILED_LOG
                # Update log of IDs that failed to send
                if [[ -f $FAILED_LOG.new ]]; then
                    mv $FAILED_LOG.new $FAILED_LOG
                else
                    rm $FAILED_LOG
                fi
                rm $LOG.lock
            fi
        fi
    fi
    return 0;
}

function get_num_failed() {
    # Print the number of pending IDs that failed to send
    if [[ -f $FAILED_LOG ]]; then
        echo "$(cat $FAILED_LOG | wc -l)"
    fi
}

function main() {
    login
    while [[ true ]]; do
        show_prompt
        read barcode
        if [[ ${#barcode} != $VALID_BARCODE_LENGTH ]]; then
            printf "${RED}ERROR: Invalid barcode${RESET}\n"   
        else
            printf "${GREEN}Got barcode: ${barcode}${RESET}\n"
            # Append barcode to log
            echo $barcode >> $LOG
            # Send data to server asynchronously
            post_data $barcode &
        fi
    done
}

main
