# Pod name resolution: "ministack" → ministack's IP on the Docker network, and
# *.localhost / *.internal → the Envoy Service "edge" (#8). k3s's CoreDNS imports these keys.
locals {
  # Written by `task bootstrap`.
  ministack_file = "${path.module}/../../.local/ministack.yaml"
  ministack_ip   = fileexists(local.ministack_file) ? yamldecode(file(local.ministack_file)).ip : ""
}

resource "kubernetes_config_map_v1" "coredns_custom" {
  # After the access entries (the root key's admin rights) and Argo CD: by then k3s has deployed
  # CoreDNS too.
  depends_on = [module.cluster]

  lifecycle {
    precondition {
      condition     = local.ministack_ip != ""
      error_message = ".local/ministack.yaml is missing: run `task bootstrap` first."
    }
  }

  metadata {
    name      = "coredns-custom"
    namespace = "kube-system"
  }

  data = {
    "ministack.server" = <<-EOT
      ministack:53 {
          hosts {
              ${local.ministack_ip} ministack
          }
      }
    EOT
    "edge.override"    = <<-EOT
      rewrite name regex (.+)\.localhost\.?$ edge.envoy-gateway-system.svc.cluster.local answer auto
      rewrite name regex (.+)\.internal\.?$ edge.envoy-gateway-system.svc.cluster.local answer auto
    EOT
  }
}

# CoreDNS doesn't reload imported files, so a checksum of the ConfigMap on its pod template rolls
# it when the content changes. It follows the ConfigMap, which waits for module.cluster.
resource "kubernetes_annotations" "coredns_restart" {
  api_version = "apps/v1"
  kind        = "Deployment"
  metadata {
    name      = "coredns"
    namespace = "kube-system"
  }
  template_annotations = {
    "testkube-poc/coredns-custom-sha256" = sha256(jsonencode(kubernetes_config_map_v1.coredns_custom.data))
  }
  # k3s's deploy controller manages the Deployment; take over just this annotation.
  force = true
}
