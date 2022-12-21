#!/bin/bash
#
# Author: Denis Steinhorst [denis at steinhor dot st]
# Description: Dynamic DNS Updater to Failover between two IPs for Dynu.com
# Version: 1.0.1
# Date: 2022-12-16
# License: WTFPL
#
# Usage: see --help
# Documentation: https://github.com/denissteinhorst/dynu_failover
#
# Notes: This script is intended to be run from cron every minute.

# RUNTIME VARIABLES

DRYRUN=0
FORCE=0
QUIET=0
VERBOSE=0
LASTIP=0
UPDATEIP=0
TIMESTAMP=0
TRIES=0
ERROR=0

# PARSING ARGUMENTS

while [ "$1" != "" ]; do
    case $1 in
    -d | --dryrun)
        DRYRUN=1
        ;;
    -f | --force)
        FORCE=1
        ;;
    -q | --quiet)
        QUIET=1
        ;;
    -v | --verbose)
        VERBOSE=1
        ;;
    -h | --help)
        echo "Usage: ${0} [-d | --dryrun] [-q | --quiet] [-v | --verbose] [-f | --force] [-h | --help]"
        exit
        ;;
    *)
        echo "Unknown Argument, use: ${0} [-d | --dryrun] [-q | --quiet] [-v | --verbose] [-f | --force] [-h | --help]"
        exit 1
        ;;
    esac
    shift
done

# RUN-MODES

if [ $VERBOSE == 1 ]; then
    if [ -t 1 ]; then
        echo -e "\x1B[31m Starting Dynu Failover Script in \"verbose mode\": \x1B[0m"
    else
        echo "Starting Dynu Failover Script in \"verbose mode\":"
    fi
fi

if [ $VERBOSE == 1 ] && [ $QUIET == 1 ]; then
    if [ -t 1 ]; then
        echo -e "\x1B[31m INFO: You can't use verbose and quiet mode at the same time! Disabling quiet mode \x1B[0m"
    else
        echo "INFO: You can't use verbose and quiet mode at the same time! Disabling quiet mode:"
    fi
    QUIET=0
fi

if [ $DRYRUN == 1 ]; then
    if [ -t 1 ]; then
        echo -e "\x1B[31m Starting Dynu Failover Script in \"dryrun mode\", no changes to dynu will be made! \x1B[0m"
    else
        echo "Starting Dynu Failover Script in \"dryrun mode\", no changes to dynu will be made!"
    fi
fi

# METHODS

writeLog() {
    if [ "$LOGPATH" != "" ]; then
        if [ ! -f $LOGPATH ]; then
            echo "$(date +"%Y-%m-%d %H:%M:%S") - ${1}" >>$LOGPATH
        else
            echo "$(date +"%Y-%m-%d %H:%M:%S") - ${1}" >>$LOGPATH
        fi
    fi
}

exitWith() {
    if [ $VERBOSE == 1 ]; then
        printMsg "[[exitWith]]"
    fi
    if [ $QUIET == 0 ]; then
        if [ -t 1 ]; then
            echo -e "\x1B[31m [!] ERROR: \x1B[0m ${1}"
        else
            echo "[!] ERROR: $1"
        fi
    fi
    writeLog "[!] ERROR: ${1}"
    exit 1
}

printMsg() {
    if [ $QUIET == 0 ]; then
        if [ -t 1 ]; then
            echo -e "\x1B[36m -> \x1B[0m ${1}"
        else
            echo "-> ${1}"
        fi
    fi
}

