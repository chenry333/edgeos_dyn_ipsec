#!/bin/bash
echo '* * * * * root /config/scripts/strongswan/strongswan_setup.sh > /var/log/strongswan_setup.log 2>&1' > /etc/cron.d/strongswan_setup
