terraform {
  required_providers {
    cofide = {
      source  = "cofide/cofide"
      version = "0.6.0" # Pinned to avoid bug in v0.6.1 (inconsistent plan for `cofide_connect_cluster`)
    }
  }
}

provider "cofide" {}