validateConfig() {
    # CHECK FOR: PRIMARY_FRIENDLY_NAME
    if [ -z "$PRIMARY_FRIENDLY_NAME" ]; then
        ERROR=1 && exitWith "PRIMARY_FRIENDLY_NAME is empty! Use a friendly name for your primary host."
    else
        if [ $VERBOSE == 1 ]; then
            printMsg "Primary Hostname:\x1B[33m \t\t$PRIMARY_FRIENDLY_NAME \x1B[0m"
        fi
    fi

    # CHECK FOR: PRIMARY_FRITZDNS
    if [ -z "$PRIMARY_FRITZDNS" ]; then
        ERROR=1 && exitWith "PRIMARY_FRITZDNS is empty! You need to have a MyFritz-Address for your primary host."
    fi
    if [[ $PRIMARY_FRITZDNS != *".myfritz.net" ]]; then
        ERROR=1 && exitWith "PRIMARY_FRITZDNS is not a valid subdomain of myfritz.net!"
    else
        if [ $VERBOSE == 1 ]; then
            printMsg "Primary FritzDNS:\x1B[33m \t\t$PRIMARY_FRITZDNS \x1B[0m"
        fi
    fi

    # CHECK FOR: SECONDARY_FRIENDLY_NAME
    if [ -z "$SECONDARY_FRIENDLY_NAME" ]; then
        ERROR=1 && exitWith "SECONDARY_FRIENDLY_NAME is empty! Use a friendly name for your secondary host."
    else
        if [ $VERBOSE == 1 ]; then
            printMsg "Secondary Hostname:\x1B[33m \t$SECONDARY_FRIENDLY_NAME \x1B[0m"
        fi
    fi

    # CHECK FOR: SECONDARY_FRITZDNS
    if [ -z "$SECONDARY_FRITZDNS" ]; then
        ERROR=1 && exitWith "SECONDARY_FRITZDNS is empty! You need to have a MyFritz-Address for your secondary host."
    fi
    if [[ $SECONDARY_FRITZDNS != *".myfritz.net" ]]; then
        ERROR=1 && exitWith "SECONDARY_FRITZDNS is not a valid subdomain of myfritz.net!"
    else
        if [ $VERBOSE == 1 ]; then
            printMsg "Secondary FritzDNS:\x1B[33m \t$SECONDARY_FRITZDNS \x1B[0m"
        fi
    fi
    if [ $PRIMARY_FRITZDNS == $SECONDARY_FRITZDNS ]; then
        ERROR=1 && exitWith "PRIMARY_FRITZDNS and SECONDARY_FRITZDNS are equal! This ain't how \"failover\" works you know... :P"
    fi

    # CHECK FOR: DYNU CREDENTIALS
    if [ -z "$DYNU_USERNAME" ]; then
        ERROR=1 && exitWith "DYNU_USERNAME is empty! You need to have a Dynu.com account to use this script."
    else
        if [ $VERBOSE == 1 ]; then
            printMsg "Using Dynu account:\x1B[33m \t$DYNU_USERNAME \x1B[0m"
        fi
    fi
    if [ -z "$DYNU_PASSWORD" ]; then
        ERROR=1 && exitWith "DYNU_PASSWORD is empty! You need to have a Dynu.com account to use this script."
    fi
    if [[ ! $DYNU_PASSWORD =~ ^[a-f0-9]{64}$ ]]; then
        ERROR=1 && exitWith "DYNU_PASSWORD is not a valid sha-256 hash!"
    else
        if [ $VERBOSE == 1 ]; then
            printMsg "Found valid SHA256:\x1B[33m \t****** (masked) \x1B[0m"
        fi
    fi
    if [ -z "$DYNU_HOSTNAME" ]; then
        ERROR=1 && exitWith "DYNU_HOSTNAME is empty! You need to have a Dynu.com account to use this script."
    else
        if [ $VERBOSE == 1 ]; then
            printMsg "Trying to update:\x1B[33m \t\t${DYNU_HOSTNAME} \x1B[0m"
        fi
    fi
    if [ -z "$DYNU_URL" ]; then
        ERROR=1 && exitWith "DYNU_URL is empty! You need to provide the base-update-url (without ?...)."
    else
        if [ $VERBOSE == 1 ]; then
            printMsg "Using Update-URL:\x1B[33m \t\t${DYNU_URL} \x1B[0m"
        fi
    fi

    # CHECK FOR: ERROR_MAIL
    if [ -z "$ERROR_MAIL" ]; then
        if [ $VERBOSE == 1 ]; then
            printMsg "ERROR_MAIL is empty! No error mail will be sent. (this is not a problem)"
        fi
    else
        if [ $VERBOSE == 1 ]; then
            printMsg "Sending Error-Mails to:\x1B[33m \t${ERROR_MAIL} \x1B[0m"
        fi
    fi

    # CHECK FOR: LOGPATH
    if [ -z "$LOGPATH" ]; then
        if [ $VERBOSE == 1 ]; then
            printMsg "LOGPATH is empty! No logs will be written. (this is not a problem)"
        fi
    else
        if [ $VERBOSE == 1 ]; then
            printMsg "Writing Logfiles to:\x1B[33m \t${LOGPATH} \x1B[0m"
        fi
    fi

    # CHECK FOR: MAX_RETRIES
    if [ -z "$MAX_RETRIES" ]; then
        ERROR=1 && exitWith "MAX_RETRIES is empty! If you not set this, the script will try to update your IP and send mails continuesly."
    else
        if [ $VERBOSE == 1 ]; then
            printMsg "Retrying the ping:\x1B[33m \t${MAX_RETRIES} (times before giving up)\x1B[0m"
        fi
    fi

    # CHECK FOR: RETRY_COOLDOWN
    if [ -z "$RETRY_COOLDOWN" ]; then
        ERROR=1 && exitWith "RETRY_COOLDOWN is empty! This is the time in seconds the script will wait before trying to update your IP again."
    else
        if [ $VERBOSE == 1 ]; then
            printMsg "waiting:\x1B[33m \t\t\t${RETRY_COOLDOWN} (seconds before resetting the retry counter)\x1B[0m"
        fi
    fi

    if [ $VERBOSE == 1 ]; then
        read -p " ->  Looking good to me, do you want to continue? [y/n] " -n 1 -r
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo " Aborting..."
            exit 1
        fi
        printMsg "Configuration validated!"
    fi
}

