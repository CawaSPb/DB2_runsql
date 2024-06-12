#!/bin/bash

# Define rows limit
ROWS_LIMIT=20

# Check if 'silent mode' key is set
SILENT_MODE=0
if [[ $1 == "-s" ]]; then
    SILENT_MODE=1
    shift
fi

SCRIPTNAME=$1
SCRIPTFILENAME="${SCRIPTNAME%.*}"

LOGFILELINES=0
if [ -f ${SCRIPTFILENAME}.out ]; then
    LOGFILELINES=$(wc -l < ${SCRIPTFILENAME}.out|sed 's/ *//')
fi

db2 -c- -v -s -t -f "${SCRIPTNAME}" -l "${SCRIPTFILENAME}.log" -z "${SCRIPTFILENAME}.out" -m
RC=$?


if [ $RC -lt 4 ]; then
#   ROWS_MODIFIED=`db2 -x -c- "select ROWS_DELETED + ROWS_INSERTED + ROWS_UPDATED from table(MON_GET_UNIT_OF_WORK(mon_get_application_handle(),-1))"`
    ROWS_MODIFIED=`tail -n +${LOGFILELINES}  ${SCRIPTFILENAME}.out|egrep "^  Number of rows affected : \d*"|awk '{n += $6}; END{print n}'`

    if [[ SILENT_MODE -ne 1 && $ROWS_MODIFIED -gt $ROWS_LIMIT ]]; then
#       CAPTCHA=$(( RANDOM%1000 ))
        CAPTCHA=$(( `od -An -N2 -i /dev/random` % 1000))

        printf "\nOverall number of rows affected : %-d" ${ROWS_MODIFIED} |tee -a ${SCRIPTFILENAME}.out
        printf "\nPlease confirm the update by typing '%-d'\n" ${CAPTCHA} |tee -a ${SCRIPTFILENAME}.out

        read ANSWER
        printf "%s\n" ${ANSWER} >> ${SCRIPTFILENAME}.out
        if [[ _${CAPTCHA} == _${ANSWER} ]]; then
            printf "\nModification is confirmed.\n\n" |tee -a ${SCRIPTFILENAME}.out
        else
            printf "\nModification is not confirmed, the answer is '${ANSWER}'.\n!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! CHANGES WILL BE ROLLED BACK !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n\n" |tee -a ${SCRIPTFILENAME}.out
            db2 -c- -v -l "${SCRIPTFILENAME}.log" -z "${SCRIPTFILENAME}.out"  rollback

            exit -2
        fi
    fi

    db2 -c- -v -l "${SCRIPTFILENAME}.log" -z "${SCRIPTFILENAME}.out"  commit
    exit 0
else
    db2 -c- -v -l "${SCRIPTFILENAME}.log" -z "${SCRIPTFILENAME}.out"  rollback
    exit -1
fi

