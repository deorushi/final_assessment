variable "vm_username" {
  description = "Username for AKS nodes SSH (optional)"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "EastUS"
}

variable "subscription_id" {
  type        = string
  description = "Azure Subscription ID"
}

variable "tenant_id" {
  type        = string
  description = "Azure Tenant ID"
}
