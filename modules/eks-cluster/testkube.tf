# Testkube's database, storage and secrets (modules/testkube), for the add-on in
# gitops/addons/testkube.
module "testkube" {
  source = "../testkube"

  name       = "${var.name}-testkube"
  vpc_id     = var.vpc_id
  subnet_ids = var.subnet_ids
}
