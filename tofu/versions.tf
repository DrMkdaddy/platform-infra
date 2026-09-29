terraform {
  required_version = ">= 1.6.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.55.0"
    }
  }

  # State is local for the lab. Move it to an S3 or Postgres backend before any
  # shared or cloud use, so two operators cannot apply over each other.
  backend "local" {}
}
