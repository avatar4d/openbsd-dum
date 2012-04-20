#!/bin/sh
 
<< LICENSE 

Modified BSD License

Copyright (c) 2012, Chad M. Gross
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of the Chad M. Gross nor the
      names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL Chad M. Gross BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

LICENSE


<< DISCLAIMER

There are two situations where this script will fail to report properly:

1. When traffic reaches a point that the byte counter of netstat rolls over to zero

2. When the system is shutdown mid-month after it has started logging data. The data
   will continue to log and this can be computed manually if needed. It will start
   working again once the next month starts.

DISCLAIMER


# VARIABLES
PATH="/var/log/odum"
LOGFILE="odum.log"
#Grab today's date as well as the current in/out bytes as displyed by /usr/bin/netstat
CURRENT_DAY=`/bin/date +%d`
CURRENT_MONTH=`/bin/date +%m`
CURRENT_BYTES_IN=`/usr/bin/netstat -b -n -I xl0 | /usr/bin/grep xl0 | /usr/bin/tail -n1 | /usr/bin/awk '{print $5}'`
CURRENT_BYTES_OUT=`/usr/bin/netstat -b -n -I xl0 | /usr/bin/grep xl0 | /usr/bin/tail -n1 | /usr/bin/awk '{print $6}'`


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

    #Calculate current day/month in/out bytes
    CURRENT_DAY_IN=`/bin/echo "$CURRENT_BYTES_IN - $YESTERDAY_BYTES_IN" | /usr/bin/bc`
    CURRENT_DAY_OUT=`/bin/echo "$CURRENT_BYTES_OUT - $YESTERDAY_BYTES_OUT" | /usr/bin/bc` 
    CURRENT_MONTH_IN=`/bin/echo "$CURRENT_BYTES_IN - $START_BYTES_IN" | /usr/bin/bc`
    CURRENT_MONTH_OUT=`/bin/echo "$CURRENT_BYTES_OUT - $START_BYTES_OUT" | /usr/bin/bc`
    
    #print out results in MB
    /bin/echo "Today's Data Usage In: `/bin/echo "$CURRENT_DAY_IN/1024/1024" | /usr/bin/bc`  MB"
    /bin/echo "Today's Data Usage Out: `/bin/echo "$CURRENT_DAY_OUT/1024/1024" | /usr/bin/bc` MB"
    /bin/echo "This Month's Data Usage In: `/bin/echo "$CURRENT_MONTH_IN/1024/1024" | /usr/bin/bc` MB"
    /bin/echo "This Month's Data Usage Out: `/bin/echo "$CURRENT_MONTH_OUT/1024/1024" | /usr/bin/bc` MB" 
}

log_rotate() {
    #Create new log if new month and back up old log
    #NOTE: THIS WILL NEVER DELETE LOGS
    if [ $CURRENT_MONTH != 01 ]; then
        mv $PATH/$LOGFILE $PATH/$LOGFILE.`/bin/date +%Y`-$((`/bin/date +%m` - 1)) #If not January, subtract 1 from month
    else
        mv $PATH/$LOGFILE $PATH/$LOGFILE.`/bin/date +%Y`-12 #otherwise make 12
    fi

}


# LOGIC
#Check if log exists and rotate log if server was shutdown during a month change
if [ -e $PATH/$LOGFILE ] && [ $CURRENT_MONTH != `/usr/bin/head -n1 $PATH/$LOGFILE | /usr/bin/cut -d"-" -f2` ]; then
    log_rotate
fi

#Check if log exists and has data report on metrics
if [ -e $PATH/$LOGFILE ] && [ -n "`/bin/cat $PATH/$LOGFILE`" ]; then
    report
else
    echo "No bandwidth data to report on."
    echo "Either this is the first run or the system was shutdown during a change in month"
fi

#Rotate log if month changed
if [ $CURRENT_DAY == 01 ]; then
    log_rotate
fi

#Create the logging directory if it doesn't exist
if [ ! -d $PATH ]; then
    /bin/mkdir -p $PATH
fi 

#Log current data if not already logged for the day
if [ $CURRENT_DAY != "`/usr/bin/tail -n1 $PATH/$LOGFILE | /usr/bin/cut -d"-" -f3 | /usr/bin/cut -d"|" -f1`" ]; then
    /bin/echo "`/bin/date +%Y-%m-%d`|$CURRENT_BYTES_IN|$CURRENT_BYTES_OUT" >> $PATH/$LOGFILE
fi
