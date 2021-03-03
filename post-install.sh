#!/bin/bash

set -o errexit
set -o nounset
# set -o xtrace

eip_config() {
cat -<<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    lo:
      match:
        name: lo
      addresses:
        - ${EIP}/32
EOF
}


export VMIP=$(exo vm list --output-template '{{ .Name }}:{{ .IPAddress }}' | grep 'dokku-demo' | cut -f 2 -d ':')

if [ -z "$VMIP" ]; then
  echo "The machine is not running !"
  exit 1
fi

echo "VM IP = $VMIP" | boxes -d stone

export EIP=$(exo eip list --output-template '{{ .Instances }}:{{ .IPAddress }}' | grep 'dokku-demo' | cut -f 2 -d ':')

if [ -z "$EIP" ]; then
  echo "The Elastic IP is not configured for the VM"
  exit 1
fi

echo "Elastic IP = $EIP" | boxes -d stone

eip_config >post-install/51-eip.yaml
tar czf post-install.tar.gz post-install
scp post-install.tar.gz ubuntu@$VMIP:
ssh ubuntu@$VMIP <<EOF
tar xzf post-install.tar.gz
cd post-install
sudo bash ./apply.sh
EOF

echo "Done" | boxes -d stone
