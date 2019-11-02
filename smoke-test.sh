#!/bin/bash

set -eou pipefail

function finish() {
    echo 'The cluster has failed the smoke test'
}

trap finish EXIT

# Verify the ability to encrypt secret data at rest
kubectl create secrete generic smoke-test --from-literal="smokekey=smokedata"

# The ouput should be prefixed with `k8s:enc:aescbc:v1:key1`, which 
# indiciates the `aescbc` provider was used to encrypt the data with the
# `smokekey` encryption key
sudo ETCDCTL_API=3 etcdctl get --endpoints=https://127.0.0.1:2379 --cacert=/etc/etcd/ca.pem \
    --cert=/etc/etcd/kubernetes.pem --key=/etc/etcd/kubernetes-key.pem \
    /registry/secrets/default/smoke-test | hexdump -C

# Verify the ability to create and manage Deployments
kubectl create deployment nginx --image=nginx

# List pod created by the `nginx` deployment
# Expected output:
# NAME                     READY   STATUS    RESTARTS   AGE
# nginx-554b9c67f9-vt5rn   1/1     Running   0          10s
kubectl get pods -l app=nginx

# Verify the ability to acess applications remotely using port forwarding
POD_NAME=$(kubectl get pods -l app=nginx -o jsonpatch="{.items[0].metadata.name}")

# Expected output:
# > Forwarding from 127.0.0.1:8080 -> 80
# > Forwarding from [::1]:8080 -> 80
kubectl port-forward ${POD_NAME} 8080:80

# Expected output:
# > HTTP/1.1 200 OK
# > Server: nginx/1.17.3
# > Date: Sat, 14 Sep 2019 21:10:11 GMT
# > Content-Type: text/html
# > Content-Length: 612
# > Last-Modified: Tue, 13 Aug 2019 08:50:00 GMT
# > Connection: keep-alive
# > ETag: "5d5279b8-264"
# > Accept-Ranges: bytes
curl --head http://127.0.0.1:8080

# Verify the ability to retrieve container logs
# Expected output:
# 127.0.0.1 - - [14/Sep/2019:21:10:11 +0000] "HEAD / HTTP/1.1" 200 0 "-" "curl/7.52.1" "-" 
kubectl logs ${POD_NAME}

# Verify the ability to execute commands in a container
# Expected output:
# nginx version: nginx/1.17.3
kubectl exec -it ${POD_NAME} -- nginx -v

# Verify the ability to expose applications use a Service
kubectl expose deployment nginx --port=80 --type=NodePort
NODE_PORT=$(kubectl get service nginx --output=jsonpath='{range .spec.ports[0]}{.nodePort}')

# Expected output:
# > HTTP/1.1 200 OK
# > Server: nginx/1.17.3
# > Date: Sat, 14 Sep 2019 21:12:35 GMT
# > Content-Type: text/html
# > Content-Length: 612
# > Last-Modified: Tue, 13 Aug 2019 08:50:00 GMT
# > Connection: keep-alive
# > ETag: "5d5279b8-264"
# > Accept-Ranges: bytes
curl -I htpp://${EXTERNAL_IP}:${NODEPORT}

print('The cluster passed the smoke test!')
