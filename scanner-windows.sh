#!/bin/bash

#WARNING: THIS IS NO LONGER SUPPORTED

# Configuration
VALID_BARCODE_LENGTH=9
SERVER_ADDR=https://stuypulse-attendance.appspot.com/
SHOW_SERVER_RESPONSE_IF_SUCCESS=false
SAVE_DUMP_OUTPUT=true
OUTPUT_FILE=OUT
OFFLINE=false

# Current time
MONTH=$(date +%m)
DAY=$(date +%d)
YEAR=$(date +%Y)
MONTH_OVERRIDE=""
DAY_OVERRIDE=""
YEAR_OVERRIDE=""
# Log of all IDs
LOG=barcode-${MONTH}-${DAY}-${YEAR}.log
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

function login() {
    # Read login credentials and validate with server
    if [[ $ADMIN_EMAIL == "" ]]; then
        echo -n "Attendance Administrator Email: "
        read email
        ADMIN_EMAIL=$email
    fi
    echo -n "Attendance Administrator Password: "
    read -s pass
    echo ""
    response=$(curl -s $SERVER_ADDR -d "email=${ADMIN_EMAIL}&pass=${pass}&month=${MONTH}&day=${DAY}&year=${YEAR}")
    if [[ ${#response} == 0 ]]; then
        printf "${RED}ERROR: Could not contact server${RESET}\n"
    elif echo $response | grep -E "SUCCESS" > /dev/null; then
        printf "${GREEN}Validation successful${RESET}\n"
        ADMIN_PASS=$pass
    else
        # Print out error message
        printf "${RED}${response}${RESET}\n"
    fi
}

function show_prompt() {
    echo "============================="
    # If there are pending IDs that failed to send, display a warning
    num_failed=$(get_num_failed)
    if [[ $num_failed != "" ]]; then
        printf "${YELLOW}(!) ${num_failed} IDs failed to send to server${RESET}\n"
    fi
    echo -n "Swipe card: "
}

function post_data() {
    # Send ID to server
    if [[ $# != 1 ]]; then
        return -1;
    fi
    # If we're in offline mode, then append the IDs to the log of pending IDs
    if $OFFLINE; then
        echo $1 >> $FAILED_LOG
        exit 0
    fi
    if [[ $YEAR_OVERRIDE != "" ]]; then
        YEAR=$YEAR_OVERRIDE
    fi
    if [[ $MONTH_OVERRIDE != "" ]]; then
        MONTH=$MONTH_OVERRIDE
    fi
    if [[ $DAY_OVERRIDE != "" ]]; then
        DAY=$DAY_OVERRIDE
    fi
    response=$(curl -s $SERVER_ADDR -d "id=$1&email=${ADMIN_EMAIL}&pass=${ADMIN_PASS}&month=${MONTH}&day=${DAY}&year=${YEAR}")
    if [[ ${#response} == 0 ]]; then
        # Log any IDs that failed to send to the server
        printf "\n${RED}ERROR: Could not contact server${RESET}\n"
        echo $1 >> $FAILED_LOG
        show_prompt
    elif echo $response | grep -E "ERROR" > /dev/null; then
        printf "\n${RED}${response}${RESET}\n"
        show_prompt
    else
        if $SHOW_SERVER_RESPONSE_IF_SUCCESS; then
            printf "\n${GREEN}${response}${RESET}\n"
            show_prompt
        fi
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
                    response=$(curl -s $SERVER_ADDR -d "id=$line&email=${ADMIN_EMAIL}&pass=${ADMIN_PASS}&month=${MONTH}&day=${DAY}&year=${YEAR}")
                    # If still unsuccessful, append to a new log
                    if [[ ${#response} == 0 || $(echo $response | grep -E "ERROR" > dev/null) ]]; then
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

function dump_data() {
    if $SAVE_DUMP_OUTPUT; then
        curl $SERVER_ADDR/dump -d "email=${ADMIN_EMAIL}&pass=${ADMIN_PASS}" > $OUTPUT_FILE
        printf "${GREEN}Output saved to file '${OUTPUT_FILE}'${RESET}\n"
    else
        curl $SERVER_ADDR/dump -d "email=${ADMIN_EMAIL}&pass=${ADMIN_PASS}"
    fi
}

function dump_day() {
    if $SAVE_DUMP_OUTPUT; then
        curl $SERVER_ADDR/day -d "email=${ADMIN_EMAIL}&pass=${ADMIN_PASS}&month=$1&day=$2&year=$3" > $OUTPUT_FILE
        printf "${GREEN}Output saved to file '${OUTPUT_FILE}'${RESET}\n"
    else
        curl $SERVER_ADDR/day -d "email=${ADMIN_EMAIL}&pass=${ADMIN_PASS}&month=$1&day=$2&year=$3"
    fi
}

function dump_today() {
    month=$(date +%m)
    day=$(date +%d)
    year=$(date +%Y)
    if $SAVE_DUMP_OUTPUT; then
        curl $SERVER_ADDR/day -d "email=${ADMIN_EMAIL}&pass=${ADMIN_PASS}&month=${month}&day=${day}&year=${year}" > $OUTPUT_FILE
        printf "${GREEN}Output saved to file '${OUTPUT_FILE}'${RESET}\n"
    else
        curl $SERVER_ADDR/day -d "email=${ADMIN_EMAIL}&pass=${ADMIN_PASS}&month=${month}&day=${day}&year=${year}"
    fi
}

function dump_student() {
    if $SAVE_DUMP_OUTPUT; then
        curl $SERVER_ADDR/student -d "email=${ADMIN_EMAIL}&pass=${ADMIN_PASS}&id=$1" > $OUTPUT_FILE
        printf "${GREEN}Output saved to file '${OUTPUT_FILE}'${RESET}\n"
    else
        curl $SERVER_ADDR/student -d "email=${ADMIN_EMAIL}&pass=${ADMIN_PASS}&id=$1"
    fi
}

function delete_date_for_student() {
    if $SAVE_DUMP_OUTPUT; then
        curl $SERVER_ADDR/delete -d "email=${ADMIN_EMAIL}&pass=${ADMIN_PASS}&month=$1&day=$2&year=$3&id=$4" > $OUTPUT_FILE
        printf "${GREEN}Output saved to file '${OUTPUT_FILE}'${RESET}\n"
    else
        curl $SERVER_ADDR/delete -d "email=${ADMIN_EMAIL}&pass=${ADMIN_PASS}&month=$1&day=$2&year=$3&id=$4"
    fi
}

function dump_csv() {
    if $SAVE_DUMP_OUTPUT; then
        curl $SERVER_ADDR/csv -d "email=${ADMIN_EMAIL}&pass=${ADMIN_PASS}" > $OUTPUT_FILE.csv
        printf "${GREEN}Output saved to file '${OUTPUT_FILE}.csv'${RESET}\n"
    else
        curl $SERVER_ADDR/day -d "email=${ADMIN_EMAIL}&pass=${ADMIN_PASS}"
    fi
}

function drop_data() {
    if $SAVE_DUMP_OUTPUT; then
        curl $SERVER_ADDR/dropdb -d "email=${ADMIN_EMAIL}&pass=${ADMIN_PASS}" > $OUTPUT_FILE
        printf "${GREEN}Output saved to file '${OUTPUT_FILE}'${RESET}\n"
    else
        curl $SERVER_ADDR/dropdb -d "email=${ADMIN_EMAIL}&pass=${ADMIN_PASS}"
    fi
}

function main() {
    while [[ true ]]; do
        show_prompt
        read barcode
        if [[ ${#barcode} != $VALID_BARCODE_LENGTH ]]; then
            printf "${RED}ERROR: Invalid barcode${RESET}\n"   
	elif echo $barcode | grep "[^0-9]\+" > /dev/null; then
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

function help() {
    echo -e "Usage: ./scanner.sh [-d|--dump|--day|--today|-s|--student|--dropdb]"
    echo -e " -d, --dump\t\tDump(show) all attendance data"
    echo -e " --day\t\t\tShow attendance data for a specific day"
    echo -e " --today\t\tShow attendance data for today"
    echo -e " -s, --student\t\tShow attendance data for a student"
    echo -e " -c, --csv\t\tExport data to CSV"
    echo -e " --delete\t\tDelete attendance for a student on a particular day"
    echo -e " --dropdb\t\tDrop(delete) all attendance data"
}

if [[ $# -eq 1 ]]; then
    if [[ $1 == "--help" || $1 == "-h" ]]; then
        help
        exit 0
    elif [[ $1 == "--offline" ]]; then
        OFFLINE=true
        main
    fi
fi

while [[ $ADMIN_PASS == "" ]]; do
    login
done
if [[ $# -ge 1 ]]; then
    if [[ $1 == "--dump" || $1 == "-d" ]]; then
        printf "${GREEN}Dumping data...${RESET}\n"
        dump_data
    elif [[ $1 == "--delete" ]]; then
        echo -n "Please enter the ID for the student: "
        read id
        echo -n "What is the year of the day you want to delete? (####) "
        read year
        echo -n "What is the month of the day you want to delete? (1-12) "
        read month
        echo -n "What is the day you want to delete? (1-31) "
        read day
        delete_date_for_student $month $day $year $id
    elif [[ $1 == "--dropdb" ]]; then
        printf "${RED}Are you sure you want to delete all the data? (y/n)${RESET} "
        read ans
        if [[ $ans == "y" ]]; then
            printf "${GREEN}Dropping all data...${RESET}\n"
            drop_data
        else
            echo "Aborting."
        fi
    elif [[ $1 == "--day" ]]; then
        echo -n "Which month do you want to see the attendance for? (1-12) "
        read month
        echo -n "Which day do you want to see the attendance for? (1-31) "
        read day
        echo -n "Which year do you want to see the attendance for? (####) "
        read year
        dump_day $month $day $year
    elif [[ $1 == "--today" ]]; then
        dump_today
    elif [[ $1 == "-c" || $1 == "--csv" ]]; then
        dump_csv
    elif [[ $1 == "-s" || $1 == "--student" ]]; then
        echo -n "Please enter the ID for the student: "
        read id
        dump_student $id
    else
        help
    fi
else
    main
fi
