locals {
  read_only_paths_normalized = [for paths in var.read_only_paths: {
    target = paths.c
    source = paths.h
    type = "bind"
    read_only = true
  }]

  read_write_files_normalized = [for paths in var.read_write_files: {
    target = paths.c
    source = paths.h
    type = "file"
    read_only = false
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

  devices_normalized = [for path in var.added_devices: {
    target = path
    source = path
    type = "bind"
    read_only = false
  }]

  capabilities = flatten([
    var.has_vpn ? ["NET_ADMIN"] : [],
    length(var.added_devices) > 0 ? ["SYS_ADMIN", "SYS_RAWIO"] : []
  ])

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
    local.read_write_files_normalized,
    local.fast_paths_normalized,
    local.devices_normalized,
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
              type = volume.value.type == "file" ? "FileOrCreate" : null
              path = volume.value.source
            }
          }
        }

        dns_config {
          nameservers = ["8.8.8.8"]
        }

        dynamic "init_container" {
          for_each = var.init_command == "" ? [] : [true]
          content {
            name  = "${var.name}-init"
            image = "${var.image}:${var.image_version}"

            args = [var.init_command]

            dynamic "env" {
              for_each = var.env
              content {
                name = env.key
                value = env.value
              }
            }

            dynamic "volume_mount" {
              for_each = local.paths

              content {
                name = "vol-${volume_mount.key}"
                mount_path = volume_mount.value.target
                read_only = volume_mount.value.read_only
              }
            }

            security_context {
              privileged = length(var.added_devices) > 0 ? true : false
              capabilities {
                add = local.capabilities
              }
            }
          }
        }

        container {
          name  = var.name
          image = "${var.image}:${var.image_version}"

          security_context {
            privileged = length(var.added_devices) > 0 ? true : false
            capabilities {
              add = local.capabilities
            }
          }

          dynamic "env" {
            for_each = var.env
            content {
              name = env.key
              value = env.value
            }
          }

          dynamic "port" {
            for_each = var.web_access_port == null ? [] : [var.web_access_port]
            content {
              container_port = port.value
              protocol       = "TCP"
              name           = "web-access"
            }
          }

          dynamic "port" {
            for_each = var.forward_tcp
            content {
              container_port = port.value
              protocol       = "TCP"
              name           = "tcp-${port.key}"
            }
          }

          dynamic "port" {
            for_each = var.internal_tcp
            content {
              container_port = port.value
              protocol       = "TCP"
              name           = "tcp-int-${port.key}"
            }
          }

          dynamic "port" {
            for_each = var.forward_udp
            content {
              container_port = port.value
              protocol       = "UDP"
              name           = "udp-${port.key}"
            }
          }

          dynamic "port" {
            for_each = var.internal_udp
            content {
              container_port = port.value
              protocol       = "UDP"
              name           = "udp-int-${port.key}"
            }
          }

          dynamic "volume_mount" {
            for_each = local.paths

            content {
              name = "vol-${volume_mount.key}"
              mount_path = volume_mount.value.target
              read_only = volume_mount.value.read_only
            }
          }

          args = var.additional_args
          tty = var.tty
          stdin = var.tty
        }
      }
    }

    revision_history_limit = 5
  }

  timeouts {
    create = "2m"
  }
}
