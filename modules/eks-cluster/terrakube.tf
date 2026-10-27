# Terrakube's database, cache, storage, secrets and admin token (modules/terrakube), for the
# add-on in gitops/addons/terrakube.
module "terrakube" {
  source = "../terrakube"

  name       = "${var.name}-terrakube"
  vpc_id     = var.vpc_id
  subnet_ids = var.subnet_ids

  # ministack's S3 as pods see it (CoreDNS answers "ministack" in-cluster). Real AWS: leave unset.
  s3_endpoint = "http://ministack:4566"
}
