#!/bin/bash -x
function usage()
{
    echo "INFO:"
    echo "Usage: deploy-node.sh index admin #nodes subnet vmname"
}

error_log()
{
    if [ "$?" != "0" ]; then
        log "$1"
        log "Deployment ends with an error" "1"
        exit 1
    fi
}

function log()
{

  mess="$(hostname): $1"

  logger -t "${BASH_SCRIPT}" "${mess}"

}

function ssh_config()
{
  log "Configure ssh..."
  log "Create ssh configuration for ${ADMIN_USER}"

  printf "Host *\n  user %s\n  StrictHostKeyChecking no\n" "${ADMIN_USER}"  >> "${ADMIN_HOME}/.ssh/config"

  error_log "Unable to create ssh config file for user ${ADMIN_USER}"

  log "Copy generated keys..."

  cp id_rsa "${ADMIN_HOME}/.ssh/id_rsa"
  error_log "Unable to copy id_rsa key to $ADMIN_USER .ssh directory"

  cp id_rsa.pub "${ADMIN_HOME}/.ssh/id_rsa.pub"
  error_log "Unable to copy id_rsa.pub key to $ADMIN_USER .ssh directory"

  cat "${ADMIN_HOME}/.ssh/id_rsa.pub" >> "${ADMIN_HOME}/.ssh/authorized_keys"
  error_log "Unable to copy $ADMIN_USER id_rsa.pub to authorized_keys "

  chmod 700 "${ADMIN_HOME}/.ssh"
  error_log "Unable to chmod $ADMIN_USER .ssh directory"

  chown -R "${ADMIN_USER}:" "${ADMIN_HOME}/.ssh"
  error_log "Unable to chown to $ADMIN_USER .ssh directory"

  chmod 400 "${ADMIN_HOME}/.ssh/id_rsa"
  error_log "Unable to chmod $ADMIN_USER id_rsa file"

  chmod 644 "${ADMIN_HOME}/.ssh/id_rsa.pub"
  error_log "Unable to chmod $ADMIN_USER id_rsa.pub file"

  chmod 400 "${ADMIN_HOME}/.ssh/authorized_keys"
  error_log "Unable to chmod $ADMIN_USER authorized_keys file"
}

function ssh_config_root()
{

  log "Create ssh configuration for root"

  printf "Host *\n  user %s\n  StrictHostKeyChecking no\n" "root"  >> "/root/.ssh/config"

  error_log "Unable to create ssh config file for user root"

  log "Copy generated keys..."

  cp id_rsa "/root/.ssh/id_rsa"
  error_log "Unable to copy id_rsa key to root .ssh directory"

  cp id_rsa.pub "/root/.ssh/id_rsa.pub"
  error_log "Unable to copy id_rsa.pub key to root .ssh directory"

  cat "/root/.ssh/id_rsa.pub" >> "/root/.ssh/authorized_keys"
  error_log "Unable to copy root id_rsa.pub to authorized_keys "

  chmod 700 "/root/.ssh"
  error_log "Unable to chmod root .ssh directory"

  chown -R "root:" "/root/.ssh"
  error_log "Unable to chown to root .ssh directory"

  chmod 400 "/root/.ssh/id_rsa"
  error_log "Unable to chmod root id_rsa file"

  chmod 644 "/root/.ssh/id_rsa.pub"
  error_log "Unable to chmod root id_rsa.pub file"

  chmod 400 "/root/.ssh/authorized_keys"
  error_log "Unable to chmod root authorized_keys file"
}

function install_docker()
{
    log "Update System ..."
    until apt-get --yes update
    do
      log "Lock detected on apt-get while install Try again..."
      sleep 2
    done

    log "Install software-properties-common ..."
    until apt-get --yes install apt-transport-https ca-certificates wget curl unzip jq
    do
      log "Lock detected on apt-get while install Try again..."
      sleep 2
    done

    log "Install Docker ..."

    curl -fsSL https://test.docker.com/ | sh

    usermod -aG docker "${ADMIN_USER}"

}

function install_docker_compose()
{
  curl -L "https://github.com/docker/compose/releases/download/1.9.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  chmod +x /usr/local/bin/docker-compose
  docker-compose --version
}

function register_node()
{
   log "register node to consul"
   curl -X PUT -d "${IP}" http://${IPhc}:8500/v1/kv/nodes/${INDEX}/ip
   curl -X PUT -d "0" http://${IPhc}:8500/v1/kv/nodes/${INDEX}/state
   curl -X PUT -d "${nodeVmName}" http://${IPhc}:8500/v1/kv/nodes/${INDEX}/hostname
}

function get_sshkeys()
 {

    log "Get ssh keys from Consul"
    curl -s "http://${IPhc}:8500/v1/kv/ssh/id_rsa" | jq -r '.[0].Value' | base64 --decode > id_rsa
    error_log "Fails to Get id_rsa"
    curl -s "http://${IPhc}:8500/v1/kv/ssh/id_rsa.pub" | jq -r '.[0].Value' | base64 --decode > id_rsa.pub
    error_log "Fails to Get id_rsa"
}

function fix_etc_hosts()
{
  log "Add hostame and ip in hosts file ..."
  #IP=$(ip addr show eth0 | grep inet | grep -v inet6 | awk '{ print $2; }' | sed 's?/.*$??')
  HOST=$(hostname)
  echo "${IP}" "${HOST}" >> "${HOST_FILE}"
}

function myip()
{
  IP=$(ip addr show eth0 | grep inet | grep -v inet6 | awk '{ print $2; }' | sed 's?/.*$??')
  echo "${IP}"
}

function activate_swarm()
{
  if [ "${INDEX}" = "1" ];then
    token=$(docker swarm init | awk '/--token/{print $2;}')
    curl -X PUT -d "${token}" http://${IPhc}:8500/v1/kv/swarm/token
  else
    token=$(curl -s "http://${IPhc}:8500/v1/kv/swarm/token" | jq -r '.[0].Value')
    ipmanager=$(curl -s "http://${IPhc}:8500/v1/kv/nodes/1/ip" | jq -r '.[0].Value')
    docker swarm join --token "${token}" "${ipmanager}:2377"
  fi
}

log "Execution of Install Script from CustomScript ..."

## Variables

BASH_SCRIPT="${0}"
INDEX="${1}"
ADMIN_USER="${2}"
numberOfNodes="${3}"
nodeSubnetRoot="${4}"
nodeVmName="${5}"
IPhc="${6}"

TERM=xterm
IP=$(myip)
HOST_FILE="/etc/hosts"

CWD="$(cd -P -- "$(dirname -- "$0")" && pwd -P)"

ADMIN_HOME=$(getent passwd "$ADMIN_USER" | cut -d: -f6)

export ADMIN_USER ADMIN_HOME IP TERM INDEX numberOfNodes nodeSubnetRoot IPhc BASH_SCRIPT

echo "1:$ADMIN_USER 2:$ADMIN_HOME 3:$IP 4:$TERM 5:$INDEX 6:$numberOfNodes 7:$nodeSubnetRoot 8:$IPhc 9:$BASH_SCRIPT"

log "CustomScript Directory is ${CWD}"

##
env
##

fix_etc_hosts
register_node
get_sshkeys
ssh_config
ssh_config_root
install_docker
install_docker_compose
activate_swarm

log "Success : End of Execution of Install Script from CustomScript"

exit 0
