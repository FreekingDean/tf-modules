locals {
  entrypoints = var.public ? "https-public" : "https-local"

  publicity = var.public ? "public" : "local"
}

resource "kubernetes_service" "service_web" {
  count = var.web_access_port == null ? 0 : 1
  metadata {
    name      = "${var.name}-web"
    namespace = "default"

    labels = {
      k8s-app = var.name
    }
  }

  spec {
    type = "ClusterIP"

    port {
      port        = var.web_access_port
      target_port = "web-access"
    }

    selector = {
      k8s-app = var.name
    }
  }
}

resource "kubernetes_service" "service_udp" {
  count = length(var.forward_udp)

  metadata {
    name      = "${var.name}-udp"
    namespace = "default"

    labels = {
      k8s-app = var.name
    }
  }

  spec {
    type = "LoadBalancer"

    port {
      port        = var.forward_udp[count.index]
      protocol    = "UDP"
      target_port = "udp-${count.index}"
    }

    selector = {
      k8s-app = var.name
    }
  }
}

resource "kubernetes_service" "service_tcp" {
  count = length(var.forward_tcp) > 0 ? 1 : 0
  metadata {
    name      = "${var.name}-tcp-external"
    namespace = "default"

    labels = {
      k8s-app = var.name
    }
  }

  spec {
    type = "LoadBalancer"

    dynamic "port" {
      for_each = var.forward_tcp
      content {
        port        = port.value
        target_port = "tcp-${port.value}"
      }
    }

    selector = {
      k8s-app = var.name
    }
  }
}

resource "kubernetes_service" "internal_tcp" {
  count = length(var.internal_tcp)

  metadata {
    name      = "${var.name}-tcp"
    namespace = "default"

    labels = {
      k8s-app = var.name
    }
  }

  spec {
    type = "ClusterIP"

    port {
      port        = var.internal_tcp[count.index]
      target_port = "tcp-int-${count.index}"
    }

    selector = {
      k8s-app = var.name
    }
  }
}

resource "kubernetes_service" "internal_udp" {
  count = length(var.internal_udp)

  metadata {
    name      = "${var.name}-udp"
    namespace = "default"

    labels = {
      k8s-app = var.name
    }
  }

  spec {
    type = "ClusterIP"

    port {
      port        = var.internal_udp[count.index]
      target_port = "udp-int-${count.index}"
    }

    selector = {
      k8s-app = var.name
    }
  }
}

resource "kubernetes_ingress" "ingress-proxy" {
  count = length(var.proxy_list) == 0 ? 0 : 1
  metadata {
    name = "${var.name}-proxies"
    namespace = "default"
    annotations = {
      "traefik.frontend.entryPoints" = "http,https"
    }
  }
  spec {
    dynamic "rule" {
      for_each = var.proxy_list
      content {
        host = chomp(rule.value)
        http {
          path {
            backend {
              service_name = kubernetes_service.internal_tcp[0].metadata[0].name
              service_port = 80
            }

            path = "/"
          }
        }
      }
    }
  }
}

resource "kubernetes_ingress" "ingress" {
  count = var.web_access_port == null ? 0 : 1
  metadata {
    name = var.name
    namespace = "default"
    annotations = {
      "traefik.ingress.kubernetes.io/router.entrypoints" = local.entrypoints
      "traefik.ingress.kubernetes.io/router.tls" = "true"
    }
  }

  spec {
    tls {
      hosts = ["${var.name}.${local.publicity}.deangalvin.com"]
    }

    rule {
      host = "${var.name}.${local.publicity}.deangalvin.com"
      http {
        path {
          backend {
            service_name = kubernetes_service.service_web[0].metadata[0].name
            service_port = var.web_access_port
          }

          path = "/"
        }
      }
    }
  }
}

output "internal_ip" {
  value = length(kubernetes_service.internal_tcp) > 0 ? kubernetes_service.internal_tcp[0].spec[0].cluster_ip : null
}
