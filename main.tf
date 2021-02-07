terraform {
  required_providers {
    exoscale = {
      source  = "exoscale/exoscale"
      version = "0.21.1"
    }
  }
}

locals {
  zone = "ch-gva-2"
}

data "exoscale_compute_template" "ubuntu" {
  zone = local.zone
  name = "Linux Ubuntu 20.04 LTS 64-bit"
}

resource "exoscale_security_group" "web" {
  name        = "web"
  description = "Webservers"

  tags = {
    kind = "web"
  }
}



resource "exoscale_nlb" "main_load_balancer" {
  zone = local.zone
  name = "main-load-balancer"
  description = "Main Load Balancer"
}

resource "exoscale_instance_pool" "dokku_server" {
  zone = local.zone
  name = "dokku-server"
  template_id = data.exoscale_compute_template.ubuntu.id
  size = 1
  service_offering = "medium"
  disk_size = 50
  key_pair     = "supcik@heia-fr"

  timeouts {
    delete = "10m"
  }
  
  user_data    = <<EOF
#cloud-config
package_upgrade: true
runcmd:
  - echo "dokku dokku/web_config boolean false"              | debconf-set-selections
  - echo "dokku dokku/vhost_enable boolean true"             | debconf-set-selections
  - echo "dokku dokku/hostname string dokku.isc.heia-fr.ch"  | debconf-set-selections
  - echo "dokku dokku/skip_key_file boolean true"            | debconf-set-selections
  - echo "dokku dokku/nginx_enable boolean true"             | debconf-set-selections
  - echo "dokku dokku/key_file string /root/.ssh/id_rsa.pub" | debconf-set-selections
  - [ apt-get, update, -qq ]
  - [ apt-get, -qq, -y, --no-install-recommends, install, apt-transport-https ]
  - wget -nv -O - https://get.docker.com/ | sh
  - wget -nv -O - https://packagecloud.io/dokku/dokku/gpgkey | apt-key add -
  - echo "deb https://packagecloud.io/dokku/dokku/ubuntu/ focal main" | sudo tee /etc/apt/sources.list.d/dokku.list
  - [ apt-get, update,-qq ]
  - [ apt-get, -qq, -y, install, dokku ]
  - [ dokku, plugin:install-dependencies, --core ]
  - [ dokku, "domains:set-global", dokku.isc.heia-fr.ch ]
  - wget -nv -O - https://github.com/supcik.keys     | grep ed25519 | sed '1q;d' | dokku ssh-keys:add jacques
  - wget -nv -O - https://github.com/derlin.keys     | grep ed25519 | sed '1q;d' | dokku ssh-keys:add lucy
  - wget -nv -O - https://github.com/damieng002.keys | grep ed25519 | sed '1q;d' | dokku ssh-keys:add damien
  - [ dokku, plugin:install, https://github.com/dokku/dokku-letsencrypt.git ]
EOF
}

resource "exoscale_nlb_service" "website" {
  zone             = exoscale_nlb.main_load_balancer.zone
  name             = "dokku-https"
  description      = "Website over HTTPS"
  nlb_id           = exoscale_nlb.main_load_balancer.id
  instance_pool_id = exoscale_instance_pool.dokku_server.id
    protocol       = "tcp"
    port           = 443
    target_port    = 443

  healthcheck {
    mode     = "tcp"
    port     = 443
  }
}