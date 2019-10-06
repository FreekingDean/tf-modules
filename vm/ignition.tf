data "ignition_config" "startup" {
  users = [
    data.ignition_user.user.id
  ]

  directories = [
    data.ignition_directory.storage.id
  ]

  systemd = [
    data.ignition_systemd_unit.storage_unit.id,
    data.ignition_systemd_unit.docker_unit.id,
  ]
}

data "ignition_systemd_unit" "docker_unit" {
  name = "docker-tcp.socket"
  enabled = true
  content = "[Unit]\nDescription=Docker Socket for the API\n\n[Socket]\nListenStream=2375\nBindIPv6Only=both\nService=docker.service\n\n[Install]\nWantedBy=sockets.target"
}

data "ignition_systemd_unit" "storage_unit" {
  name = "storage.mount"
  enabled = true
  content = file("${path.module}/services/storage.mount")
}

# Example configuration for the basic `core` user
data "ignition_user" "user" {
  name = "core"
  groups = ["sudo"]
  uid = 500

  #Example password: foobar
  password_hash = "$5$XMoeOXG6$8WZoUCLhh8L/KYhsJN2pIRb3asZ2Xos3rJla.FA1TI7"
  # Preferably use the ssh key auth instead
  #ssh_authorized_keys = "${list()}"
}

data "ignition_directory" "storage" {
  filesystem = "root"
  path = "/storage"
}
