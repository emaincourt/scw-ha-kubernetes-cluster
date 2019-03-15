resource "scaleway_server" "workers" {
  count = "${var.workers_replicas}"

  name  = "worker-${count.index}"
  image = "${var.workers_base_image}"
  type  = "${var.workers_instance_type}"

  cloudinit = <<EOF
#!/bin/sh

sed -i.bak 's/nameserver 127.0.0.53/nameserver 1.1.1.1/' /etc/resolv.conf

mkdir -p /root/.aws

cat <<AWS > /root/.aws/config
[plugins]
endpoint = awscli_plugin_endpoint

[default]
region = nl-ams
s3 =
  endpoint_url = https://s3.nl-ams.scw.cloud
  max_concurrent_requests = 100
  max_queue_size = 1000
s3api =
  endpoint_url = https://s3.nl-ams.scw.cloud
AWS

  cat <<AWS > /root/.aws/credentials
[default]
aws_access_key_id=${var.scw_access_key}
aws_secret_access_key=${var.scw_access_token}
AWS

exists=$(aws s3 ls | grep k8s-clusters-bootstrap | head -n 1)
while [ -z "$exists" ]
do
  sleep 5s
  echo "Waiting until bucket creation..."
  exists=$(aws s3 ls | grep k8s-clusters-bootstrap | head -n 1)
done

exists=$(aws s3 ls s3://k8s-clusters-bootstrap | grep ${var.masters_lbs_domain} | head -n 1)
while [ -z "$exists" ]
do
  sleep 5s
  echo "Waiting until certificates archive creation..."
  exists=$(aws s3 ls s3://k8s-clusters-bootstrap | grep ${var.masters_lbs_domain} | head -n 1)
done

aws s3 cp s3://k8s-clusters-bootstrap/${var.masters_lbs_domain}/certs.tar.gz /root/certs.tar.gz

mkdir -p /etc/kubernetes/pki

tar -xvf /root/certs.tar.gz -C /root

sh -c "$(cat /root/join.txt | grep 'kubeadm join')"

rm /root/join.sh /etc/kubernetes/pki/join.txt
EOF
}
