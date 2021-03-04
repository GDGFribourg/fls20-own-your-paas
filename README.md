# Live demo

## Create the virtual machine (Exoscale)

Create the virtualmachine at Exoscale using terraform

``` bash
terraform apply
```

## Configure the host with the secondary (elastic) IP address

``` bash
bash ./post-install.sh
```

## Check that the Elastic IP is configured

``` bash
VMIP=$(exo vm list --output-template '{{ .Name }}:{{ .IPAddress }}' | \
    grep 'dokku-demo' | cut -f 2 -d ':')
ssh ubuntu@$VMIP -- "/sbin/ip addr show dev lo" | boxes -d stone
```

## Prepare installation (set variables)

``` bash
PROJECT_BASE_DIR=$(pwd)
echo "Project Base: $PROJECT_BASE_DIR" | boxes -d stone
VMIP=$(exo vm list --output-template '{{ .Name }}:{{ .IPAddress }}' | \
    grep 'dokku-demo' | cut -f 2 -d ':')
echo "VM IP Adddress: $VMIP" | boxes -d stone
EIP=$(exo eip list --output-template '{{ .Instances }}:{{ .IPAddress }}' | \
    grep 'dokku-demo' | cut -f 2 -d ':')
echo "VM EIP Adddress: $EIP" | boxes -d stone

```

## Build dokku-demo-site using Hugo and Caddy

``` bash
cd $PROJECT_BASE_DIR
hugo new site dokku-demo-site
cd dokku-demo-site
git init
git submodule add \
  https://github.com/rhazdon/hugo-theme-hello-friend-ng.git \
  themes/hello-friend-ng

```

Add the file `config.toml`

``` toml
baseURL = "https://www.dokku-demo.isc.heia-fr.ch/"
languageCode = "en-us"
title = "Welcome to Fribourg Linux Seminar"
theme = "hello-friend-ng"

PygmentsCodeFences = true
PygmentsStyle = "monokai"

[author]
  name = "Jacques Supcik"

[params]
  dateform        = "2 Jan 2006"
  dateformShort   = "2 Jan"
  dateformNum     = "02-01-2006"
  dateformNumTime = "02-01-2006 15:04"

  # footerLeft = "Powered by <a href=\"http://gohugo.io\">Hugo</a>"
  footerRight = "Theme \"hello-friend-ng\" by <a href=\"https://github.com/rhazdon\">Djordje Atlialp</a>"
```

Test if the site works properly

``` bash
hugo serve
^C
```

Add a basic `Caddyfile`

``` Caddyfile
http:// {
    root * /srv/public/
    file_server
}
```

Add a `Dockerfile`

``` Dockerfile
FROM klakegg/hugo AS builder
WORKDIR /src
COPY ./ /src/
RUN hugo

FROM caddy:latest
COPY Caddyfile /etc/caddy/Caddyfile
COPY --from=builder /src/public /srv/public
```

Build and test docker image:

``` bash
docker build -t heiafr/dokku-demo-site:latest .
docker run --rm -p 8080:80 heiafr/dokku-demo-site:latest
^C
```

Push image to dockerhub

``` bash
docker login
docker push heiafr/dokku-demo-site:latest
```

---

## Create the Dokku "app" (on the virtual machine at Exoscale)

Connect to your dokku server

``` bash
ssh ubuntu@$VMIP
```

Create the app

``` bash
dokku apps:create www
```

Go back to your notebook

``` bash
logout
```

---

## Create a project for the deployment to Dokku

Type the following commands:

``` bash
cd $PROJECT_BASE_DIR
mkdir dokku-demo-site-deploy
cd dokku-demo-site-deploy
```

Add this 1-liner `Dockerfile`:

``` Dockerfile
FROM heiafr/dokku-demo-site:latest
```

Initialize a git repository

``` bash
git init
git add Dockerfile
git commit -m "Initial commit"
```

Add your dokku server as a new "remote"

``` bash
git remote add dokku dokku@${VMIP}:www
```

Push your Dockerfile to the Dokku server.
**This actually does deploy your app.**

``` bash
git push dokku master
```


Test:

``` bash
open http://www.dokku-demo.isc.heia-fr.ch
```

Configure SSL using Let's Encrypt:

``` bash
ssh ubuntu@$VMIP
```

``` bash
dokku config:set www DOKKU_DOCKERFILE_PORTS="80/tcp"
dokku proxy:ports-clear www
dokku config:set --no-restart www DOKKU_LETSENCRYPT_EMAIL=jacques.supcik@hefr.ch
dokku letsencrypt www
```

Go back to your notebook

``` bash
logout
```

Final test

``` bash
open https://www.dokku-demo.isc.heia-fr.ch
```

## Destroy the virtual machine (cleanup)

Go to the terraform project first!

``` bash
cd $PROJECT_BASE_DIR
rm -Rf dokku-demo-site
rm -Rf dokku-demo-site-deploy
bash ./destroy.sh

```