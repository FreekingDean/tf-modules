locals {
  data = {
    "docker" = {
      os = "/home/bananaboy/Projects/tftest/coreos_production_qemu_image.img"
      network_name = "dockernet"
      ip_prefix = "10.1.1"
      bridge_name = "dckrbr"
      mac_prefix = "1"
    },
    "k8s" = {
      os = "https://github.com/rancher/k3os/releases/download/v0.3.0/k3os-amd64.iso"
      network_name = "k8snet"
      ip_prefix = "10.1.2"
      mac_prefix = "0"
      bridge_name = "k8sbr"
    }
  }
  ip_prefix = local.data[var.orchistration_type]["ip_prefix"]
  controller_ip = "${local.ip_prefix}.11"
  ip_cidr = "${local.ip_prefix}.0/24"
  os = local.data[var.orchistration_type]["os"]
  network_name = local.data[var.orchistration_type]["network_name"]
  network_domain = "${local.network_name}.local"
  bridge_name = local.data[var.orchistration_type]["bridge_name"]
  memory = 8192 / var.node_count
  mac_prefix = local.data[var.orchistration_type]["mac_prefix"]
}

resource "libvirt_pool" "pool" {
  name = "${var.orchistration_type}"
  type = "dir"
  path = "/storage/fast/vms/pool_${var.orchistration_type}"
}

resource "libvirt_ignition" "ignition" {
  name    = "main_ignition_${var.orchistration_type}"
  pool    = libvirt_pool.pool.name
  content = data.ignition_config.startup.rendered
}

resource "libvirt_network" "main_net" {
  name = local.network_name
  addresses = [local.ip_cidr]
  domain = local.network_domain
  bridge = local.bridge_name
  dns {
    enabled = true

    hosts {
      hostname = "controller.${local.network_domain}"
      ip = local.controller_ip
    }
  }

  dhcp {
    enabled = true
  }
}

# We fetch the latest ubuntu release image from their mirrors
resource "libvirt_volume" "os" {
  name   = "os-qcow2_${var.orchistration_type}.${count.index}"
  pool   = libvirt_pool.pool.name
  source = local.os
  format = "qcow2"
  count = var.node_count
}

resource "libvirt_domain" "vm" {
  name = "${var.orchistration_type}.${count.index}"
  coreos_ignition = libvirt_ignition.ignition.id
  memory = local.memory

  filesystem {
    source   = "/storage"
    target   = "storage"
    readonly = false
    accessmode = "mapped"
  }

  disk {
    volume_id = libvirt_volume.os.*.id[count.index]
  }

  boot_device {
    dev = ["cdrom"]
  }

  network_interface {
    network_id = libvirt_network.main_net.id
    addresses = ["${local.ip_prefix}.1${count.index + 1}"]
    mac = "52:54:00:6c:3c:${local.mac_prefix}${count.index + 1}"
    wait_for_lease = true
  }

  console {
    type        = "pty"
    target_port = "0"
  }

  count = var.node_count
}
