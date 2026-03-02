#!/bin/sh

if [ -x /usr/sbin/qconn ]; then
    echo "---> Starting qconn"
    waitfor /dev/ptyp0 4
    waitfor /dev/socket 4
    /usr/sbin/qconn port=8000
fi

if [ -x /usr/sbin/sshd ]; then
    echo "---> Starting sshd"
    /usr/sbin/sshd
fi

if [ -x /opt/score/autostart.sh ]; then
    echo "---> Executing /opt/score/autostart.sh"
    sh /opt/score/autostart.sh &
fi
