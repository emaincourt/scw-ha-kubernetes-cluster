resource "scaleway_server" "lbs" {
  count = "${var.masters_lbs_replicas}"

  name  = "masters-lb-${count.index}"
  image = "${var.masters_lbs_base_image}"
  type  = "${var.masters_lbs_instance_type}"

  cloudinit = <<EOF
#!/bin/sh

set -e

sed -i.bak 's/nameserver 127.0.0.53/nameserver 1.1.1.1/' /etc/resolv.conf

apt-get -yq update && apt-get install -y haproxy

cat <<HA > /etc/haproxy/haproxy.cfg
global
    user haproxy
    group haproxy
defaults
    mode http
    log global
    retries 2
    timeout connect 3000ms
    timeout server 5000ms
    timeout client 5000ms
frontend kubernetes
    bind 0.0.0.0:6443
    option tcplog
    mode tcp
    default_backend kubernetes-master-nodes
backend kubernetes-master-nodes
    mode tcp
    balance roundrobin
    option tcp-check
HA

count=0

for host in ${join(" ", scaleway_server.masters.*.private_ip)}
do
  echo "    server k8s-master-$count $host:6443 check fall 3 rise 2" >> /etc/haproxy/haproxy.cfg
  count=$((count + 1))
done

echo "net.ipv4.ip_nonlocal_bind=1" >> /etc/sysctl.conf

sysctl -p

systemctl enable haproxy
systemctl restart haproxy
EOF
}
