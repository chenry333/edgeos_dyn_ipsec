# edgeos_dyn_ipsec
IPSec configuration for EdgeOS.  Handles dynamic updating

After updating to EdgeOS 1.9.x we noticed that our IPSec tunnels were no longer working.  After
troubleshooting we discovered that using hostnames in the site-to-site ipsec tunnel configuration
was resulting in a `no shared key found` error as it could not match the PSK with the remote.

The following script + cron job will automatically monitor your ipsec configuration and keep it in sync
with DNS hsotnames as things change.

Combined with the DynDNS service built into EdgeOS you can automatically reconfigure things if you encoutner an IP change

- strongswan_setup_cli.sh: uses internal CLI commands to tear down and re-setup tunnels
- strongswan_setup_files.sh: manually generates ipsec configuration files
- strongswan_setup.sh: path that is executed by cron job.  Should sym link to _cli.sh or _files.sh

strongswan_cron.sh will install a cron job at boot that will execute the strongswan_setup.sh
command every minute and log to /var/log/strongswan_setup.log

If changes are detected the ipsec configuration will be updated and the service restarted
