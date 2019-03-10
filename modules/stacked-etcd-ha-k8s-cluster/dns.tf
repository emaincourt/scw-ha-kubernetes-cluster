resource "cloudflare_record" "masters-lbs" {
  count = "${var.masters_lbs_replicas}"

  domain = "${var.cloudflare_zone}"
  name   = "${var.masters_lbs_domain}"
  value  = "${element(scaleway_server.lbs.*.private_ip, count.index)}"
  type   = "A"
  ttl    = 120
}
