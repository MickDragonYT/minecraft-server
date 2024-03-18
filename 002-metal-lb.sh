#!/usr/bin/env bash
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.7/config/manifests/metallb-native.yaml
kubectl wait --namespace metallb-system \
                --for=condition=ready pod \
                --selector=app=metallb \
                --timeout=90s
declare max_ip=$(ipcalc $(docker network inspect -f '{{range .IPAM.Config}}{{println .Subnet}}{{end}}' kind | head -n1)  | grep HostMax | tr -s ' ' | cut -f2 -d' ')
declare min_ip=$(ipcalc ${max_ip} 24 | grep HostMin | tr -s ' ' | cut -f2 -d' ' )
kubectl apply -f  <(cat <<EOF
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: aitomi
  namespace: metallb-system
spec:
  addresses:
  - ${min_ip}-${max_ip}
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: empty
  namespace: metallb-system
EOF
)

