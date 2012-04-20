openbsd-dum
===========
OpenBSD Data Usage Meter

This is a script for OpenBSD that will report daily data consumption in MB as well as the total for the month based on data from netstat. It is intended to be called from cron, which will email the report to root or whoever root is aliased to in /etc/mail/aliases. 


By default it logs to /var/log/odum/odum.log in the following format:

DATE|BYTES-IN|BYTES-OUT


Example Log Entry:

2012-04-01|164584809291|162057262018


Example Output:

Today's Data Usage In: 713  MB
Today's Data Usage Out: 63 MB
This Month's Data Usage In: 2415 MB
This Month's Data Usage Out: 709 MB


Usage:

sudo crontab -e

        0       0       *       *       *       /root/bin/odum/odum.sh



