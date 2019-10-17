locals {
  read_only_paths_normalized = [for paths in var.read_only_paths: {
    target = paths.c
    source = paths.h
    type = "bind"
    read_only = true
  }]

  read_write_paths_normalized = [for paths in var.read_write_paths: {
    target = paths.c
    source = paths.h
    type = "bind"
    read_only = false
  }]

  fast_paths_normalized = [for path in var.fast_paths: {
    target = path
    source = "/storage/fast/${var.name}${path}"
    type = "bind"
    read_only = false
  }]
  paths = flatten([
    #{
    #  target = "/etc/localtime",
    #  source = "/etc/localtime",
    #  type = "bind",
    #  read_only = true,
    #},
    var.config_path == null ? [] : [{
      target = var.config_path
      source = "/storage/cold/opt/${var.name}"
      read_only = false
      type = "bind"
    }],
    var.root_path == null ? [] : [{
      target = var.root_path
      source = "/"
      read_only = true
      type = "bind"
    }],
    var.storage_path == null ? [] : [{
      target = var.storage_path
      source = "/storage/cold"
      read_only = false
      type = "bind"
    }],
    var.seedbox_path == null ? [] : [{
      target = var.seedbox_path
      source = "/storage/cold/seedbox"
      read_only = false
      type = "bind"
    }],
    var.tv_path == null ? [] : [{
      target = var.tv_path
      source = "/storage/cold/tv"
      read_only = false
      type = "bind"
    }],
    var.movies_path == null ? [] : [{
      target = var.movies_path
      source = "/storage/cold/movies"
      read_only = false
      type = "bind"
    }],
    local.read_only_paths_normalized,
    local.read_write_paths_normalized,
    local.fast_paths_normalized,
  ])
}

resource "kubernetes_deployment" "deployment" {
  metadata {
    name      = var.name
    namespace = "default"

    labels = {
      k8s-app = var.name
    }
  }

  spec {
    replicas = var.scale

    selector {
      match_labels = {
        k8s-app = var.name
      }
    }

    template {
      metadata {
        labels = {
          k8s-app = var.name
        }
        namespace = "default"
      }

      spec {
        dynamic "volume" {
          for_each = local.paths
          content {
            name = "vol-${volume.key}"
            host_path {
              path = volume.value.source
            }
          }
        }

        dns_config {
          nameservers = ["8.8.8.8"]
        }

        container {
          name  = var.name
          image = "${var.image}:${var.image_version}"

          security_context {
            capabilities {
              add = var.has_vpn ? ["NET_ADMIN"] : []
            }
          }

          dynamic "env" {
            for_each = var.env
            content {
              name = env.key
              value = env.value
            }
          }

          port {
            container_port = var.web_access_port
            protocol       = "TCP"
            name           = "web-access"
          }

          dynamic "volume_mount" {
            for_each = local.paths

            content {
              name = "vol-${volume_mount.key}"
              mount_path = volume_mount.value.target
              read_only = volume_mount.value.read_only
            }
          }
        }
      }
    }

    revision_history_limit = 5
  }
}

resource "kubernetes_service" "service" {
  metadata {
    name      = var.name
    namespace = "default"

    labels = {
      k8s-app = var.name
    }
  }

  spec {
    port {
      port        = var.web_access_port
      target_port = "web-access"
    }

    selector = {
      k8s-app = var.name
    }
  }
}

resource "kubernetes_ingress" "ingress" {
  metadata {
    name = var.name
    namespace = "default"
  }

  spec {
    tls {
      hosts = ["${var.name}.local.deangalvin.com"]
    }

    rule {
      host = "${var.name}.local.deangalvin.com"
      http {
        path {
          backend {
            service_name = var.name
            service_port = var.web_access_port
          }

          path = "/"
        }
      }
    }
  }
}
