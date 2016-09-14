#!/bin/sh

# VARIABLES

#####################################################################
# Change the following to whatever network card you wish to monitor #
								    #
NIC=vr0								    #
 								    #
#####################################################################

PATH="/var/log/odum"
LOGFILE="odum.log"

#Grab today's date as well as the current in/out bytes as displyed by /usr/bin/netstat
CURRENT_DAY=`/bin/date +%d`
CURRENT_MONTH=`/bin/date +%m`
CURRENT_YEAR=`/bin/date +%Y`
CURRENT_BYTES_IN=`/usr/bin/netstat -b -n -I $NIC | /usr/bin/grep $NIC | /usr/bin/tail -n1 | /usr/bin/awk '{print $5}'`
CURRENT_BYTES_OUT=`/usr/bin/netstat -b -n -I $NIC | /usr/bin/grep $NIC | /usr/bin/tail -n1 | /usr/bin/awk '{print $6}'`


# FUNCTIONS
report() {
  #Grab first in/out bytes logged for the month
  first_line=`/usr/bin/head -n1 $PATH/$LOGFILE`
  START_BYTES_IN=`/bin/echo $first_line | /usr/bin/cut -d"|" -f 2`
  START_BYTES_OUT=`/bin/echo $first_line | /usr/bin/cut -d"|" -f 3`

  #Grab the last in/out bytes logged for the month
  last_line=`/usr/bin/tail -n1 $PATH/$LOGFILE`
  YESTERDAY_BYTES_IN=`/bin/echo $last_line | /usr/bin/cut -d"|" -f 2`
  YESTERDAY_BYTES_OUT=`/bin/echo $last_line | /usr/bin/cut -d"|" -f 3`

  #Test if a reboot happened or netstat rolled over and calculate appropriately
  if [ "$CURRENT_BYTES_IN" -lt  "$YESTERDAY_BYTES_IN" ]; then
    CURRENT_DAY_IN="$CURRENT_BYTES_IN"
    CURRENT_DAY_OUT="$CURRENT_BYTES_OUT"
    CURRENT_MONTH_IN=`/bin/echo "$CURRENT_BYTES_IN + $YESTERDAY_BYTES_IN" | /usr/bin/bc`
    CURRENT_MONTH_OUT=`/bin/echo "$CURRENT_BYTES_OUT + $YESTERDAY_BYTES_OUT" | /usr/bin/bc`

    #fix report by outputting total cumulative value
    CURRENT_REPORT_IN=$CURRENT_MONTH_IN
    CURRENT_REPORT_OUT=$CURRENT_MONTH_OUT
  else
    #Calculate current day/month in/out bytes
    CURRENT_DAY_IN=`/bin/echo "$CURRENT_BYTES_IN - $YESTERDAY_BYTES_IN" | /usr/bin/bc`
    CURRENT_DAY_OUT=`/bin/echo "$CURRENT_BYTES_OUT - $YESTERDAY_BYTES_OUT" | /usr/bin/bc`
    CURRENT_MONTH_IN=`/bin/echo "$CURRENT_BYTES_IN - $START_BYTES_IN" | /usr/bin/bc`
    CURRENT_MONTH_OUT=`/bin/echo "$CURRENT_BYTES_OUT - $START_BYTES_OUT" | /usr/bin/bc`

    #report today's (cumulative value)
    CURRENT_REPORT_IN=$CURRENT_BYTES_IN
    CURRENT_REPORT_OUT=$CURRENT_BYTES_OUT
  fi
  
    #print out results in MB
    /bin/echo "Today's Data Usage In: `/bin/echo "$CURRENT_DAY_IN/1024/1024" | /usr/bin/bc`  MB"
    /bin/echo "Today's Data Usage Out: `/bin/echo "$CURRENT_DAY_OUT/1024/1024" | /usr/bin/bc` MB"
    /bin/echo "This Month's Data Usage In: `/bin/echo "$CURRENT_MONTH_IN/1024/1024" | /usr/bin/bc` MB"
    /bin/echo "This Month's Data Usage Out: `/bin/echo "$CURRENT_MONTH_OUT/1024/1024" | /usr/bin/bc` MB"
  
  log CURRENT_REPORT_IN CURRENT_REPORT_OUT

}

log_rotate() {
  #Create new log if new month and back up old log
  #NOTE: THIS WILL NEVER DELETE LOGS
  if [ $CURRENT_MONTH != 01 ]; then
    #If not January, subtract 1 from month
    /bin/mv $PATH/$LOGFILE $PATH/$LOGFILE.$(($CURRENT_YEAR))-$(($CURRENT_MONTH - 1))
  else
    #otherwise subtract 1 from the year and append 12 for month of December
    /bin/mv $PATH/$LOGFILE $PATH/$LOGFILE.$(($CURRENT_YEAR - 1))-12
  fi

  touch $PATH/$LOGFILE

  #Remove logs older than 1 year old
  if [ `/bin/ls $PATH/$LOGFILE.$(($CURRENT_YEAR - 2))-* 2>/dev/null | /usr/bin/wc -l` != 0 ]; then
    echo "Removing old files"
    /bin/rm $PATH/$LOGFILE.$(($CURRENT_YEAR - 2))-*
  fi
}

log(){
  #Log current data if not already logged for the day
  if [ $CURRENT_DAY != "`/usr/bin/tail -n1 $PATH/$LOGFILE | /usr/bin/cut -d"-" -f3 | /usr/bin/cut -d"|" -f1`" ]; then
      /bin/echo "`/bin/date +%Y-%m-%d`|$CURRENT_REPORT_IN|$CURRENT_REPORT_OUT" >> $PATH/$LOGFILE
  fi
}

# LOGIC
#Create the logging directory if it doesn't exist
if [ ! -d $PATH ]; then
    /bin/mkdir -p $PATH
    /usr/bin/touch $PATH/$LOGFILE
fi

#Check if log exists and rotate log if server was shutdown during a month change
if [ -e $PATH/$LOGFILE ] && [ -n "`/bin/cat $PATH/$LOGFILE`" ]; then
        if [ $CURRENT_MONTH != `/usr/bin/head -n1 $PATH/$LOGFILE | /usr/bin/cut -d"-" -f2` ]; then
                log_rotate
        fi
fi

#Check if log exists and has data report on metrics
if [ -e $PATH/$LOGFILE ] && [ -n "`/bin/cat $PATH/$LOGFILE`" ]; then
    report
else
    echo "No bandwidth data to report on."
    echo "This must be the first run "
    CURRENT_REPORT_IN=$CURRENT_BYTES_IN
    CURRENT_REPORT_OUT=$CURRENT_BYTES_OUT
    log CURRENT_REPORT_IN CURRENT_REPORT_OUT

fi

