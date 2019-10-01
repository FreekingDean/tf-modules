locals {
  data = {
    "docker" = {
      os = "/home/bananaboy/Projects/tftest/coreos_production_qemu_image.img"
    }
  }
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

# We fetch the latest ubuntu release image from their mirrors
resource "libvirt_volume" "os" {
  name   = "os-qcow2_${var.orchistration_type}.${count.index}"
  pool   = libvirt_pool.pool.name
  source = local.data[var.orchistration_type]["os"]
  format = "qcow2"
  count = var.node_count
}

resource "libvirt_domain" "vm" {
  name = "${var.orchistration_type}.${count.index}"
  coreos_ignition = libvirt_ignition.ignition.id
  memory = 2048

  filesystem {
    source   = "/storage"
    target   = "storage"
    readonly = false
    accessmode = "passthrough"
  }

  disk {
    volume_id = libvirt_volume.os.*.id[count.index]
  }

  boot_device {
    dev = ["cdrom"]
  }

  network_interface {
    network_name = "dockernet"
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
