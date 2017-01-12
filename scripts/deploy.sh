#!/bin/bash -x
function usage()
 {
    echo "INFO:"
    echo "Usage: deploy.sh [user]"
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
  echo "${BASH_SCRIPT}" "${mess}" >> /tmp/${BASH_SCRIPT}.log
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

function install_packages()
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
}

function install_docker()
{
    log "Install Docker ..."

    curl -fsSL https://test.docker.com/ | sh

    log "activate experimental flag"
    echo '{ "experimental": true }' > /etc/docker/daemon.json

    log "restarting service"
    service docker restart

    usermod -aG docker "${ADMIN_USER}"

}

function install_docker_compose()
{
  curl -L "https://github.com/docker/compose/releases/download/1.9.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  chmod +x /usr/local/bin/docker-compose
  docker-compose --version
}

function pull_images()
{
  log "pulling commander..."
  docker pull herveleclerc/azure-commander
}

function pull_compose()
{
  log "pulling compose files"
  mkdir -p "${ADMIN_HOME}"/docker/{consul,envconsul}
  curl -fsSL "$REPO/docker/consul/docker-compose.yml" -o "${ADMIN_HOME}/docker/consul/docker-compose.yml"
  chown -R  "${ADMIN_USER}" "${ADMIN_HOME}/docker"
  docker-compose -f "${ADMIN_HOME}/docker/consul/docker-compose.yml" up -d
}

function put_keys()
{
  curl -X PUT -d @${ADMIN_HOME}/.ssh/id_rsa http://localhost:8500/v1/kv/ssh/id_rsa
  curl -X PUT -d @${ADMIN_HOME}/.ssh/id_rsa.pub http://localhost:8500/v1/kv/ssh/id_rsa.pub
}


function generate_sshkeys()
{
  log "Generating ssh keys..."
  echo -e 'y\n'|ssh-keygen -b 4096 -f id_rsa -t rsa -q -N ''
}

function fix_etc_hosts()
{
  log "Add hostame and ip in hosts file ..."
  #IP=$(ip addr show eth0 | grep inet | grep -v inet6 | awk '{ print $2; }' | sed 's?/.*$??')
  HOST=$(hostname)
  echo "${IP}" "${HOST}" >>  "${HOST_FILE}"
}

function myip()
{
  IP=$(ip addr show eth0 | grep inet | grep -v inet6 | awk '{ print $2; }' | sed 's?/.*$??')
  echo "${IP}"
}

log "Execution of Install Script from CustomScript ..."

## Variables

BASH_SCRIPT="${0}"
ADMIN_USER="${1}"
REPO="${2}"

TERM=xterm
HOST_FILE="/etc/hosts"

IP=$(myip)
CWD="$(cd -P -- "$(dirname -- "$0")" && pwd -P)"
ADMIN_HOME=$(getent passwd "$ADMIN_USER" | cut -d: -f6)

export ADMIN_USER ADMIN_HOME IP TERM REPO BASH_SCRIPT
log "1:$ADMIN_USER 2:$ADMIN_HOME 3:$IP 4:$TERM 5:$REPO 6:$BASH_SCRIPT"

log "CustomScript Directory is ${CWD}"

##
fix_etc_hosts
install_packages
generate_sshkeys
ssh_config
install_docker
install_docker_compose
pull_compose
pull_images
put_keys

log "Success : End of Execution of Install Script from CustomScript"

exit 0