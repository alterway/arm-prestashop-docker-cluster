#!/bin/bash
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
}

function ssh_config()
{
  log "Configure ssh..."
  log "Create ssh configuration for ${ADMIN_USER}"

  printf "Host *\n  user %s\n  StrictHostKeyChecking no\n" "${ADMIN_USER}"  >> "/home/${ADMIN_USER}/.ssh/config"

  error_log "Unable to create ssh config file for user ${ADMIN_USER}"

  log "Copy generated keys..."

  cp id_rsa "/home/${ADMIN_USER}/.ssh/id_rsa"
  error_log "Unable to copy id_rsa key to $ADMIN_USER .ssh directory"

  cp id_rsa.pub "/home/${ADMIN_USER}/.ssh/id_rsa.pub"
  error_log "Unable to copy id_rsa.pub key to $ADMIN_USER .ssh directory"

  cat "/home/${ADMIN_USER}/.ssh/id_rsa.pub" >> "/home/${ADMIN_USER}/.ssh/authorized_keys"
  error_log "Unable to copy $ADMIN_USER id_rsa.pub to authorized_keys "

  chmod 700 "/home/${ADMIN_USER}/.ssh"
  error_log "Unable to chmod $ADMIN_USER .ssh directory"

  chown -R "${ADMIN_USER}:" "/home/${ADMIN_USER}/.ssh"
  error_log "Unable to chown to $ADMIN_USER .ssh directory"

  chmod 400 "/home/${ADMIN_USER}/.ssh/id_rsa"
  error_log "Unable to chmod $ADMIN_USER id_rsa file"

  chmod 644 "/home/${ADMIN_USER}/.ssh/id_rsa.pub"
  error_log "Unable to chmod $ADMIN_USER id_rsa.pub file"

  chmod 400 "/home/${ADMIN_USER}/.ssh/authorized_keys"
  error_log "Unable to chmod $ADMIN_USER authorized_keys file"

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
    until apt-get --yes install apt-transport-https ca-certificates wget curl
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

function pull_images()
{
  docker pull herveleclerc/azure-commander
}

function pull_compose()
{
  mkdir -p "${ADMIN_USER}/docker/{consul,envconsul}"
  curl -fsSL "$REPO/docker/consul/docker-compose.yml" -o "${ADMIN_USER}/docker/consul/docker-compose.yml"
  chown -R  "${ADMIN_USER}" "${ADMIN_USER}/docker"
  docker-compose -f "${ADMIN_USER}/docker/consul/docker-compose.yml" up -d
  chow
}


function generate_sshkeys()
{
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

ADMIN_USER="${1}"
REPO="${2}"

IP=$(myip)
export IP

CWD="$(cd -P -- "$(dirname -- "$0")" && pwd -P)"

log "CustomScript Directory is ${CWD}"

HOST_FILE="/etc/hosts"

##
fix_etc_hosts
generate_sshkeys
ssh_config
install_docker
install_docker_compose
pull_images
pull_compose

log "Success : End of Execution of Install Script from CustomScript"

exit 0