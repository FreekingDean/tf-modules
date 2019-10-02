locals {
  data = {
    "docker" = {
      os = "/home/bananaboy/Projects/tftest/coreos_production_qemu_image.img"
      network_name = "dockernet"
      ip_prefix = "10.1.1"
    },
    "k8s" = {
      os = "https://github.com/rancher/k3os/releases/download/v0.3.0/k3os-amd64.iso"
      network_name = "k8snet"
      ip_prefix = "10.1.2"
    }
  }
  ip_prefix = local.data[var.orchistration_type]["ip_prefix"]
  controller_ip = format("%s.11", local.ip_prefix)
  ip_cidr = format("%s.0/24", local.ip_prefix)
  os = local.data[var.orchistration_type]["os"]
  network_name = local.data[var.orchistration_type]["network_name"]
  network_domain = format("%s.local", local.network_name)
  memory = 8192 / var.node_count
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
  dns {
    enabled = true

    hosts {
      hostname = format("controller.%s", local.network_domain)
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
    addresses = ["10.0.1.1${count.index + 1}"]
    mac = "52:54:00:6c:3c:0${count.index + 1}"
    wait_for_lease = true
  }

  console {
    type        = "pty"
    target_port = "0"
  }

  count = var.node_count
}
