locals {
  ip_prefix = "10.1.2"
  controller_ip = "${local.ip_prefix}.11"
  ip_cidr = "${local.ip_prefix}.0/24"
  network_name = "k8snet"
  network_domain = "${local.network_name}.local"
  bridge_name = local.network_name
  memory = 8192 / var.node_count
  mac_prefix = "0"
  dist_org = "FreekingDean"
  dist_version = "v0.5.1-rc1"
}

resource "libvirt_pool" "pool" {
  name = "${var.orchistration_type}"
  type = "dir"
  path = "/storage/fast/vms/pool_${var.orchistration_type}"
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
#resource "libvirt_volume" "os" {
#  #size = 2147483648
#  name   = "os"
#  pool   = libvirt_pool.pool.name
#  source = "https://github.com/rancher/k3os/releases/download/v0.3.0/k3os-amd64.iso"
#  #format = "raw"
#}

resource "libvirt_volume" "root" {
  size = (1024*1024*1024)*8
  name   = "root.${count.index}"
  pool   = libvirt_pool.pool.name
  count = var.node_count
  #source = "https://github.com/rancher/k3os/releases/download/v0.3.0/k3os-amd64.iso"
  format = "raw"
}

# We fetch the latest ubuntu release image from their mirrors
resource "libvirt_volume" "kernel" {
  lifecycle {
    ignore_changes = [
      format,
    ]
  }
  name   = "kernel-qcow2_${var.orchistration_type}.${count.index}"
  pool   = libvirt_pool.pool.name
  source = "https://github.com/${local.dist_org}/k3os/releases/download/${local.dist_version}/k3os-vmlinuz-amd64"
  format = "qcow2"
  count = var.node_count
}

# We fetch the latest ubuntu release image from their mirrors
resource "libvirt_volume" "initrd" {
  lifecycle {
    ignore_changes = [
      format,
    ]
  }
  name   = "initrd-qcow2_${var.orchistration_type}.${count.index}"
  pool   = libvirt_pool.pool.name
  source = "https://github.com/${local.dist_org}/k3os/releases/download/${local.dist_version}/k3os-initrd-amd64"
  format = "qcow2"
  count = var.node_count
}

#data "template_file" "user_data" {
#  template = file("${path.module}/cloud_init.cfg")
#}
#
#resource "libvirt_cloudinit_disk" "commoninit" {
#  name      = "commoninit.iso"
#  user_data = data.template_file.user_data.rendered
#}

resource "libvirt_domain" "vm" {
  name = "${var.orchistration_type}.${count.index}"
  memory = local.memory

  #cloudinit = libvirt_cloudinit_disk.commoninit.id

  kernel = libvirt_volume.kernel.*.id[count.index]
  initrd = libvirt_volume.initrd.*.id[count.index]

  cmdline = [
    {
      #"k3os.mode" = "live"
      "k3os.debug" = "true"
      "k3os.fallback_mode" = "install"
      "k3os.install.silent" = "true"
      "k3os.install.debug" = "true"
      "k3os.install.device" = "/dev/vda"
      "hostname" = count.index == 0 ? "k8s.master" : "k8s.node${count.index}"
      "k3os.labels.machine" = "enterprise"
      "k3os.modules" = "kvm"
      "k3os.modules" = "nvme"
      "k3os.modules" = "9p"
      "run_cmd" = "\"mkdir -p /storage && mount storage /storage -t9p -otrans=virtio,version=9p2000.L,cache=mmap\""
      "k3os.install.iso_url" = "https://github.com/${local.dist_org}/k3os/releases/download/${local.dist_version}/k3os-amd64.iso"
      #"k3os.install.config_url" = "https://raw.githubusercontent.com/FreekingDean/tf-modules/master/vm/k3os.yaml"
      "console" = "ttyS0,115200"
      "ssh_authorized_keys" = "github:FreekingDean"
      "k3os.token" = "mysecrettoken"
    },
    count.index == 0 ? {
      "k3os.k3s_args" = "\"server --no-deploy traefik\""
    } : {
      #"k3os.k3s_args" = "\"--resolv-conf /etc/resolv.conf\""
      "k3os.server_url" = "https://${local.controller_ip}:6443"
    },
    #{
    #  "1 k3os.k3s_args" = "\"--no-deploy traefik\""
    #},
  ]

  filesystem {
    source   = "/storage"
    target   = "storage"
    readonly = false
    accessmode = "mapped"
  }
  
  boot_device {
    dev = ["cdrom"]
  }

  #disk {
  #  volume_id = libvirt_volume.os.id
  #}

  disk {
    volume_id = libvirt_volume.root[count.index].id
  }

  network_interface {
    network_id = libvirt_network.main_net.id
    addresses = ["${local.ip_prefix}.1${count.index + 1}"]
    mac = "52:54:00:6C:3C:${local.mac_prefix}${count.index + 1}"
    wait_for_lease = false
  }

  console {
    type        = "pty"
    target_port = "0"
  }

  count = var.node_count
}
