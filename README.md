# Demo / Live coding

## Create the virtual machine (Exoscale)

Create the virtualmachine at Exoscale using terraform

```
terraform apply
```

## Prepare installation (on the notebook)

Change the the base directory and type the following commands in your shell:

```
PROJECT_BASE_DIR=$(pwd)

VMIP=$(exo vm list --output-template '{{ .Name }}:{{ .IPAddress }}' | \
	grep 'dokku-demo' | cut -f 2 -d ':')
EIP=$(exo eip list --output-template '{{ .Instances }}:{{ .IPAddress }}' | \
	grep 'dokku-demo' | cut -f 2 -d ':')
echo "Project Base: $PROJECT_BASE_DIR"
echo "VM IP Adddress: $VMIP"
echo "VM EIP Adddress: $EIP"
```

## Build dokku-demo-site using Hugu and Caddy (on the notebook)

type the following commands in your shell:

```
cd $PROJECT_BASE_DIR
hugo new site dokku-demo-site
cd dokku-demo-site
git init
git submodule add \
  https://github.com/rhazdon/hugo-theme-hello-friend-ng.git \
  themes/hello-friend-ng
```

Add the file `config.toml`

```
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

### Test if the site works properly

```
hugo serve
^C
```

Add a basic `Caddyfile`

```
http:// {
    root * /srv/public/
    file_server
}
```

Add a `Dockerfile`

```
FROM klakegg/hugo AS builder
WORKDIR /src
COPY ./ /src/
RUN hugo

FROM caddy:latest
COPY Caddyfile /etc/caddy/Caddyfile
COPY --from=builder /src/public /srv/public
```

Build and test docker image:

```
docker build -t heiafr/dokku-demo-site:latest .
open http://localhost:8080
docker run --rm -p 8080:80 heiafr/dokku-demo-site:latest
^C
```


Push image to dockerhub

```
docker login
docker push heiafr/dokku-demo-site:latest
```

---

## Create the Dokku "app" (on the virtual machine at Exoscale)

```
ssh ubuntu@$VMIP
```

```
dokku apps:create www
^D
```

---

## Create a project for the deployment (back on notebookk)

Type the following commands:

```
cd $PROJECT_BASE_DIR
mkdir dokku-demo-site-deploy
cd dokku-demo-site-deploy
```

Add this 1-liner `Dockerfile`:

```
FROM heiafr/dokku-demo-site:latest
```

Type the following commands:

```
git init
git add Dockerfile
git commit -m "Initial commit"
git remote add dokku dokku@${VMIP}:www
git push dokku master
```

Test:

```
open http://www.dokku-demo.isc.heia-fr.ch
```

Configure SSL using Let's Encrypt:

```
ssh ubuntu@$VMIP
```

```
dokku config:set www DOKKU_DOCKERFILE_PORTS="80/tcp"
dokku proxy:ports-clear www
dokku config:set --no-restart www DOKKU_LETSENCRYPT_EMAIL=jacques.supcik@hefr.ch
dokku letsencrypt www
^D
```

```
open https://www.dokku-demo.isc.heia-fr.ch
```

## Destroy the virtual machine

Go to the terraform project first!

```
terraform destroy \
  -target exoscale_nlb_service.https \
  -target exoscale_nlb_service.http \
  -target exoscale_instance_pool.dokku_server
```