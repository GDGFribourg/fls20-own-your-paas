terraform {
  required_providers {
    exoscale = {
      source  = "exoscale/exoscale"
      version = "0.22.0"
    }
  }
}

locals {
  zone = "ch-gva-2"
  vhost = "dokku-demo.isc.heia-fr.ch"
}

resource "exoscale_ipaddress" "dokku_server" {
    zone = local.zone
}

resource "exoscale_security_group" "webservers" {
  name        = "web"
  description = "Webservers"
}

resource "exoscale_security_group_rules" "web" {
  security_group_id = exoscale_security_group.webservers.id

  ingress {
    protocol  = "TCP"
    ports     = ["22", "80", "443"]
    cidr_list = ["0.0.0.0/0", "::/0"]
  }
}

data "exoscale_compute_template" "ubuntu" {
  zone = local.zone
  name = "Linux Ubuntu 20.04 LTS 64-bit"
}

resource "exoscale_compute" "dokku_server" {
  zone = local.zone
  display_name = "dokku-server"
  state = "Running"
  hostname = "dokku-demo"
  keyboard = "fr-ch"
  template_id = data.exoscale_compute_template.ubuntu.id
  security_group_ids = [exoscale_security_group.webservers.id]
  size = "Medium"
  disk_size = 50
  key_pair     = "supcik@heia-fr"

  timeouts {
    delete = "10m"
  }
  
  user_data    = <<EOF
#cloud-config
package_upgrade: true
runcmd:
  - wget -nv -O - https://github.com/supcik.keys     | grep ed25519 | sed '1q;d' >> /home/ubuntu/.ssh/authorized_keys
  - wget -nv -O - https://github.com/derlin.keys     | grep ed25519 | sed '1q;d' >> /home/ubuntu/.ssh/authorized_keys
  - wget -nv -O - https://github.com/damieng002.keys | grep ed25519 | sed '1q;d' >> /home/ubuntu/.ssh/authorized_keys
  - echo "dokku dokku/web_config boolean false"              | debconf-set-selections
  - echo "dokku dokku/vhost_enable boolean true"             | debconf-set-selections
  - echo "dokku dokku/hostname string ${local.vhost}"        | debconf-set-selections
  - echo "dokku dokku/skip_key_file boolean true"            | debconf-set-selections
  - echo "dokku dokku/nginx_enable boolean true"             | debconf-set-selections
  - echo "dokku dokku/key_file string /root/.ssh/id_rsa.pub" | debconf-set-selections
  - [ apt-get, update, -qq ]
  - [ apt-get, -qq, -y, --no-install-recommends, install, apt-transport-https ]
  - wget -nv -O - https://get.docker.com/ | sh
  - [ gpasswd, -a, ubuntu, docker ]
  - wget -nv -O - https://packagecloud.io/dokku/dokku/gpgkey | apt-key add -
  - echo "deb https://packagecloud.io/dokku/dokku/ubuntu/ focal main" | sudo tee /etc/apt/sources.list.d/dokku.list
  - [ apt-get, update,-qq ]
  - [ apt-get, -qq, -y, install, dokku ]
  - [ dokku, plugin:install-dependencies, --core ]
  - [ dokku, "domains:set-global", ${local.vhost} ]
  - wget -nv -O - https://github.com/supcik.keys     | grep ed25519 | sed '1q;d' | dokku ssh-keys:add jacques
  - wget -nv -O - https://github.com/derlin.keys     | grep ed25519 | sed '1q;d' | dokku ssh-keys:add lucy
  - wget -nv -O - https://github.com/damieng002.keys | grep ed25519 | sed '1q;d' | dokku ssh-keys:add damien
  - [ dokku, plugin:install, https://github.com/dokku/dokku-letsencrypt.git ]
EOF
}

resource "exoscale_secondary_ipaddress" "dokku_server" {
  compute_id = exoscale_compute.dokku_server.id
  ip_address = exoscale_ipaddress.dokku_server.ip_address
}
