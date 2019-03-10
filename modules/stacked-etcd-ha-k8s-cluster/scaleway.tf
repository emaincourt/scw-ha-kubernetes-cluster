provider "scaleway" {
  organization = "${var.scw_organization}"
  token        = "${var.scw_access_token}"
  region       = "${var.scw_region}"
}
