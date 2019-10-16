#locals {
#  tcp_ports = [for port in var.forward_tcp: {
#    name           = "TCP_${port}"
#    target_port    = port
#    published_port = port
#    protocol       = "tcp"
#  }]
#  udp_ports = [for port in var.forward_udp: {
#    name           = "UDP_${port}"
#    target_port    = port
#    published_port = port
#    protocol       = "udp"
#  }]
#  ports = concat(local.tcp_ports, local.udp_ports)
#
#  read_only_paths_normalized = [for paths in var.read_only_paths: {
#    target = paths.c
#    source = paths.h
#    type = "bind"
#    read_only = true
#  }]
#
#  read_write_paths_normalized = [for paths in var.read_write_paths: {
#    target = paths.c
#    source = paths.h
#    type = "bind"
#    read_only = false
#  }]
#
#  fast_paths_normalized = [for path in var.fast_paths: {
#    target = path
#    source = "/storage/fast/${var.name}${path}"
#    type = "bind"
#    read_only = false
#  }]
#  paths = flatten([
#    {
#      target = "/etc/localtime",
#      source = "/etc/localtime",
#      type = "bind",
#      read_only = true,
#    },
#    var.config_path == null ? [] : [{
#      target = var.config_path
#      source = "/storage/cold/opt/${var.name}"
#      read_only = false
#      type = "bind"
#    }],
#    var.root_path == null ? [] : [{
#      target = var.root_path
#      source = "/"
#      read_only = true
#      type = "bind"
#    }],
#    var.dockersock_path == null ? [] : [{
#      target = var.dockersock_path
#      source = "/var/run/docker.sock"
#      read_only = true
#      type = "bind"
#    }],
#    var.storage_path == null ? [] : [{
#      target = var.storage_path
#      source = "/storage/cold"
#      read_only = false
#      type = "bind"
#    }],
#    var.seedbox_path == null ? [] : [{
#      target = var.seedbox_path
#      source = "/storage/cold/seedbox"
#      read_only = true
#      type = "bind"
#    }],
#    var.tv_path == null ? [] : [{
#      target = var.tv_path
#      source = "/storage/cold/tv"
#      read_only = false
#      type = "bind"
#    }],
#    var.movies_path == null ? [] : [{
#      target = var.movies_path
#      source = "/storage/cold/movies"
#      read_only = false
#      type = "bind"
#    }],
#    local.read_only_paths_normalized,
#    local.read_write_paths_normalized,
#    local.fast_paths_normalized,
#  ])
#
#  labels = merge(
#    {},
#    var.web_access_port == null ? {} : {
#      "traefik.frontend.rule" = "Host:${var.name}.local.deangalvin.com"
#      "traefik.frontend.entryPoints" = "https"
#      "traefik.tags" = "traefik-public"
#      "traefik.docker.network" = "traefik-public"
#      "traefik.port" = var.web_access_port
#    }
#  )
#
#  networks = flatten([
#    var.web_access_port == null ? [] : [var.traefik_network_id],
#    var.added_networks
#  ])
#
#  constraints = flatten([
#    var.manager_only ? ["node.role==manager"] : []
#  ])
#}
#
#resource "docker_service" "service" {
#  name = var.name
#
#  labels = local.labels
#
#  task_spec {
#    networks = local.networks
#
#    placement {
#      constraints = local.constraints
#      platforms {
#        os = "linux"
#        architecture = "amd64"
#      }
#    }
#
#    container_spec {
#      image = "${var.image}:${var.image_version}"
#      args  = var.args
#      labels = local.labels
#      env = var.env
#
#      dynamic "dns_config" {
#        for_each = range(var.dns_nameservers == null ? 0 : 1)
#        content {
#          nameservers = var.dns_nameservers
#        }
#      }
#
#      dynamic "mounts" {
#        for_each = local.paths
#        content {
#          target = mounts.value.target
#          source = mounts.value.source
#          type = mounts.value.type
#          read_only = mounts.value.read_only
#        }
#      }
#    }
#  }
#
#  endpoint_spec {
#    dynamic "ports" {
#      for_each = local.ports
#      content {
#        target_port    = ports.value.target_port
#        published_port = ports.value.published_port
#        protocol       = ports.value.protocol
#      }
#    }
#  }
#
#  mode {
#    global = var.global
#
#    dynamic "replicated" {
#      for_each = range(var.global == true ? 0 : 1)
#      content {
#        replicas = var.scale
#      }
#    }
#  }
#
#  update_config {
#    order = var.scale == 1 ? "start-first" : "stop-first"
#  }
#}
#
#data "docker_registry_image" "container_registry_image" {
#  name = "${var.image}:${var.image_version}"
#}
#
#resource "docker_image" "container_image" {
#  name          = "${data.docker_registry_image.container_registry_image.name}"
#  pull_triggers = ["${data.docker_registry_image.container_registry_image.sha256_digest}"]
#  keep_locally  = true
#}
#
#data "http" "ip_address" {
#  url = "https://wtfismyip.com/text"
#}
#
#data "cloudflare_zones" "deangalvin" {
#  filter {
#    name = "deangalvin.com"
#  }
#}
#
#resource "cloudflare_record" "a_record" {
#  count = "${var.web_access_port == null ? 0 : 1}"
#  zone_id = data.cloudflare_zones.deangalvin.zones[0].id
#  name = "${var.name}.local"
#  value = "192.168.2.23"
#  ttl = 1
#  type = "A"
#  proxied = "false"
#}

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
        container {
          name  = var.name
          image = "${var.image}:${var.image_version}"

          port {
            container_port = var.web_access_port
            protocol       = "TCP"
            name           = "web-access"
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
