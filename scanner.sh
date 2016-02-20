#!/bin/bash

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
# Directory where all logs are stored
LOG_DIR="logs"
# Log of all IDs
LOG=$LOG_DIR/barcode-${MONTH}-${DAY}-${YEAR}.log
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

# Create log directory if it doesn't exist
if [ ! -d $LOG_DIR ]; then
    mkdir -p $LOG_DIR
fi

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
    elif [[ $response =~ "SUCCESS" ]]; then
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
    response=$(curl -s $SERVER_ADDR -d "id=$1&email=${ADMIN_EMAIL}&pass=${ADMIN_PASS}&month=${MONTH}&day=${DAY}&year=${YEAR}")
    if [[ ${#response} == 0 ]]; then
        # Log any IDs that failed to send to the server
        printf "\n${RED}ERROR: Could not contact server${RESET}\n"
        echo $1 >> $FAILED_LOG
        show_prompt
    elif [[ $response =~ "ERROR" ]]; then
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
            if [[ $num_failed ]]; then
                touch $LOG.lock
                printf "\n${MAGENTA}(!) I'm preparing to dump ${num_failed} pending IDs to the server!${RESET}\n"
                show_prompt
                # Iterate through each failed ID and try to send it to the
                # server
                while read line; do
                    response=$(curl -s $SERVER_ADDR -d "id=$line&email=${ADMIN_EMAIL}&pass=${ADMIN_PASS}&month=${MONTH}&day=${DAY}&year=${YEAR}")
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
        curl $SERVER_ADDR/day -d "email=${ADMIN_EMAIL}&pass=${ADMIN_PASS}&month=$1&day=$2&year=$3" > $1-$2-$3.log
        printf "${GREEN}Output saved to file '$1-$2-$3.log'${RESET}\n"
    else
        curl $SERVER_ADDR/day -d "email=${ADMIN_EMAIL}&pass=${ADMIN_PASS}&month=$1&day=$2&year=$3"
    fi
}

function dump_today() {
    month=$(date +%m)
    day=$(date +%d)
    year=$(date +%Y)
    if $SAVE_DUMP_OUTPUT; then
        curl $SERVER_ADDR/day -d "email=${ADMIN_EMAIL}&pass=${ADMIN_PASS}&month=${month}&day=${day}&year=${year}" > $month-$day-$year.log
        printf "${GREEN}Output saved to file '$month-$day-$year.log'${RESET}\n"
    else
        curl $SERVER_ADDR/day -d "email=${ADMIN_EMAIL}&pass=${ADMIN_PASS}&month=${month}&day=${day}&year=${year}"
    fi
}

function dump_student() {
    if $SAVE_DUMP_OUTPUT; then
        curl $SERVER_ADDR/student -d "email=${ADMIN_EMAIL}&pass=${ADMIN_PASS}&id=$1" > $1.log
        printf "${GREEN}Output saved to file '$1.log'${RESET}\n"
    else
        curl $SERVER_ADDR/student -d "email=${ADMIN_EMAIL}&pass=${ADMIN_PASS}&id=$1"
    fi
}

function delete_date_for_student() {
    response=$(curl -s $SERVER_ADDR/delete -d "email=${ADMIN_EMAIL}&pass=${ADMIN_PASS}&month=$1&day=$2&year=$3&id=$4")
    if [[ ${#response} == 0 ]]; then
        printf "${RED}ERROR: Could not contact server${RESET}\n"
    elif [[ $response =~ "SUCCESS" ]]; then
        printf "${GREEN}Successfully deleted date${RESET}\n"
    else
        printf "${RED}${response}${RESET}\n"
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
    response=$(curl -s $SERVER_ADDR/dropdb -d "email=${ADMIN_EMAIL}&pass=${ADMIN_PASS}")
    if [[ ${#response} == 0 ]]; then
        printf "${RED}ERROR: Could not contact server${RESET}\n"
    elif [[ $response =~ "Deleted" ]]; then
        printf "${GREEN}${response}${RESET}\n"
    else
        printf "${RED}${response}${RESET}\n"
    fi
}

function scan() {
    # Update log name if dates were overridden
    LOG=$LOG_DIR/barcode-${MONTH}-${DAY}-${YEAR}.log
    FAILED_LOG=$LOG.FAILED
    printf "${YELLOW}Enter \"back\" to go back to the main menu${RESET}\n"
    while [[ true ]]; do
        show_prompt
        read barcode
        if [[ $barcode == "back" ]]; then
            main
        elif [[ ${#barcode} != $VALID_BARCODE_LENGTH ]]; then
            printf "${RED}ERROR: Invalid barcode${RESET}\n"
        elif echo $barcode | grep "[^0-9]\+" > /dev/null; then
            printf "${RED}ERROR: Invalid barcode${RESET}\n"
        else
            if [[ ! -f $LOG ]]; then
                touch $LOG
            fi
            # Only send barcodes that haven't been logged yet
            # -q will only return exit code
            if grep -q $barcode $LOG; then
                printf "${YELLOW}You already scanned in${RESET}\n"
            else
                printf "${GREEN}Got barcode: ${barcode}${RESET}\n"
                # Append barcode to log
                echo $barcode >> $LOG
                # Send data to server asynchronously
                post_data $barcode &
            fi
        fi
    done
}

function upload_attendance_from_log() {
    if [[ ! -f $1 ]]; then
        printf "${RED}File not found!${RESET}\n"
        return
    fi
    basename=$(basename $1 .log)
    IFS=- read junk MONTH DAY YEAR <<< $basename
    while read id; do
        printf "${MAGENTA}Uploading $id${RESET}\n"
        response=$(curl -s $SERVER_ADDR -d "id=$id&email=${ADMIN_EMAIL}&pass=${ADMIN_PASS}&month=${MONTH}&day=${DAY}&year=${YEAR}")
        if [[ ${#response} != 0 && ! $response =~ "ERROR" ]]; then
            printf "${GREEN}Done!${RESET}\n"
        else
            printf "${RED}Failed to send $id${RESET}\n"
        fi
    done < $1
}

# Format attendance by removing dates we don't want, and converting csv to ods
function format_attendance() {
    # Number to Month
    case $1 in
    [1-9]|1[0-2])
        date=$(date -d "$1/01" +%B) ;;
    *)
        printf "${RED}Invalid month${RESET}"
        return ;;
    esac

    dump_csv
    file="$date-Attendance.csv"

    head=$(head -n 1 "$OUTPUT_FILE.csv")
    found=0
    first=0
    last=0
    IFS=',' read -r -a split <<< "$head"

    for element in "${split[@]}"; do
        if [[ $element =~ ^$1/[0-9]+/[0-9]{4}$ ]]; then
            found=1
        else
            if [[ $found == 1 ]]; then # We've finished going through meetings of the desired month
                break
            fi
        fi

        if [[ $found == 0 ]]; then # Only increment until we've found the first meeting of the month
            first=$((first+1))
        fi
        last=$((last+1))
    done
    first=$((first+1)) # Correct offset

    if [[ $first -gt $last ]]; then
        printf "${RED}No data for that month.${RESET}\n"
        return
    fi
    cat OUT.csv | cut -d, -f-2,$first-$last > "$file"

    # Remove junk id's, including ones not linked to any names on Team Manager
    sed -i -e "/[0-9]\{9\},,/d" "$file"
    sed -i -e "/000000000,/d" "$file"
    printf "${GREEN}Data formatted to $file${RESET}\n"

    if [[ ! $(command -v csv2ods) ]]; then
        printf "${YELLOW}csv2ods not detected. Attempting installation...${RESET}\n"
        sudo apt-get install python-odf-tools
        if [[ ! $(command -v csv2ods) ]]; then
            printf "${RED}csv2ods still not detected! Aborting!${RESET}\n"
        fi
    fi
    printf "${YELLOW}Converting from csv to ods...${RESET}\n"
    csv2ods -i "$date-Attendance.csv" -o "$date-Attendance.ods"
    printf "${GREEN}$date-Attendance.csv converted to $date-Attendance.ods${RESET}\n"

    echo -n "Would you like to email this? [y/n] "
    read ans
    if [[ $ans =~ ^[Yy]$ ]]; then
        echo -n "Your Email: "
        read email
        printf "${YELLOW}If you have 2 factor auth enabled, you need to generate an app specific password.\n"
        printf "You can do so over at https://security.google.com/settings/security/apppasswords?pli=1 (assuming you use gmail)${RESET}\n"
        echo -n "Password: "
        read password
        echo -n "Your Name: "
        read name
        echo -n "Recipient Email: "
        read recipient
        mail_attendance "$date" "$email" "$password" "$name" "$recipient"
    fi
}

function mail_attendance() {
    if [[ ! $(command -v mime-tool) ]]; then
        printf "${YELLOW}mime-tool not detected. Attempting installation...${RESET}\n"
        sudo apt-get install topal
        if [[ ! $(command -v mime-tool) ]]; then
            printf "${RED}mime-tool still not detected! Aborting!${RESET}\n"
        fi
    fi

    printf "${YELLOW}Crafting email...${RESET}\n"
    echo "From: \"$4\" <$2>" > message.txt
    echo "Subject: Attendance for $date" >> message.txt
    mime-tool "$date-Attendance.ods" >> message.txt
    curl "smtps://smtp.gmail.com:465" --user "$2:$3" --mail-from "$2" --mail-rcpt "$5" --ssl --upload-file message.txt
    rm message.txt $date-Attendance.csv $OUTPUT_FILE.csv
}

function help() {
    echo -e "Usage: ./scanner.sh [--offline|-h|--help]"
    echo -e " --offline\tTake attendance offline"
    echo -e " -h --help\tDisplay this message"
}

function main() {
    while :; do
        echo -e "\n1)  Take attendance for today"
        echo "2)  Take attendance for a specific day"
        echo "3)  Dump(show) all attendance data"
        echo "4)  Show attendance data for a specific day"
        echo "5)  Show attendance data for today"
        echo "6)  Show attendance data for a student"
        echo "7)  Export data to CSV"
        echo "8)  Delete attendance for a student on a particular day"
        echo "9)  Drop(delete) all attendance data"
        echo "10) Upload attendance from a log"
        echo "11) Format attendance for a specific month (and option to email it)"
        echo -e "12) Exit\n"
        printf "${GREEN}What would you like to do?>${RESET} "
        read choice

        if [[ $choice == "1" ]]; then
            # Override dates with current date
            MONTH=$(date +%m)
            DAY=$(date +%d)
            YEAR=$(date +%Y)
            scan
        elif [[ $choice == "2" ]]; then
            echo -n "Which month do you want to scan for? (1-12) "
            read month
            echo -n "Which day do you want to scan for? (1-31) "
            read day
            echo -n "Which year do you want to scan for? (####) "
            read year
            MONTH=$month
            DAY=$day
            YEAR=$year
            scan
        elif [[ $choice == "3" ]]; then
            printf "${GREEN}Dumping data...${RESET}\n"
            dump_data
        elif [[ $choice == "4" ]]; then
            echo -n "Which month do you want to see the attendance for? (1-12) "
            read month
            echo -n "Which day do you want to see the attendance for? (1-31) "
            read day
            echo -n "Which year do you want to see the attendance for? (####) "
            read year
            dump_day $month $day $year
        elif [[ $choice == "5" ]]; then
            dump_today
        elif [[ $choice == "6" ]]; then
            echo -n "Please enter the ID for the student: "
            read id
            dump_student $id
        elif [[ $choice == "7" ]]; then
            dump_csv
        elif [[ $choice == "8" ]]; then
            echo -n "Please enter the ID for the student: "
            read id
            echo -n "What is the year of the day you want to delete? (####) "
            read year
            echo -n "What is the month of the day you want to delete? (1-12) "
            read month
            echo -n "What is the day you want to delete? (1-31) "
            read day
            delete_date_for_student $month $day $year $id
        elif [[ $choice == "9" ]]; then
            printf "${RED}Are you sure you want to delete all the data? (y/n)${RESET} "
            read ans
            if [[ $ans == "y" ]]; then
                printf "${GREEN}Dropping all data...${RESET}\n"
                drop_data
            else
                echo "${RED}Aborting.${RESET}\n"
            fi
        elif [[ $choice == "10" ]]; then
            find $LOG_DIR -name "*.log"
            echo -ne "\nWhich log would you like to upload? "
            read log
            upload_attendance_from_log $log
        elif [[ $choice == "11" ]]; then
            echo -n "Month to format? (1-12) "
            read month
            format_attendance $month
        elif [[ $choice == "12" ]]; then
            printf "${RED}Exiting...${RESET}\n"
            exit
        fi
    done
}

if [[ $# -eq 1 ]]; then
    if [[ $1 == "--help" || $1 == "-h" ]]; then
        help
        exit 0
    elif [[ $1 == "--offline" ]]; then
        OFFLINE=true
        scan
    fi
fi

while [[ ! $ADMIN_PASS ]]; do
    login
done
main
