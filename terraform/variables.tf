variable "vm_username" {
  description = "VM username"
  type        = string
}

variable "vm_password" {
  description = "VM password"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "EastUS"
}
