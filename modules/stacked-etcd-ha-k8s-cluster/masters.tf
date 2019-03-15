resource "scaleway_server" "masters" {
  count = "${var.masters_replicas}"

  name  = "master-${count.index}"
  image = "${var.masters_base_image}"
  type  = "${var.masters_instance_type}"

  cloudinit = <<EOF
#!/bin/sh

echo 'Setting up DNS servers...'

sed -i.bak 's/nameserver 127.0.0.53/nameserver 1.1.1.1/' /etc/resolv.conf

echo 'Setting up S3 credentials...'

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

echo 'Setting up cluster configuration...'

  cat <<CFG > /root/kubeadm-config.yaml
apiVersion: kubeadm.k8s.io/v1beta1
kind: ClusterConfiguration
kubernetesVersion: stable
apiServer:
  certSANs:
  - "${var.masters_lbs_domain}.${var.cloudflare_zone}"
controlPlaneEndpoint: "${var.masters_lbs_domain}.${var.cloudflare_zone}:6443"
CFG

  echo 'Start polling DNSs for host ${var.masters_lbs_domain}.${var.cloudflare_zone}...'

  successes=0
  while [ "$successes" != "5" ]
  do

    dns=$(dig +short ${var.masters_lbs_domain}.${var.cloudflare_zone})

    if [ ! -z "$dns" ]
    then
      successes=$((successes + 1))
      echo "Got $successes successfull response(s)"
    else
      echo "Waiting until LBs creation..."
      sleep 5s
    fi

  done

  echo 'Initializing cluster...'

  kubeadm init --config /root/kubeadm-config.yaml > /root/join.txt

  echo 'Setting up weave...'

  kubectl --kubeconfig /etc/kubernetes/admin.conf apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')"
  
  mkdir -p $HOME/.kube
  cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  chown $(id -u):$(id -g) $HOME/.kube/config

  echo 'Storing generated certificates onto S3...'

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

  echo 'Start polling bucket creation for certificates...'

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

  echo 'Cloning certificates...'

  aws s3 cp s3://k8s-clusters-bootstrap/${var.masters_lbs_domain}/certs.tar.gz /root/certs.tar.gz

  mkdir -p /etc/kubernetes/pki

  tar -xvf /root/certs.tar.gz -C /etc/kubernetes/pki/

  mv /etc/kubernetes/pki/admin.conf /etc/kubernetes/

  echo 'Joining the cluster...'

  sh -c "$(cat /etc/kubernetes/pki/join.txt | grep 'kubeadm join') --experimental-control-plane"

  rm /root/join.sh /etc/kubernetes/pki/join.txt
fi

echo 'Everything went fine.'
EOF
}