getConfig() {
    if [ ! -f dynu_failover.conf ]; then
        ERROR=1 && exitWith "Configuration file not found!"
    else
        if [ $VERBOSE == 1 ]; then
            printMsg "Config found! starting validation next."
        fi
        source dynu_failover.conf

        if [ $VERBOSE == 1 ]; then
        printMsg "Configuration validated!"
        fi
    fi
}

setState() {
    if [ $DRYRUN == 1 ]; then
        printMsg "DRY: (new dynu_failover.state) ${1} ${2} $(date +%s)"

        if [ $VERBOSE == 1 ]; then
            printMsg "State file got not updated, because of dry-run."
        fi
    else
        TIMESTAMP=$(date +%s)

        echo "${1}" >dynu_failover.state
        echo "${2}" >>dynu_failover.state
        echo "${TIMESTAMP}" >>dynu_failover.state

        if [ $VERBOSE == 1 ]; then
            printMsg "Update State: ${1} ${2} $(date +%s)"
        fi
    fi
}

getState() {
    if [ ! -f dynu_failover.state ]; then
        setState "0" "0"

        if [ $VERBOSE == 1 ]; then
            printMsg "State file not found, creating it."
        fi
    else
        LASTIP=$(head -n 1 dynu_failover.state)
        TRIES=$(head -n 2 dynu_failover.state | tail -n 1)
        TIMESTAMP=$(head -n 3 dynu_failover.state | tail -n 1)
    fi

    if [ $VERBOSE == 1 ]; then
        printMsg "Loaded States: ${LASTIP} ${TRIES} ${TIMESTAMP}"
    fi
}

checkTries() {
    if [ $VERBOSE == 1 ]; then
        printMsg "current try: ${TRIES}/${MAX_RETRIES}"
    fi

    if [ $(expr $TRIES \>= $MAX_RETRIES) -eq 1 ]; then
        if [ $VERBOSE == 1 ]; then
            printMsg "reached: ${TRIES}/${MAX_RETRIES} tries"
        fi
        if [ $(($TIMESTAMP + $RETRY_COOLDOWN)) -le $(date +%s) ]; then
            if [ $VERBOSE == 1 ]; then
                printMsg "Cooldown expired, resetting tries, continuing..."
            fi
            TRIES=0
            setState $LASTIP $TRIES
        else
            ERROR=1 && exitWith "The cooldown is not over yet, aborting..."
        fi
    fi
}

sendMail() {
    if [ "$ERROR_MAIL" != "" ]; then
        mail -s "Dynu Failover on [${HOSTNAME}] failed - Tried: ${TRIES}/${MAX_RETRIES} times." $ERROR_MAIL </dev/null
        writeLog "Sent mail to [${ERROR_MAIL}]"

        if [ $VERBOSE == 1 ]; then
            printMsg "Dynu Failover on [${HOSTNAME}] failed - Tried: ${TRIES}/${MAX_RETRIES} times."
            printMsg "Sent mail to [${ERROR_MAIL}]"
        fi
    fi
}

checkHosts() {
    if ping -c 1 $1 >/dev/null 2>&1; then
        UPDATEIP=$(dig +short $1)
        if [ $VERBOSE == 1 ]; then
            printMsg "\"${PRIMARY_FRIENDLY_NAME}\" is responding: ${UPDATEIP}"
        fi
        setState $UPDATEIP "0"
    else
        if [ $VERBOSE == 1 ]; then
            printMsg "\"${PRIMARY_FRIENDLY_NAME}\" is not reachable, trying secondary."
        fi
        writeLog "\"${PRIMARY_FRIENDLY_NAME}\" is not reachable, trying secondary."

        if ping -c 1 $2 >/dev/null; then
            UPDATEIP=$(dig +short $2)
            if [ $VERBOSE == 1 ]; then
                printMsg "\"${SECONDARY_FRIENDLY_NAME}\" is responding: ${UPDATEIP}"
            fi
            setState $UPDATEIP "0"
        else
            if [ $VERBOSE == 1 ]; then
                printMsg "${SECONDARY_FRIENDLY_NAME} is not reachable as well, aborting."
            fi
            writeLog "\"${SECONDARY_FRIENDLY_NAME}\" is not reachable as well, aborting."

            TRIES=$((TRIES + 1))
            setState $UPDATEIP $TRIES
            sendMail
            ERROR=1 && exitWith "No hosts are reachable! Tried: ${TRIES}/${MAX_RETRIES}"
        fi
    fi
}

