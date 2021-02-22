#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset

VMIP=$(exo vm list --output-template '{{ .Name }}:{{ .IPAddress }}' | \
	grep 'dokku-demo' | cut -f 2 -d ':')
EIP=$(exo eip list --output-template '{{ .Instances }}:{{ .IPAddress }}' | \
	grep 'dokku-demo' | cut -f 2 -d ':')

echo "Configuring $VMIP/$EIP"

cat > post-install/51-eip.yaml <<-EOF
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


tar czf post-install.tar.gz post-install
scp post-install.tar.gz ubuntu@$VMIP:
ssh ubuntu@$VMIP <<EOF
tar xzf post-install.tar.gz
cd post-install
sudo bash ./apply.sh
EOF

