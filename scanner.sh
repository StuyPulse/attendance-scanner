#!/bin/bash

# Configuration
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

# Remind the user of any failed IDs upon exiting
trap "remind_failed_ids; exit" EXIT

# Remind the user of any failed IDs
function remind_failed_ids() {
    failed_logs=$(find $LOG_DIR -name "*.FAILED")
    if [[ $failed_logs != "" ]]; then
        printf "\n${RED}(!) The following logs have ids that have failed to send to the server:${RESET}\n"
        echo "$failed_logs"
    fi
}

function login() {
    # Read login credentials and validate with server
    read -rep "Attendance Administrator Email: " email
    read -resp "Attendance Administrator Password: " pass
    echo
    response=$(curl -s $SERVER_ADDR -d "email=${email}&pass=${pass}&month=${MONTH}&day=${DAY}&year=${YEAR}")
    if [[ ${#response} == 0 ]]; then
        printf "${RED}ERROR: Could not contact server${RESET}\n"
    elif [[ $response =~ SUCCESS ]]; then
        printf "${GREEN}Validation successful${RESET}\n"
        ADMIN_PASS=$pass
        ADMIN_EMAIL=$email
    else
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
}

function post_data() {
    # Send ID to server
    if [[ $# != 1 ]]; then
        return -1;
    fi
    # If we're in offline mode, then append the IDs to the log of pending IDs
    if $OFFLINE; then
        echo "$1" >> "$FAILED_LOG"
        exit 0
    fi
    response=$(curl -s $SERVER_ADDR -d "id=$1&email=${ADMIN_EMAIL}&pass=${ADMIN_PASS}&month=${MONTH}&day=${DAY}&year=${YEAR}")
    if [[ ${#response} == 0 ]]; then
        # Log any IDs that failed to send to the server
        printf "\n${RED}ERROR: Could not contact server${RESET}\n"
        echo "$1" >> "$FAILED_LOG"
        show_prompt
    elif [[ $response =~ ERROR ]]; then
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
                touch "$LOG.lock"
                printf "\n${MAGENTA}(!) Preparing to dump ${num_failed} pending IDs to the server!${RESET}\n"
                show_prompt
                # Iterate through each failed ID and try to send it to the
                # server
                while read line; do
                    response=$(curl -s $SERVER_ADDR -d "id=$line&email=${ADMIN_EMAIL}&pass=${ADMIN_PASS}&month=${MONTH}&day=${DAY}&year=${YEAR}")
                    # If unsuccessful, append to list of new IDs
                    if [[ ${#response} == 0 || $response =~ ERROR ]]; then
                        echo "$line" >> "$FAILED_LOG.new"
                    else
                        echo "$line" >> "$LOG"
                    fi
                done < "$FAILED_LOG"

                # If there are more failed IDs, update the failed log
                if [[ -f $FAILED_LOG.new ]]; then
                    mv "$FAILED_LOG.new" "$FAILED_LOG"
                else
                    rm -f "$FAILED_LOG"
                fi
                rm -f "$LOG.lock"
            fi
        fi
    fi
    return 0;
}

function get_num_failed() {
    # Print the number of pending IDs that failed to send
    if [[ -f $FAILED_LOG ]]; then
        wc -l < "$FAILED_LOG"
    fi
}

function dump_data() {
    response=$(curl -s $SERVER_ADDR/dump -d "email=${ADMIN_EMAIL}&pass=${ADMIN_PASS}")
    if [[ $? != 0 ]]; then
        printf "${RED}ERROR: Could not contact server${RESET}\n"
    elif [[ $response =~ ERROR ]]; then
        printf "${RED}${response}${RESET}\n"
    else
        if $SAVE_DUMP_OUTPUT; then
            printf "${GREEN}Output saved to file '$OUTPUT_FILE'${RESET}\n"
            echo "$response" > "$OUTPUT_FILE"
        else
            echo "$response"
        fi
    fi
}

function dump_day() {
    response=$(curl -s $SERVER_ADDR/day -d "email=${ADMIN_EMAIL}&pass=${ADMIN_PASS}&month=$1&day=$2&year=$3")
    if [[ $? != 0 ]]; then
        printf "${RED}ERROR: Could not contact server${RESET}\n"
    elif [[ $response =~ ERROR ]]; then
        printf "${RED}${response}${RESET}\n"
    else
        if $SAVE_DUMP_OUTPUT; then
            printf "${GREEN}Output saved to file '$1-$2-$3.log'${RESET}\n"
            echo "$response" > "$1-$2-$3.log"
        else
            echo "$response"
        fi
    fi
}

function dump_today() {
    month=$(date +%m)
    day=$(date +%d)
    year=$(date +%Y)
    dump_day "$month" "$day" "$year"
}

function dump_student() {
    response=$(curl -s $SERVER_ADDR/student -d "email=${ADMIN_EMAIL}&pass=${ADMIN_PASS}&id=$1")
    if [[ $? != 0 ]]; then
        printf "${RED}ERROR: Could not contact server${RESET}\n"
    elif [[ $response =~ ERROR ]]; then
        printf "${RED}${response}${RESET}\n"
    else
        if $SAVE_DUMP_OUTPUT; then
            printf "${GREEN}Output saved to file '$1.log'${RESET}\n"
            echo "$response" > "$1.log"
        else
            echo "$response"
        fi
    fi
}

function delete_date_for_student() {
    response=$(curl -s $SERVER_ADDR/delete -d "email=${ADMIN_EMAIL}&pass=${ADMIN_PASS}&month=$1&day=$2&year=$3&id=$4")
    if [[ ${#response} == 0 ]]; then
        printf "${RED}ERROR: Could not contact server${RESET}\n"
    elif [[ $response =~ SUCCESS ]]; then
        printf "${GREEN}Successfully deleted date${RESET}\n"
    else
        printf "${RED}${response}${RESET}\n"
    fi
}

function dump_csv() {
    response=$(curl -s $SERVER_ADDR/csv -d "email=${ADMIN_EMAIL}&pass=${ADMIN_PASS}")
    if [[ $? != 0 ]]; then
        printf "${RED}ERROR: Could not contact server${RESET}\n"
    elif [[ $response =~ ERROR ]]; then
        printf "${RED}${response}${RESET}\n"
    else
        if $SAVE_DUMP_OUTPUT; then
            printf "${GREEN}Output saved to file '$OUTPUT_FILE.csv'${RESET}\n"
            echo "$response" > "$OUTPUT_FILE.csv"
        else
            echo "$response"
        fi
    fi
}

function drop_data() {
    response=$(curl -s $SERVER_ADDR/dropdb -d "email=${ADMIN_EMAIL}&pass=${ADMIN_PASS}")
    if [[ ${#response} == 0 ]]; then
        printf "${RED}ERROR: Could not contact server${RESET}\n"
    elif [[ $response =~ Deleted ]]; then
        printf "${GREEN}${response}${RESET}\n"
    else
        printf "${RED}${response}${RESET}\n"
    fi
}

function scan() {
    # Update log name if dates were overridden
    LOG=$LOG_DIR/barcode-${MONTH}-${DAY}-${YEAR}.log
    FAILED_LOG=$LOG.FAILED

    echo "1) Scan by id"
    echo "2) Scan by name"
    read -rep "Mode? " choice
    if [[ $choice == "1" ]]; then
        : # pass
    elif [[ $choice == "2" ]]; then
        scan_names
        return
    else
        printf "${RED}Invalid choice${RESET}\n"
        return
    fi

    printf "${YELLOW}Enter \"back\" to go back to the main menu${RESET}\n"
    while :; do
        show_prompt
        read -rep "Enter barcode: " barcode
        history -s "$barcode"
        if [[ $barcode == "back" ]]; then
            return
        elif echo "$barcode" | grep -q -v "^[0-9]\{9\}$"; then
            printf "${RED}ERROR: Invalid barcode${RESET}\n"
        else
            if [[ ! -f "$LOG" ]]; then
                touch "$LOG"
            fi
            # Only send barcodes that haven't been logged yet
            if grep -q "$barcode" "$LOG"; then
                printf "${YELLOW}You already scanned in${RESET}\n"
            else
                printf "${GREEN}Got barcode: ${barcode}${RESET}\n"
                # Append barcode to log
                echo "$barcode" >> "$LOG"
                # Send data to server asynchronously
                post_data "$barcode" &
            fi
        fi
    done
}

function escape() {
    sed 's/[]\.|$(){}?+*^]/\\&/g' <<< "$*"
}

function scan_names() {
    if [[ ! -f "STUDENTS.csv" ]]; then
        printf "${YELLOW}Fetching data...${RESET}\n"
        dump_csv
        mv "$OUTPUT_FILE.csv" "STUDENTS.csv"
    fi
    # Update log name if dates were overridden
    LOG=$LOG_DIR/barcode-${MONTH}-${DAY}-${YEAR}.log
    FAILED_LOG=$LOG.FAILED
    printf "${YELLOW}Enter \"back\" to go back to the main menu${RESET}\n"
    while :; do
        show_prompt
        read -rep "Enter name: " name
        history -s "$name"
        if [[ $name == "back" ]]; then
            return
        elif [[ $name == "" ]]; then
            continue
        else
            if [[ ! -f "$LOG" ]]; then
                touch "$LOG"
            fi

            results=$(grep -i "^[0-9]\{9\},$(escape $name)" "STUDENTS.csv" 2> /dev/null | cut -d, -f1-2)
            num_results=$(echo "$results" | wc -l)

            if [[ $results == "" ]]; then
                printf "${RED}There is nobody with that name in the database.${RESET}\n"
                continue
            elif [[ $num_results == "1" ]]; then
                IFS=',' read -r -a split <<< "$results"
                barcode=${split[0]}
                name=${split[1]}
            else
                printf "${YELLOW}There is more than one result. Please choose from the following:${RESET}\n"

                IFS=$'\n' read -d '' -r -a split <<< "$results"
                for index in "${!split[@]}"; do
                    tmp=$(echo "${split[index]}" | cut -c 11-)
                    echo "[$index] $tmp"
                done

                read -rep "Result? [0-$((${num_results}-1))] " result

                if [[ "$result" =~ ^[0-9]+$ ]] && [ "$result" -ge 0 -a "$result" -lt $num_results ]; then
                    target="${split[$result]}"
                    barcode=$(echo "$target" | cut -d, -f1)
                    name=$(echo "$target" | cut -d, -f2)
                else
                    printf "${RED}Invalid selection.${RESET}\n"
                    continue
                fi
            fi

            if grep -q "$barcode" "$LOG"; then
                printf "${YELLOW}$name already scanned in${RESET}\n"
            else
                printf "${GREEN}Got: ${name} - ${barcode}${RESET}\n"
                # Append barcode to log
                echo "$barcode" >> "$LOG"
                # Send data to server asynchronously
                post_data "$barcode" &
            fi
        fi
    done
}

function upload_attendance_from_log() {
    if [[ ! -f $1 ]]; then
        printf "${RED}File not found!${RESET}\n"
        return
    fi
    basename=$1
    if [[ $basename =~ .*.FAILED ]]; then
        basename=$(basename "$basename" .FAILED)
    fi
    basename=$(basename "$basename" .log)
    IFS=- read junk MONTH DAY YEAR <<< "$basename"
    echo "Uploading attendance from ${MONTH}/${DAY}/${YEAR}"
    while read id; do
        response=$(curl -s $SERVER_ADDR -d "id=$id&email=${ADMIN_EMAIL}&pass=${ADMIN_PASS}&month=${MONTH}&day=${DAY}&year=${YEAR}")
        if [[ ${#response} != 0 && ! $response =~ ERROR ]]; then
            printf "${GREEN}Sent $id${RESET}\n"
        else
            printf "${RED}Failed to send $id${RESET}\n"
        fi
    done < "$1"
    if [[ $1 =~ .*.FAILED ]]; then
        rm "$1"
    fi
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
    cut -d, -f-2,$first-$last < $OUTPUT_FILE.csv > "$file"

    # Remove junk id's, including ones not linked to any names on the server
    sed -i -e "/[0-9]\{9\},,/d" "$file"
    sed -i -e "/000000000,/d" "$file"
    printf "${GREEN}Data formatted to $file${RESET}\n"

    if [[ ! $(command -v csv2ods) ]]; then
        printf "${YELLOW}csv2ods not detected. Attempting installation...${RESET}\n"
        sudo apt-get install python-odf
        if [[ ! $(command -v csv2ods) ]]; then
            printf "${RED}csv2ods still not detected! Aborting!${RESET}\n"
            return
        fi
    fi
    printf "${YELLOW}Converting from csv to ods...${RESET}\n"
    csv2ods -i "$date-Attendance.csv" -o "$date-Attendance.ods"
    printf "${GREEN}$date-Attendance.csv converted to $date-Attendance.ods${RESET}\n"

    read -rep "Would you like to email this? (Only gmail is supported) [y/n] " ans
    if [[ $ans =~ ^[Yy]$ ]]; then
        read -rep "Your Email: " email
        printf "${YELLOW}If you have 2 factor authentication enabled, you need to generate an app specific password.\n"
        printf "You can do so over at https://security.google.com/settings/security/apppasswords?pli=1${RESET}\n"
        read -resp "Password: " password
        read -rep "Your Name: " name
        read -rep "Recipient Email: " recipient
        mail_attendance "$date" "$email" "$password" "$name" "$recipient"
    fi
}

function mail_attendance() {
    if [[ ! $(command -v mime-tool) ]]; then
        printf "${YELLOW}mime-tool not detected. Attempting installation...${RESET}\n"
        sudo apt-get install topal
        if [[ ! $(command -v mime-tool) ]]; then
            printf "${RED}mime-tool still not detected! Aborting!${RESET}\n"
            return
        fi
    fi

    printf "${YELLOW}Crafting email...${RESET}\n"
    echo "From: \"$4\" <$2>" > message.txt
    echo "Subject: Attendance for $date" >> message.txt
    mime-tool "$date-Attendance.ods" >> message.txt
    curl "smtps://smtp.gmail.com:465" --user "$2:$3" --mail-from "$2" --mail-rcpt "$5" --ssl --upload-file message.txt
    rm message.txt "$date-Attendance.csv" "$OUTPUT_FILE.csv"
}

function get_attendance_percentage() {
    response=$(curl -s $SERVER_ADDR/percent -d "email=${ADMIN_EMAIL}&pass=${ADMIN_PASS}&id=$1")
    if [[ ${#response} == 0 ]]; then
        printf "${RED}ERROR: Could not contact server${RESET}\n"
    elif [[ $response =~ ERROR ]]; then
        printf "${RED}${response}${RESET}\n"
    else
        printf "${YELLOW}$1 has attended $response%% of meetings.${RESET}"
    fi
}

function dump_logs() {
    # Backup current logs
    rm -rf "$LOG_DIR.bkp" && cp -rf "$LOG_DIR" "$LOG_DIR.bkp"

    dump_csv

    # Temporarily disable dump saving so we can manually output to a desired file
    SAVE_DUMP_OUTPUT=false
    IFS=',' read -r -a dates <<< "$(head -1 "OUT.csv")"

    # Start at two to account for first and second columns being ID and Name
    for ((i=2; i < ${#dates[@]}; i++)); do
        IFS="/" read month day year <<< "${dates[$i]}"

        # Add padding zeroes for consistent log names
        day=$(printf "%02d" "$day")
        month=$(printf "%02d" "$month")

        echo -ne "\e[0K\rDownloading log $(( i-1 )) of $(( ${#dates[@]}-2 ))..."
        sed "s/ID: //g" <(dump_day "$month" "$day" "$year") > "$LOG_DIR/barcode-${month}-${day}-${year}.log"
    done
    printf "\n${GREEN}Done!${RESET}\n"
    SAVE_DUMP_OUTPUT=true
}

function help() {
    echo -e "Usage: ./scanner.sh [--offline|-h|--help]"
    echo -e " --offline\tTake attendance offline"
    echo -e " -h --help\tDisplay this message"
}

function main() {
    remind_failed_ids
    while :; do
        echo -e "\n1)  Take attendance for today"
        echo "2)  Take attendance for a specific day"
        if $OFFLINE; then
            printf "${RED}"
        fi
        echo "3)  Dump(show) all attendance data"
        echo "4)  Show attendance data for a specific day"
        echo "5)  Show attendance data for today"
        echo "6)  Show attendance data for a student"
        echo "7)  Export data to CSV"
        echo "8)  Delete attendance for a student on a particular day"
        echo "9)  Drop(delete) all attendance data"
        echo "10) Upload attendance from a log"
        echo "11) Format attendance for a specific month (and option to email it)"
        echo "12) Get percentage of meetings attended for by a student"
        echo "13) Sync logs from server"
        printf "${RESET}"
        echo -e "14) Go online"
        echo -e "15) Exit\n"
        read -rep "What would you like to do?> " choice

        if [[ $choice == "15" ]]; then
            printf "${RED}Exiting...${RESET}\n"
            exit
        fi
        if [[ $choice == "1" ]]; then
            # Override dates with current date
            MONTH=$(date +%m)
            DAY=$(date +%d)
            YEAR=$(date +%Y)
            scan
        elif [[ $choice == "2" ]]; then
            read -rep "Which month do you want to scan for? (1-12) " month
            read -rep "Which day do you want to scan for? (1-31) " day
            read -rep "Which year do you want to scan for? (####) " year
            MONTH=$(printf "%02d" "$month")
            DAY=$(printf "%02d" "$day")
            YEAR=$year
            scan
        elif [[ $choice == "14" ]]; then
            if $OFFLINE; then
                login
                if [[ $ADMIN_PASS ]]; then
                    OFFLINE=false
                    remind_failed_ids
                fi
            else
                printf "${YELLOW}You are already online${RESET}\n"
            fi
        elif $OFFLINE; then
            echo "You are currently in offline mode. Available actions are:"
            echo ""
            echo "1)  Take attendance for today"
            echo "2)  Take attendance for a specific day"
            echo "14) Go online"
            echo "15) Exit"
            echo ""
            echo "For more functionality, re-run the script while connected to the internet"
        elif [[ $choice == "3" ]]; then
            printf "${GREEN}Dumping data...${RESET}\n"
            dump_data
        elif [[ $choice == "4" ]]; then
            read -rep "Which month do you want to see the attendance for? (1-12) " month
            read -rep "Which day do you want to see the attendance for? (1-31) " day
            read -rep "Which year do you want to see the attendance for? (####) " year
            month=$(printf "%02d" "$month")
            day=$(printf "%02d" "$day")
            dump_day "$month" "$day" "$year"
        elif [[ $choice == "5" ]]; then
            dump_today
        elif [[ $choice == "6" ]]; then
            read -rep "Please enter the ID for the student: " id
            history -s "$id"
            dump_student "$id"
        elif [[ $choice == "7" ]]; then
            dump_csv
        elif [[ $choice == "8" ]]; then
            read -rep "Please enter the ID for the student: " id
            history -s "$id"
            read -rep "What is the year you want to delete? (####) " year
            read -rep "What is the month you want to delete? (1-12) " month
            read -rep "What is the day you want to delete? (1-31) " day
            delete_date_for_student "$month" "$day" "$year" "$id"
        elif [[ $choice == "9" ]]; then
            read -rep "Are you sure you want to delete all the data? (y/n) " ans
            if [[ $ans == "y" ]]; then
                printf "${GREEN}Dropping all data...${RESET}\n"
                drop_data
            else
                printf "${RED}Aborting.${RESET}\n"
            fi
        elif [[ $choice == "10" ]]; then
            find $LOG_DIR -name "*.log*"
            read -rep "Which log would you like to upload? " log
            history -s "$log"
            upload_attendance_from_log "$log"
        elif [[ $choice == "11" ]]; then
            read -rep "Month to format? (1-12) " month
            format_attendance "$month"
        elif [[ $choice == "12" ]]; then
            read -rep "Please enter the ID for the student: " id
            history -s "$id"
            get_attendance_percentage "$id"
        elif [[ $choice == "13" ]]; then
            dump_logs
        fi
    done
}

if [[ $# -eq 1 ]]; then
    if [[ $1 == "--offline" ]]; then
        OFFLINE=true
    else
        help
        exit 0
    fi
fi

if ! $OFFLINE; then
    while [[ ! $ADMIN_PASS ]]; do
        login
    done
else
    printf "${YELLOW}Running in offline mode${RESET}\n"
fi
main
