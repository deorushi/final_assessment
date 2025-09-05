variable "vm_username" {
  description = "Username for the VM"
}

variable "vm_password" {
  description = "Password for the VM"
}

variable "location" {
  description = "Azure region"
  default     = "East US"
}

variable "subscription_id" {}
variable "client_id" {}
variable "client_secret" {}
variable "tenant_id" {}
