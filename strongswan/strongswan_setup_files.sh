#!/bin/bash
set -e
RUN=/opt/vyatta/bin/vyatta-op-cmd-wrapper
MD5_STRONGSWAN_CONF=$(sudo md5sum /etc/ipsec.conf |awk '{print $1}')
MD5_STRONGSWAN_PSK=$(sudo md5sum /etc/ipsec.secrets |awk '{print $1}')
STRONGSWAN_CONF_STAGE=$(mktemp)
STRONGSWAN_PSK_STAGE=$(mktemp)

### config section ###
source /config/scripts/strongswan/strongswan_setup.conf

# lookup local ip address
LOCAL_IP=`host -t A $LOCAL_HOST |grep 'has address' |awk '{print $4}'`


# add default config header to strongswan conf
cat >${STRONGSWAN_CONF_STAGE} <<EOL
config setup

conn %default
        keyexchange=ikev1
EOL

# iterate all defined REMOTES
for REMOTE in ${REMOTES[@]}; do
    # extract HOST, PSK and SUBNET
    REMOTE_HOST=${REMOTE%%;*}
    REMOTE_PSK=${REMOTE#*;};REMOTE_PSK=${REMOTE_PSK%;*}
    REMOTE_SUBNET=${REMOTE##*;}
    # grab IP for REMOTE_HOST
    REMOTE_IP=`host -t A ${REMOTE_HOST} |grep 'has address' |awk '{print $4}'`

    echo "adding connection to staging config: ${LOCAL_HOST}:${LOCAL_IP} <-> ${REMOTE_HOST}:${REMOTE_IP} ${REMOTE_PSK}"

        cat >>${STRONGSWAN_CONF_STAGE} <<EOL
conn peer-${REMOTE_HOST}-tunnel-1
        left=%any
        leftid=${LOCAL_IP}
        right=${REMOTE_IP}
        rightid=%any
        leftsubnet=${LOCAL_SUBNET}
        rightsubnet=${REMOTE_SUBNET}
        ike=aes256-sha1-modp2048!
        keyexchange=ikev1
        ikelifetime=28800s
        esp=aes256-sha1-modp2048!
        keylife=3600s
        rekeymargin=540s
        type=tunnel
        compress=no
        authby=secret
        auto=route
        keyingtries=%forever
#conn ${REMOTE_HOST}-tunnel-1
EOL

        echo "${LOCAL_IP} ${REMOTE_IP} : PSK \"${REMOTE_PSK}\"" >> ${STRONGSWAN_PSK_STAGE}
done

# check if our config changed
if [[ $(md5sum ${STRONGSWAN_CONF_STAGE} |awk '{print $1}') != ${MD5_STRONGSWAN_CONF} ]] || \
   [[ $(md5sum ${STRONGSWAN_PSK_STAGE} |awk '{print $1}') != ${MD5_STRONGSWAN_PSK} ]]; then
    echo "generated configurations do not match in place configs... overwriting"
    sudo cp -v ${STRONGSWAN_CONF_STAGE} /etc/ipsec.conf
    sudo cp -v ${STRONGSWAN_PSK_STAGE} /etc/ipsec.secrets
    ${RUN} restart vpn
# no configuration change
else
    echo "generated configurations and in place configurations match."
    echo "config md5sum: ${MD5_STRONGSWAN_CONF}"
    echo "secrets md5sum: ${MD5_STRONGSWAN_PSK}"
fi

# clean up tmp files
rm -f ${STRONGSWAN_CONF_STAGE}
rm -f ${STRONGSWAN_PSK_STAGE}
