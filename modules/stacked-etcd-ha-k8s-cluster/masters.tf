resource "scaleway_server" "masters" {
  count = "${var.masters_replicas}"

  name  = "master-${count.index}"
  image = "${var.masters_base_image}"
  type  = "${var.masters_instance_type}"

  cloudinit = <<EOF
#!/bin/sh

set -e

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

if [ "${count.index}" = 0 ]
then
  cat <<CFG > /root/kubeadm-config.yaml
apiVersion: kubeadm.k8s.io/v1beta1
kind: ClusterConfiguration
kubernetesVersion: stable
apiServer:
  certSANs:
  - "${var.masters_lbs_domain}.${var.cloudflare_zone}"
controlPlaneEndpoint: "${var.masters_lbs_domain}.${var.cloudflare_zone}:6443"
CFG

  dns=$(dig +short ${var.masters_lbs_domain}.${var.cloudflare_zone})
  while [ -z "$dns" ]
  do
    sleep 5s
    echo "Waiting until LBs creation..."
    dns=$(dig +short ${var.masters_lbs_domain}.${var.cloudflare_zone})
  done

  kubeadm init --config /root/kubeadm-config.yaml > /root/join.txt

  kubectl --kubeconfig /etc/kubernetes/admin.conf apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')"
  
  mkdir -p /root/certs/etcd

  cp /etc/kubernetes/pki/ca.crt /root/certs/
  cp /etc/kubernetes/pki/ca.key /root/certs/
  cp /etc/kubernetes/pki/sa.pub /root/certs/
  cp /etc/kubernetes/pki/sa.key /root/certs/
  cp /etc/kubernetes/pki/front-proxy-ca.crt /root/certs/
  cp /etc/kubernetes/pki/front-proxy-ca.key /root/certs/
  cp /etc/kubernetes/pki/etcd/ca.crt /root/certs/etcd/
  cp /etc/kubernetes/pki/etcd/ca.key /root/certs/etcd/
  cp /etc/kubernetes/admin.conf /root/certs/
  cp /root/join.txt /root/certs/

  tar -cvf certs.tar.gz -C /root/certs .

  aws s3 cp certs.tar.gz s3://k8s-clusters-bootstrap/${var.masters_lbs_domain}/

  rm -rf /root/certs
  rm certs.tar.gz
else
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

  tar -xvf /root/certs.tar.gz -C /etc/kubernetes/pki/

  mv /etc/kubernetes/pki/admin.conf /etc/kubernetes/

  sh -c "$(cat /etc/kubernetes/pki/join.txt | grep 'kubeadm join') --experimental-control-plane"

  rm /root/join.sh /etc/kubernetes/pki/join.txt
fi
EOF
}