updateDynu() {
    if [ $DRYRUN == 1 ]; then
        printMsg "DRY: curl -s \"https://${DYNU_USERNAME}:${DYNU_PASSWORD}@${DYNU_URL}?hostname=$DYNU_HOSTNAME&myip=${UPDATEIP}\""
    else
        response=$(curl -s "https://${DYNU_USERNAME}:${DYNU_PASSWORD}@${DYNU_URL}?hostname=$DYNU_HOSTNAME&myip=${UPDATEIP}" | head -n 1 | cut -d $' ' -f2)
        validateDynuUpdate $response
    fi
}

checkDynuUpdate() {
    if [ $ERROR == 1 ]; then
        exitWith "ERROR: Could not update IP address for: \"${DYNU_HOSTNAME}\""
    else
        if [ $(expr $UPDATEIP = $LASTIP) -eq 1 ]; then
            if [ $FORCE == 1 ]; then
                updateDynu
            else
                printMsg "IP unchanged, no update needed! But if you want to force an update, use the [-f | --force] flag."
            fi
        else
            updateDynu
        fi
    fi
}

validateDynuUpdate() {
    # https://www.dynu.com/en-US/DynamicDNS/IP-Update-Protocol#responsecode
    case $1 in
    "unknown")
        printMsg "API-Response: Unknown error, IP unchanged. See logs for more information."
        writeLog "[${1}] This response code is returned if an invalid 'request' is made to the API server. This 'response code' could be generated as a result of badly formatted parameters as well so parameters must be checked for validity by the client before they are passed along with the 'request'. "
        ;;

    $UPDATEIP)
        printMsg "API-Response: Good, IP updated to: ${UPDATEIP}."
        writeLog "[good] IP updated to: ${UPDATEIP}"
        ;;

    "badauth")
        printMsg "API-Response: Failed authentication. See logs for more information."
        writeLog "[${1}] This response code is returned in case of a failed authentication for the 'request'. Please note that sending across an invalid parameter such as an unknown domain name can also result in this 'response code'. The client must advise the user to check all parameters including authentication parameters to resolve this problem. "
        ;;

    "servererror")
        printMsg "API-Response: Dynu server error, IP unchanged. See logs for more information."
        writeLog "[${1}] This response code is returned in cases where an error was encountered on the server side. The client may send across the request again to have the 'request' processed successfully. "
        ;;

    "nochg")
        printMsg "API-Response: no change, IP unchanged. See logs for more information."
        writeLog "[${1}] This response code is returned in cases where IP address was found to be unchanged on the server side. "
        ;;

    "notfqdn")
        printMsg "API-Response: invalid hostname, IP unchanged. See logs for more information."
        writeLog "[${1}] This response code is returned in cases where the hostname is not a valid fully qualified hostname. "
        ;;

    "numhost")
        printMsg "API-Response: too many hostnames, IP unchanged. See logs for more information."
        writeLog "[${1}] This response code is returned in cases where too many hostnames(more than 20) are specified for the update process. "
        ;;

    "abuse")
        printMsg "API-Response: possible abuse detected, IP unchanged. See logs for more information."
        writeLog "[${1}] This response code is returned in cases where update process has failed due to abusive behaviour. "
        ;;

    "911")
        printMsg "API-Response: Dynu server error, IP unchanged. See logs for more information. (+10 Minutes Cooldown)"
        writeLog "[${1}] This response code is returned in cases where the update is temporarily halted due to scheduled maintenance. Client must respond by suspending update process for 10 minutes upon receiving this response code. "
        TIMESTAMP=$(date -d "+10 minutes" +%s)
        setState $UPDATEIP "3" $TIMESTAMP
        ;;

    "dnserr")
        printMsg "API-Response: Dynu server error, IP unchanged. See logs for more information."
        writeLog "[${1}] This response code is returned in cases where there was an error on the server side. The client must respond by retrying the update process. "
        ;;

    *) ;;

    esac
}

# INIT

getConfig
validateConfig
getState
checkTries
checkHosts $PRIMARY_FRITZDNS $SECONDARY_FRITZDNS
checkDynuUpdate
