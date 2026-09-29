variable "proxmox_endpoint" {
  description = "Proxmox VE API endpoint, including scheme and port."
  type        = string
}

variable "proxmox_api_token" {
  description = "Proxmox API token in the form user@realm!tokenid=secret."
  type        = string
  sensitive   = true
}

variable "proxmox_insecure" {
  description = "Skip TLS verification. Only for a self-signed lab endpoint."
  type        = bool
  default     = false
}

variable "node_name" {
  description = "Proxmox node that hosts the managed container."
  type        = string
  default     = "pve"
}

variable "container_id" {
  description = "VM ID for the managed container. Must be free on the node."
  type        = number
  default     = 900
}

variable "container_hostname" {
  description = "Hostname assigned to the managed container."
  type        = string
  default     = "tofu-worker"
}

variable "container_template" {
  description = "Volume ID of the LXC template to clone, for example local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst"
  type        = string
}

variable "datastore_id" {
  description = "Datastore that holds the container root filesystem."
  type        = string
  default     = "local-lvm"
}

variable "ssh_public_key" {
  description = "Public key injected into the container for administrative access. Leave empty to set a password instead."
  type        = string
  default     = ""
}
