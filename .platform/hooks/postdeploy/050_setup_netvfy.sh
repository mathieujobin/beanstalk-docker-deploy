#!/bin/bash -x

# This script needs you to set a new ENV var in your Beanstalk environment.

# netvfy_username, netvfy_password, netvfy_netdesc, netvfy_node_prefix

function log_debug() {
  echo $1
  echo $1 >> /var/log/netvfyinit.log
}
log_debug "Starting netvfy init: do we have info already? $netvfy_username"

# import env vars from elastic beanstalk environment
for s in $(/opt/elasticbeanstalk/bin/get-config environment | jq -r "to_entries|map(\"\(.key)=\(.value|tostring)\")|.[]" ); do export $s; done

log_debug "Starting netvfy init: after fetching beanstalk config? $netvfy_username"

if [ "$netvfy_username" = "" -o "$netvfy_apikey" = "" -o "$netvfy_netdesc" = "" -o "$netvfy_node_prefix" = "" ]
then
  log_debug "config missing"
  exit 0
fi

NET_DESC="$netvfy_netdesc"
DEST_SCRIPT="/usr/local/sbin/netvfy-agent"

function build_install_agent() {
  yum -y install git cmake pip jansson-devel libevent-devel libcurl-devel gcc gcc-c++ make openssl-devel
  git clone https://github.com/netvfy/netvfy-agent.git /tmp/netvfy-agent
  cd /tmp/netvfy-agent
  git submodule init
  git submodule update
  cd tapcfg
  pip install scons
  ./buildall.sh || true
  mkdir ../build_cli
  cd ../build_cli
  cmake ..
  make
  log_debug "netvfy: agent has been built, installing to /usr/local/sbin/"
  mv src/netvfy-agent /usr/local/sbin/
}

function build_install_go_agent() {
  yum -y install git go
  git clone https://github.com/netvfy/go-netvfy-agent.git /tmp/go-netvfy-agent
  cd /tmp/go-netvfy-agent
  make netvfy-agent
  log_debug "netvfy: agent has been built, installing to /usr/local/sbin/"
  mv netvfy-agent /usr/local/sbin/
}

function add_node_to_network() {
  log_debug "netvfy: adding node to network."
  ec2_instance_url="http://169.254.169.254/latest/meta-data/instance-id"
  EC2_TOKEN=`curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"`
  EC2_INSTANCE_ID="`wget -q -O - $ec2_instance_url || curl -H "X-aws-ec2-metadata-token: $EC2_TOKEN" -v $ec2_instance_url || echo unknown`"
  log_debug "netvfy: We've got an ec2 instance id: $EC2_INSTANCE_ID"
  PASSWORD="$netvfy_password"
  EMAIL="$netvfy_username"
  HOST="api.netvfy.com"
  IP_SUFFIX="`ip -4 addr show eth0 | grep inet | awk -F / {'print $1'} | cut -c 15-`"
  #NODE_DESC="$netvfy_node_prefix-$IP_SUFFIX-$EC2_INSTANCE_ID"
  BOOT_DATETIME=$(ls -ltr /etc/hostname | awk {'print $7 $6 $8'})
  NODE_DESC="$netvfy_node_prefix-$IP_SUFFIX-$BOOT_DATETIME"
  APIKEY=$netvfy_apikey

  log_debug "netvfy: We've got a netvfy api key: $APIKEY"

  curl -s -i -H 'X-netvfy-email: '${EMAIL}'' -H 'X-netvfy-apikey: '${APIKEY}'' -H 'Content-Type: application/json' \
    -d '{"network_description":"'${NET_DESC}'", "description":"'${NODE_DESC}'"}' -X POST https://${HOST}/v1/node

  log_debug "netvfy: node $NODE_DESC created, fetching NET_UID"

  # get NET_UID
  NET_UID="$(curl -s -H 'X-netvfy-email: '${EMAIL}'' -H 'X-netvfy-apikey: '${APIKEY}'' https://${HOST}/v1/network | jq -r ".networks[] | select(.description==\"${NET_DESC}\").uid")"

  log_debug "netvfy: got NET_UID: $NET_UID"

  all_nodes=$(curl -s -H 'X-netvfy-email: '${EMAIL}'' -H 'X-netvfy-apikey: '${APIKEY}'' https://${HOST}/v1/node?network_uid=$NET_UID)
  PROV_CODE=$(echo $all_nodes | jq -r ".nodes[] | select(.description==\"$NODE_DESC\").provcode")

  if [ "$PROV_CODE" = "" ]
  then
    log_debug "netvfy: provision code already used"
  else
    log_debug "netvfy: got provision code: $PROV_CODE, going onto the network..."
    $DEST_SCRIPT -k "$PROV_CODE" -n $NET_DESC
  fi

  log_debug "netvfy: setup completed"


  prefix_length=$(echo -n $netvfy_node_prefix | wc -c)
  dead_nodes=$(echo $all_nodes | jq -r ".nodes[] | select(.status==\"0\") | \
    select(.provcode != \"$PROV_CODE\") | \
    select(.description[0:$prefix_length]==\"$netvfy_node_prefix\").description")
  for deadnode in $dead_nodes
  do
    echo "Deleting $deadnode"
    curl -s -H 'X-netvfy-email: '${EMAIL}'' -H 'X-netvfy-apikey: '${APIKEY}'' -X DELETE \
      "https://${HOST}/v1/node?network_description=${NET_DESC}&description=${deadnode}"
  done

}

if [ ! -e $DEST_SCRIPT ]
then
  build_install_agent
fi

# grep -q $NET_DESC /root/.config/netvfy/nvagent.json
# if [[ $(sudo file /root/.config/netvfy/nvagent.json) ]]
if [[ $(sudo cat /root/.config/netvfy/nvagent.json | jq -r ".networks[] | select(.name==\"$NET_DESC\").pvkey") ]]
then
  log_debug "netvfy: node is already provision"
else
  add_node_to_network
fi

echo "
[Unit]
Description=Netvfy Agent service
After=crond.service

[Service]
Environment="HOME=/root"
ExecStart=$DEST_SCRIPT -c $NET_DESC
KillMode=process
Restart=on-failure
RestartSec=60s

[Install]
WantedBy=multi-user.target
" | sudo tee /usr/lib/systemd/system/netvfy-agent-$NET_DESC.service
sudo systemctl daemon-reload
log_debug "netvfy: systemctl daemon definition overriden and reloaded... now restarting"
sudo systemctl enable netvfy-agent-$NET_DESC
sudo systemctl restart netvfy-agent-$NET_DESC

log_debug "netvfy: execution finished."
