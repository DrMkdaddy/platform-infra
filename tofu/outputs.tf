output "container_id" {
  description = "VM ID of the managed container."
  value       = proxmox_virtual_environment_container.worker.vm_id
}

output "container_hostname" {
  description = "Hostname of the managed container."
  value       = var.container_hostname
}
