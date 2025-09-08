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
