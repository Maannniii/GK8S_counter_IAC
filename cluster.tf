variable "project" {
  description = "Google Cloud project ID"
  default = "projectid"
}
variable "region" {
  description = "Google Cluster Region"
  default = "asia-southeast1"
}
variable "credentials" {
  description = "Google Cloud Service Account"
  default = "account.json"
}

provider "google" {
  project = var.project
  region = var.region
  credentials = file(var.credentials)
}