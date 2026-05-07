variable "databases" {}
variable "apps" {}
variable "dns_domain" {}
variable "env" {}

variable "private_key_path" {
  description = "Path to the PEM private key used by remote-exec SSH to instances (e.g. ~/.ssh/my-key.pem)"
  type        = string
}
