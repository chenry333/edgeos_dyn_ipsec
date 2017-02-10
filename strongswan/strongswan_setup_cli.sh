#!/bin/vbash -e

# Set up the Vyatta environment
source /opt/vyatta/etc/functions/script-template
OPRUN=/opt/vyatta/bin/vyatta-op-cmd-wrapper
CFGRUN=/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper
alias begin='${CFGRUN} begin'
alias commit='${CFGRUN} commit'
alias delete='${CFGRUN} delete'
alias end='${CFGRUN} end'
alias save='${CFGRUN} save'
alias set='${CFGRUN} set'
alias show='${CFGRUN} show'


### config section ###
source /config/scripts/strongswan/strongswan_setup.conf

# lookup local ip
LOCAL_IP=`host -t A $LOCAL_HOST |grep 'has address' |awk '{print $4}'`

### function to rewrite configuration from scratch ###
function rewrite_config {


    # delete all current peers
    begin

    PEERS_TO_DEL=$(show vpn ipsec site-to-site peer  |grep peer |awk '{print $2}')
    echo ${PEERS_TO_DEL}
    for PEER in ${PEERS_TO_DEL[@]}; do
        delete vpn ipsec site-to-site peer ${PEER}
    done

    # delete all ESP groups
    ESP_GROUPS_TO_DEL=$(show vpn ipsec esp-group |grep esp-group |grep '{' |awk '{print $2}')
    for ESP_GROUP in ${ESP_GROUPS_TO_DEL[@]}; do
        delete vpn ipsec esp-group ${ESP_GROUP}
    done

    # delete all ike-groups
    IKE_GROUPS_TO_DEL=$(show vpn ipsec ike-group  |grep 'ike-group' |grep '{' |awk '{print $2}')
    for IKE_GROUP in ${IKE_GROUPS_TO_DEL[@]}; do
        delete vpn ipsec ike-group ${IKE_GROUP}
    done

    # add IKE/ESP groups
    set vpn ipsec esp-group ${ESP_GROUP_NAME} proposal 1 encryption aes256
    set vpn ipsec esp-group ${ESP_GROUP_NAME} proposal 1 hash sha1
    set vpn ipsec ike-group ${IKE_GROUP_NAME} proposal 1 dh-group 14
    set vpn ipsec ike-group ${IKE_GROUP_NAME} proposal 1 encryption aes256 
    set vpn ipsec ike-group ${IKE_GROUP_NAME} proposal 1 hash sha1
   
    
    # iterate all defined REMOTES
    for REMOTE in ${REMOTES[@]}; do
        # extract HOST, PSK and SUBNET
        REMOTE_HOST=${REMOTE%%;*}
        REMOTE_PSK=${REMOTE#*;};REMOTE_PSK=${REMOTE_PSK%;*}
        REMOTE_SUBNET=${REMOTE##*;}
        # grab IP for REMOTE_HOST
        REMOTE_IP=`host -t A ${REMOTE_HOST} |grep 'has address' |awk '{print $4}'`
    
        echo "adding connection: ${LOCAL_HOST}:${LOCAL_IP} <-> ${REMOTE_HOST}:${REMOTE_IP} ${REMOTE_PSK}"
    
        # add peer configuration 
        set vpn ipsec site-to-site peer ${REMOTE_IP}
        set vpn ipsec site-to-site peer ${REMOTE_IP} authentication mode pre-shared-secret
        set vpn ipsec site-to-site peer ${REMOTE_IP} authentication pre-shared-secret ${REMOTE_PSK}
        set vpn ipsec site-to-site peer ${REMOTE_IP} connection-type initiate
        set vpn ipsec site-to-site peer ${REMOTE_IP} description "${REMOTE_HOST} network"
        set vpn ipsec site-to-site peer ${REMOTE_IP} ike-group ${IKE_GROUP_NAME}
        set vpn ipsec site-to-site peer ${REMOTE_IP} local-address any
        set vpn ipsec site-to-site peer ${REMOTE_IP} tunnel 1 esp-group ${ESP_GROUP_NAME}
        set vpn ipsec site-to-site peer ${REMOTE_IP} tunnel 1 local prefix ${LOCAL_SUBNET}
        set vpn ipsec site-to-site peer ${REMOTE_IP} tunnel 1 remote prefix ${REMOTE_SUBNET}
    done

    commit
    save
    end

    echo "configuration updated!"
    exit 0
}

### check total tunnel count for running vs defined ###
NUM_REMOTES=${#REMOTES[@]}
NUM_CONFIGURED_REMOTES=$(sudo grep -c "^conn peer" /etc/ipsec.conf)

if [[ ${NUM_REMOTES} -ne ${NUM_CONFIGURED_REMOTES} ]]; then
    echo "Running config tunnels does not match defined tunnels... updating config"
    rewrite_config
fi


### check each defined tunnel exists ###
for REMOTE in ${REMOTES[@]}; do
    # extract HOST
    REMOTE_HOST=${REMOTE%%;*}
    REMOTE_IP=`host -t A ${REMOTE_HOST} |grep 'has address' |awk '{print $4}'`
    if [[ $(sudo grep -c "right=${REMOTE_IP}" /etc/ipsec.conf) -ne 1 ]]; then
        echo "Tunnel for ${REMOTE_HOST}:${REMOTE_IP} does note exist... updating config"
        rewrite_config
    fi
done

# Running config is up to date
echo "Running confinguration matches defined configuration.  Exiting"
exit 0
