#!/bin/bash
FILE_PATH="config.toml"
if [[ "$@" == "server" ]]; then
  MODE="server"
elif [[ "$@" == "client" ]]; then
  MODE="client"
else
  exec /rathole $@
fi

: > "${FILE_PATH}"
function to_config() {
    echo -e "$1" >> "${FILE_PATH}"
}

function validate_boolean() {
  value="${1,,}"
  if [[ "$value" == "false" ]]; then
    echo "false"
  else
    echo "true"
  fi
}

function create_valid_service() {
    token="SERVICE_TOKEN_${1}"
    name="SERVICE_NAME_${1}"
    type="SERVICE_TYPE_${1}"
    nodelay="SERVICE_NODELAY_${1}"
    address="SERVICE_ADDRESS_${1}"
    retry="SERVICE_RETRY_${1}"
    
    if [ -z "${!token}" ] && [ -z "${DEFAULT_TOKEN}" ]; then
      echo "::: Token not set for service '${!name}' and 'DEFAULT_TOKEN' not set"
      exit 1
    fi
    token="${!token:-${DEFAULT_TOKEN}}"
    if [[ -z "${!address}" ]]; then
      echo "::: No address for service '${!name}'"
      exit 1
    fi
    validate_address "${!address}"
    if [[ $? != 0 ]]; then
      echo "::: Invalid address for service '${!name}'"
      exit 1
    fi
    to_config "\n[${MODE}.services.${!name}]"
    type=$(get_service_type "${!type}")
    if [ -n "${type}" ]; then
      to_config "type = \"${type}\""
    fi
    to_config "token = \"${token}\""
    if [[ "${MODE}" == "server" ]]; then
      to_config "bind_addr = \"${!address}\""
    else
      to_config "local_addr = \"${!address}\""
    fi
    if [ -n "${!nodelay}" ]; then
      protocol=$(validate_boolean "${!nodelay}")
      to_config "nodelay = ${!nodelay}"
    fi
    if [[ -n "${!retry//[a-z,.]/}" && "${MODE}" == "client" ]]; then
      to_config "retry_interval = ${!retry//[a-z,.]/}"
    fi
}

function get_service_type() {
    protocol="${1,,}"
    
    if [ "${protocol}" == "udp" ]; then
      echo "udp"
    elif [ "${protocol}" == "tcp" ]; then
      echo "tcp"
    fi
}

