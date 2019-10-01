variable "name" {
  description = "The name of the service"
  type        = string
}

variable "image" {
  description = "The docker image name to use within this service"
  type        = string
}

variable "image_version" {
  description = "The image verison to use"
  type        = string
  default     = "latest"
}

variable "args" {
  description = "Arguments to pass to the containers entrypoint command"
  type        = list(string)
  default     = null
}

variable "env" {
  description = "Environment variables to be passed into the tasks"
  default = {}
}

variable "web_access_port" {
  description = "Port to forward for web access"
  default = null
  type = number
}

variable "forward_tcp" {
  description = "TCP Ports to forward"
  default     = []
  type        = list(number)
}

variable "forward_udp" {
  description = "UDP Ports to forward"
  default     = []
  type        = list(number)
}

variable "dns_nameservers" {
  description = "Name servers to use"
  default = null
  type = list(string)
}

variable "config_path" {
  description = "The path to the configuration on the container"
  default     = null
  type        = string
}

variable "dockersock_path" {
  description = "The path to the dockersock on the container"
  default     = null
  type        = string
}

variable "tv_path" {
  description = "The path to the tv on the container"
  default     = null
  type        = string
}

variable "movies_path" {
  description = "The path to the movies on the container"
  default     = null
  type        = string
}

variable "seedbox_path" {
  description = "The path to the seedbox on the container"
  default     = null
  type        = string
}

variable "storage_path" {
  description = "The path to the cold storage on the container"
  default     = null
  type        = string
}

variable "root_path" {
  description = "The path to the root dir on the container"
  default     = null
  type        = string
}

variable "fast_paths" {
  description = "Paths to be mounted for fast access (like transcoding)"
  default     = []
  type        = list(string)
}

variable "read_only_paths" {
  description = "Additional read only mounts"
  default     = []
  type        = list(object({
    c = string
    h = string
  }))
}

variable "read_write_paths" {
  description = "Additional read only mounts"
  default     = []
  type        = list(object({
    c = string
    h = string
  }))
}

variable "ephermeral_volumes" {
  description = "Ephemeral volumes used to store data for services"
  default = []
  type = list(string)
}

variable "scale" {
  description = "Override for scaling how many containers should exist for this service"
  default = 2
}

variable "vpn" {
  description = "Name of the VPN to connect to"
  default = ""
}

variable "manager_only" {
  description = "Require running this/these containers only on a manager node"
  default = false
}

variable "global" {
  description = "Run this globally"
  default = null
}

variable "added_networks" {
  description = "Additional networks to attach to"
  default = []
}

variable "traefik_network_id" {
  description = "Traefik network id to use for proxying"
  type = string
  default = null
}
