terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "3.5.0"
    }
  }
}

provider "google" {
  credentials = file(var.path_to_service_account_key)

  project = var.project_name

  region = "us-central1"
  zone   = "us-central1-a"
}

variable "path_to_service_account_key" {
	type = string
	description = "Path to service account key file"
}

variable "project_name" {
	type = string
	description = "Name of project"
}

variable "service_account_name" {
	type = string
	description = "Name of service account"
}

variable "allow_ip_ssh" {
	type = string
	description = "Your IP so that SSH can be allowed through firewall"
}
