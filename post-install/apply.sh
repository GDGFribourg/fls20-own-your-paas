#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset

cp ./51-eip.yaml /etc/netplan/51-eip.yaml
netplan apply
