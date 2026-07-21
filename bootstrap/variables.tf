variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "location" {
  description = "Azure region for bootstrap resources"
  type        = string
  default     = "southcentralus"
}

variable "tenant_id" {
  description = "Microsoft Entra tenant ID"
  type        = string
}

variable "github_owner" {
  description = "GitHub username or organization"
  type        = string
}

variable "github_repository" {
  description = "GitHub repository name"
  type        = string
  default     = "azure-cyber-range"
}

variable "github_app_id" {
  description = "Atlantis GitHub App ID; use 0 during the first deployment"
  type        = string
  default     = "0"
}

variable "atlantis_image" {
  description = "Atlantis container image"
  type        = string
  default     = "ghcr.io/runatlantis/atlantis:latest"
}