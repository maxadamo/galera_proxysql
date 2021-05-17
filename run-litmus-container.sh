#!/bin/bash
#
# this is intended to be used locally on your workstation
# to spin up the container and run a local test
#
CENTOS7_IMAGE="litmusimage/centos:7"

pdk bundle exec rake spec_prep
pdk bundle exec rake "litmus:provision[docker, ${CENTOS7_IMAGE}]"
pdk bundle exec rake 'litmus:install_agent[puppet7]'
pdk bundle exec rake litmus:install_module

docker exec -it litmusimage_centos_7-2222 yum check-update
docker exec -it litmusimage_centos_7-2222 yum install vim bash-completion less telnet -y

echo "you can create the manifest inside the container and then you can run:"
echo "puppet apply /root/manifest.pp --hiera_config=/etc/puppetlabs/code/environments/production/modules/galera_proxysql/hiera.yaml"
echo -e "\e[1;49;92m==> script completed in:\e[0m ${SECONDS} seconds"