function validate_address() {
    value="$1"
    domain_allowed="$2"
    ip="${value%:*}"
    port="${value##*:}"
    
    if ! [[ "${value}" == *":"* ]]; then
      echo "::: Invalid address '${value}'"
      return 1
    fi
    if ! [[ "${port}" =~ ^[0-9]+$ ]]; then
      echo "::: Port must be numbers only: '${port}'"
      return 1
    fi
    if [[ "${port}" -ge 65535 ]] || [[ "${port}" -le 1 ]]; then
      echo "::: Wrong port: '${port}'"
      return 1
    fi
    if [[ "${ip}" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
      return 0
    elif [[ "${ip}" =~ ^\[([0-9a-fA-F]{0,4}:){2,7}([0-9a-fA-F]{0,4})\]$ ]]; then
      return 0
    elif [[ "${ip}" =~ ^[a-zA-Z0-9.-]+$ && -n "${domain_allowed}" ]]; then
      return 0
    elif [[ -n "${domain_allowed}" ]]; then
      echo "::: Invalid domain: '${ip}'"
      return 1
    else
      echo "::: Invalid IP: '${ip}'"
      return 1
    fi
}

function client_setup() {
    validate_address "${ADDRESS}" "true"
    if [[ "$?" == 1 ]]; then
      echo "::: For client 'ADDRESS'"
      exit 1
    fi
    to_config "[client]"
    to_config "remote_addr = \"${ADDRESS}\""
    if [[ -n "${DEFAULT_TOKEN}" ]]; then
      to_config "default_token = \"${DEFAULT_TOKEN}\""
    fi
    if [[ -n "${HEARTBEAT_TIMEOUT//[a-z,.]/}" ]]; then
      to_config "heartbeat_timeout = ${HEARTBEAT_TIMEOUT//[a-z,.]/}"
    fi
    if [[ -n "${RETRY_INTERVAL//[a-z,.]/}" ]]; then
      to_config "retry_interval = ${RETRY_INTERVAL//[a-z,.]/}"
    fi
}

function server_setup() {
    validate_address "${ADDRESS}" "false"
    if [[ "$?" == 1 ]]; then
      echo "::: For client 'ADDRESS'"
      exit 1
    fi
    to_config "[server]"
    to_config "bind_addr = \"${ADDRESS}\""
    if [[ -n "${DEFAULT_TOKEN}" ]]; then
      to_config "default_token = \"${DEFAULT_TOKEN}\""
    fi
    if [[ -n "${HEARTBEAT_INTERVAL//[a-z,.]/}" ]]; then
      to_config "heartbeat_interval = ${HEARTBEAT_INTERVAL//[a-z,.]/}"
    fi
}

function setup_transport_tcp() {
    KEEPALIVE_SECONDS="${KEEPALIVE_SECONDS//[a-z,.]/}"
    KEEPALIVE_INTERVAL="${KEEPALIVE_INTERVAL//[a-z,.]/}"
    
    if ! [[ -n "${PROXY_URL}" || -n "${TCP_NODELAY}" || -n "${KEEPALIVE_SECONDS//[a-z,.]/}" || -n "${KEEPALIVE_INTERVAL//[a-z,.]/}" ]]; then
      return 0
    fi
    to_config "\n[${MODE}.transport.tcp]"
    if [[ -n "${PROXY_URL}" ]]; then
      to_config "proxy = \"${PROXY_URL}\""
    fi
    TCP_NODELAY=$(validate_boolean "${TCP_NODELAY}")
    if [[ -n "${TCP_NODELAY}" ]]; then
      to_config "nodelay = ${TCP_NODELAY}"
    fi
    if [[ -n "${KEEPALIVE_INTERVAL}" ]]; then
      to_config "keepalive_interval = ${KEEPALIVE_INTERVAL}"
    fi
    if [[ -n "${KEEPALIVE_SECONDS}" ]]; then
      to_config "keepalive_secs = ${KEEPALIVE_SECONDS}"
    fi
    return 0
}

function setup_transport_client_tls() {
    if [[ -z "${TRUSTED_ROOT}" ]]; then
      echo "::: 'TRANSPORT_TYPE' set to 'TLS' so 'TRUSTED_ROOT' must be set."
      exit 1
    fi
    to_config "\n[client.transport.tls]"
    to_config "trusted_root = \"${TRUSTED_ROOT}\""
    if [[ -n "${TLS_HOSTNAME}" ]]; then
      to_config "hostname = \"${TLS_HOSTNAME}\""
    fi
}

function setup_transport_server_tls() {
    if [[ -z "${PKCS12}" ]]; then
      echo "::: 'TRANSPORT_TYPE' set to 'TLS' so 'PKCS12' must be set."
      exit 1
    elif [[ -z "${PKCS12_PASSWORD}" ]]; then
      echo "::: 'TRANSPORT_TYPE' set to 'TLS' so 'PKCS12_PASSWORD' must be set."
      exit 1
    fi
    to_config "\n[server.transport.tls]"
    to_config "pkcs12 = \"${PKCS12}\""
    to_config "pkcs12_password = \"${PKCS12_PASSWORD}\""
    return 0
}    

function setup_transport_noise() {
    if ! [[ -n "${NOISE_PATTERN}" || -n "${NOISE_LOCAL_PRIVATE_KEY}" || -n "${NOISE_LOCAL_PRIVATE_KEY}" ]]; then
      return 0
    fi
    to_config "\n[${MODE}.transport.noise]"
    if [[ -n "${NOISE_PATTERN}" ]]; then
        to_config "pattern = \"${NOISE_PATTERN}\""
    fi
    if [[ -n "${NOISE_LOCAL_PRIVATE_KEY}" ]]; then
        to_config "local_private_key = \"${NOISE_LOCAL_PRIVATE_KEY}\""
    fi
    if [[ -n "${NOISE_REMOTE_PUBLIC_KEY}" ]]; then
        to_config "remote_public_key = \"${NOISE_REMOTE_PUBLIC_KEY}\""
    fi
}

function setup_transport_type() {
    TRANSPORT_TYPE="${TRANSPORT_TYPE,,}"
    if [ "${TRANSPORT_TYPE}" == "tcp" ]; then
      TRANSPORT_TYPE="tcp"
    elif [ "${TRANSPORT_TYPE}" == "tls" ]; then
      TRANSPORT_TYPE="tls"
    elif [ "${TRANSPORT_TYPE}" == "noise" ]; then
      TRANSPORT_TYPE="noise"
    else
      TRANSPORT_TYPE=""
      setup_transport_tcp
      return 0
    fi
    to_config "\n[${MODE}.transport]"
    to_config "type = \"${TRANSPORT_TYPE}\""
    setup_transport_tcp
    if [ "${TRANSPORT_TYPE}" == "tls" ]; then
      if [[ "${MODE}" == "client" ]]; then
        setup_transport_client_tls
      else
        setup_transport_server_tls
      fi
    elif [ "${TRANSPORT_TYPE}" == "noise" ]; then
      setup_transport_noise
    fi
    return 0
}


if [[ "${MODE}" == "server" ]]; then
  server_setup
else
  client_setup
fi
setup_transport_type

service_counter=1
while [ ${service_counter} -le 50 ]
do
  service_name="SERVICE_NAME_${service_counter}"
  if [[ -z "${!service_name}" ]]; then
    break
  fi
  create_valid_service "${service_counter}"
  service_counter=$(( $service_counter + 1 ))
done

/rathole "${FILE_PATH}"

cat "${FILE_PATH}"
