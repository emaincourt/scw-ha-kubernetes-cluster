resource "cloudflare_record" "masters-lbs" {
  domain = "${var.cloudflare_zone}"
  name   = "${var.masters_lbs_domain}"
  value  = "${element(scaleway_server.lbs.*.private_ip, 0)}"
  type   = "A"
  ttl    = 120
}
