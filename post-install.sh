#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset

VMIP=$(exo vm list --output-template '{{ .Name }}:{{ .IPAddress }}' | \
	grep 'dokku-demo' | cut -f 2 -d ':')
EIP=$(exo eip list --output-template '{{ .Instances }}:{{ .IPAddress }}' | \
	grep 'dokku-demo' | cut -f 2 -d ':')

echo "Configuring $VMIP/$EIP"

tar czf post-install.tar.gz post-install
scp post-install.tar.gz ubuntu@$VMIP:
ssh ubuntu@$VMIP <<EOF
tar xzf post-install.tar.gz
cd post-install
sudo bash ./apply.sh
/sbin/ip addr
EOF

