terraform {
  required_version = ">= 1.3.0"
  # backend "gcs" {
  #   bucket         = "terraform-state-bucket"
  #   prefix         = "cloudrun"
  # }
  backend "local" {
    path = "./terraform.tfstate"
  }
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}