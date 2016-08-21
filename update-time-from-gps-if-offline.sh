#!/bin/sh

# the GPS serial device file
GPSDEVICE=/dev/ttyUSB0

## CAUTION: This is hard-coded!
stty 4800 -F $GPSDEVICE

LOGFILE=/var/log/gpstime.log

# logging function
# this overwrites the logger command
# uncomment this function definition to use the logger command and
# log to syslog.
logger () {
    MESSAGE=$@
    if ! echo "$(date +'%F %T'):$MESSAGE" >> "$LOGFILE";then
        echo >&2 "can't write this to logfile '$LOGFILE':"
    fi
    echo >&2 "$MESSAGE" # print message to STDERR as well
    }


# function to read time from device
gpstime () {
    GPSTIMEOUT=5 # seconds to wait for gps time
    DEVICE=$1 # first argument is gps device file
    if test -r "$DEVICE";then
        if timeout $GPSTIMEOUT perl -ne 'if(@time=m/^\$(?:GPRMC|GPGGA),(\d{2})(\d{2})(\d{2})\.\d+,.*,(\d\d)(\d\d)(\d\d),.*$/){print join("-",@time[5,4,3])," ",join(":",@time[0,1,2])," UTC","\n";exit}' < $DEVICE;then
            return 0 # it worked
        else
            return 1 # gps didn't give time.
        fi
    else
        return 2 # gps file not readable
    fi
    }

# test if we have internet
online () {
    PINGTIMEOUT=5 # seconds to wait for ping answer
    SERVER=8.8.8.8 # ping google
    ping -c1 -W$PINGTIMEOUT $SERVER > /dev/null 2>&1
    }

# check if we are root
if test "$(id -u)" -ne "0";then
    logger "Changing the date can only be done with root privileges. Run this script as root!"
    exit 5
fi

# First, check if we are online
if online;then
    logger "We're online. Assuming the time is correct. Exiting."
    exit 1
else
    GPSTIME=$( gpstime "$GPSDEVICE" )
    logger "current GPS time: $GPSTIME"
    if test $? -eq 0;then # gps time reading worked
        # perform sanity check
        CURTIME=$(date) # current time
        CURTIMESECS=$(date +%s)
        if test $(date --date="$GPSTIME" +%s) -ge $CURTIMESECS;then
            logger "setting system time to GPS time"
            if date -s "$GPSTIME";then # set the date!
                logger "system time set successfully!"
                exit 0
            else
                logger "problem setting system time."
                exit 2
            fi
        else
            logger "time read from GPS device '$GPSDEVICE' ($GPSTIME) is earlier than system date ($CURTIME). Seems like a GPS data parsing error or an already up-to-date system time to me, I won't touch the system time. Exiting."
            exit 3
        fi
    else
        logger "problem reading time from GPS device '$GPSDEVICE'. Exiting."
        exit 4
    fi
    
fi

