# Pod name resolution (BRIEF D21): "ministack" → ministack's IP on the Docker network, and
# *.localhost / *.internal → the Envoy Service "edge" (#8). k3s's CoreDNS imports these keys.
locals {
  # Written by `task bootstrap`.
  ministack_file = "${path.module}/../../.local/ministack.yaml"
  ministack_ip   = fileexists(local.ministack_file) ? yamldecode(file(local.ministack_file)).ip : ""
}

resource "kubernetes_config_map_v1" "coredns_custom" {
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

# CoreDNS doesn't reload imported files, so restart it when the ConfigMap changes. k3s deploys
# CoreDNS shortly after the cluster turns ACTIVE, so wait for the Deployment first. kubectl uses a
# throwaway kubeconfig, made like `task kubeconfig` does.
resource "terraform_data" "coredns_restart" {
  triggers_replace = kubernetes_config_map_v1.coredns_custom.data

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    environment = local.exec.env
    command     = <<-EOT
      set -euo pipefail
      export KUBECONFIG=$(mktemp)
      trap 'rm -f "$KUBECONFIG"' EXIT
      aws --endpoint-url http://localhost:4566 eks update-kubeconfig --name ${module.eks.cluster_name} >/dev/null
      for i in $(seq 1 90); do
        kubectl -n kube-system get deploy/coredns >/dev/null 2>&1 && break
        sleep 2
      done
      kubectl -n kube-system rollout restart deploy/coredns
      kubectl -n kube-system rollout status deploy/coredns --timeout=180s
    EOT
  }
}
