## HA Kubernetes cluster on Scaleway

This Terraform module allows you to deploy a HA Kubernetes cluster. Only stacked topology is currently supported.

Also we make use of Cloudflare to register the private ips of the masters. All machines are exposed publicly but only their private ips are used. You can delete public ips if you do not need to SSH.

Following variables must be set to instantiate the module :

```
variable "scw_organization" {
  type        = "string"
  description = "The organization to create the cluster onto."
}

variable "scw_access_key" {
  type        = "string"
  description = "The secret key to use."
}

variable "scw_access_token" {
  type        = "string"
  description = "The API token to use."
}

variable "scw_region" {
  type        = "string"
  description = "The region where the cluster should be created."
}

variable "cloudflare_email" {
  type        = "string"
  description = "The email to use to sign in to Cloudflare."
}

variable "cloudflare_token" {
  type        = "string"
  description = "The token to use to sign in to Cloudflare."
}

variable "cloudflare_zone" {
  type        = "string"
  description = "The zone to use to create DNS records."
}

variable "masters_replicas" {
  type        = "string"
  description = "The amount of masters to spin up."
}

variable "masters_base_image" {
  type        = "string"
  description = "The base image to use for the masters."
}

variable "masters_instance_type" {
  type        = "string"
  description = "The type of instance to use for the masters."
}

variable "masters_lbs_replicas" {
  type        = "string"
  description = "The amount of Load Balancers to put in front of the masters."
}

variable "masters_lbs_base_image" {
  type        = "string"
  description = "The base image to use for the Load Balancers in front of the masters."
}

variable "masters_lbs_instance_type" {
  type        = "string"
  description = "The type of instance to use for the Load Balancers in front of the masters."
}

variable "masters_lbs_domain" {
  type        = "string"
  description = "The domain that points to all the Load Balancers' ip."
}
```
