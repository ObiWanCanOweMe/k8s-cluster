###################################
# Initial cluster creation
###################################
kubeadm init --pod-network-cidr=10.0.0.0/16
kubectl create -f k8s-networking/tigera-operator.yaml
kubectl create -f k8s-networking/calico.yaml
cp /etc/kubernetes/admin.conf /home/k8s/.kube/config

###################################
# Setup Calico & BGP
###################################
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.9.5/manifests/namespace.yaml
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.9.5/manifests/metallb.yaml
# On first install only
kubectl create secret generic -n metallb-system memberlist --from-literal=secretkey="$(openssl rand -base64 128)"
kubectl create -f bgp-lb/bgpconfig.yaml

###################################
# Setup k8s dashboard
###################################
kubectl create -f k8s-dashboard/dashboard.yaml -f k8s-dashboard/dashboard-clusterrolebinding.yaml -f k8s-dashboard/dashboard-adminuser.yaml
kubectl -n kubernetes-dashboard describe secret $(kubectl -n kube-dashboard get secret | awk '/^kubernetes-dashboard-token-/{print $1}') | awk '$1=="token:"{print $2}'

###################################
# Install Rook Ceph cluster
###################################
kubectl create namespace rook-ceph
helm install --namespace rook-ceph rook-ceph rook-release/rook-ceph
kubectl create -f deploy-rook-cep/cluster.yaml
kubectl create -f toolbox.yaml

###################################
# Reset cluster
###################################
kubectl create namespace monitoring
helm install prometheus prometheus-community/prometheus --namespace monitoring



###################################
# Reset cluster
###################################
yes y | kubeadm reset && rm -rf /etc/cni/net.d && rm -rf /var/lib/rook

#!/usr/bin/env bash
DISK="/dev/sdb"
## Zap the disk to a fresh, usable state (zap-all is important, b/c MBR has to be clean)
## You will have to run this step for all disks.
sgdisk --zap-all $DISK
## Clean hdds with dd
#dd if=/dev/zero of="$DISK" bs=1M count=100 oflag=direct,dsync
## Clean disks such as ssd with blkdiscard instead of dd
blkdiscard $DISK

## These steps only have to be run once on each node
## If rook sets up osds using ceph-volume, teardown leaves some devices mapped that lock the disks.
ls /dev/mapper/ceph-* | xargs -I% -- dmsetup remove %
## ceph-volume setup can leave ceph-<UUID> directories in /dev (unnecessary clutter)
rm -rf /dev/ceph-*