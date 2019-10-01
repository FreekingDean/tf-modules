variable "orchistration_type" {
  description = "OS to run in the VM can be one of [docker, kubernetes]"
  type = string
}
variable "node_count" {
  description = "Number of nodes to launch"
  type = number
  default = 1
}
