resource "proxmox_virtual_environment_container" "worker" {
  node_name    = var.node_name
  vm_id        = var.container_id
  description  = "Managed by OpenTofu. Manual edits are drift and will be reverted."
  tags         = ["tofu", "managed"]
  unprivileged = true
  started      = true

  initialization {
    hostname = var.container_hostname

    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }

    dynamic "user_account" {
      for_each = var.ssh_public_key == "" ? [] : [1]
      content {
        keys = [var.ssh_public_key]
      }
    }
  }

  cpu {
    cores = 2
  }

  memory {
    dedicated = 1024
  }

  disk {
    datastore_id = var.datastore_id
    size         = 8
  }

  network_interface {
    name   = "eth0"
    bridge = "vmbr0"
  }

  operating_system {
    template_file_id = var.container_template
    type             = "debian"
  }
}
