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
variable "k8s_username" {
  description = "Kubernetes username"
  type = string
  default = ""
}
variable "k8s_password" {
  description = "Kubernetes password"
  type = string
  default = ""
}