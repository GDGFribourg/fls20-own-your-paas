terraform destroy \
  -target exoscale_nlb_service.https \
  -target exoscale_nlb_service.http \
  -target exoscale_instance_pool.dokku_server \
