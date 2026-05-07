variable "instance_type" {}
variable "component" {}
variable "env" {}
variable "ports" {}
variable "dns_domain" {}
variable "private_key_path" {
  description = "Local path to PEM for SSH (remote-exec). Use pathexpand-friendly paths, e.g. ~/.ssh/wmp.pem"
  type        = string
}

