resource "kubernetes_namespace" "argocd" {
  metadata {
    name = var.argocd_namespace
  }
}

resource "kubernetes_namespace" "system" {
  metadata {
    name = var.system_namespace
  }
}

resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_chart_version
  namespace        = kubernetes_namespace.argocd.metadata[0].name
  create_namespace = false

  values = [yamlencode({
    global = {
      domain = "argocd.local"
    }
    server = {
      service = {
        type = "ClusterIP"
      }
      extraArgs = ["--insecure"]
    }
  })]
}
