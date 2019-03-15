resource "scaleway_ip" "masters" {
  count = "${var.masters_replicas}"

  server = "${element(scaleway_server.masters.*.id, count.index)}"
}

resource "scaleway_ip" "lbs" {
  count = "${var.masters_lbs_replicas}"

  server = "${element(scaleway_server.lbs.*.id, count.index)}"
}

resource "scaleway_ip" "workers" {
  count = "${var.workers_replicas}"

  server = "${element(scaleway_server.workers.*.id, count.index)}"
}
