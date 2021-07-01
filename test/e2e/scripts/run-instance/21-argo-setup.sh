#!/bin/bash
set -euo pipefail

printf '=%.0s' {0..79} ; echo
set -x

cd "$(dirname "$0")"

for i in {0..60}
do
    kubectl get hpa,svc,ep,ds,deploy,job,po --all-namespaces -o wide && break
    sleep 5
done

set -e

kubectl create namespace argo
kubectl --namespace argo apply -f https://raw.githubusercontent.com/argoproj/argo/stable/manifests/install.yaml

if [[ -n ${DOCKER_REGISTRY_URL+x} ]] && [[ -n ${DOCKER_REGISTRY_LOGIN+x} ]] && [[ -n ${DOCKER_REGISTRY_PWD+x} ]]; then
    oldstate=$(shopt -po xtrace ||:); set +x  # Do not log credentials
    kubectl --namespace argo create secret docker-registry docker-registry --docker-server="$DOCKER_REGISTRY_URL" --docker-username="$DOCKER_REGISTRY_LOGIN" --docker-password="$DOCKER_REGISTRY_PWD"
    eval "$oldstate"
    kubectl --namespace argo patch deployment.apps/argo-server         --type json --patch $'[{"op": "add", "path": "/spec/template/spec/imagePullSecrets", "value": [{"name": "docker-registry"}]}]'
    kubectl --namespace argo patch deployment.apps/workflow-controller --type json --patch $'[{"op": "add", "path": "/spec/template/spec/imagePullSecrets", "value": [{"name": "docker-registry"}]}]'
fi

# TODO use a more restrictive SA
kubectl apply -f - << EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: argo-admin
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: default
  namespace: default
EOF

# From https://github.com/argoproj/argo-workflows/blob/master/docs/workflow-controller-configmap.yaml
kubectl replace -f - << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: workflow-controller-configmap
  namespace: argo
data:
  containerRuntimeExecutor: k8sapi
EOF

set +e

for i in {0..60}
do
    ./argo list && exit 0
    kubectl get hpa,svc,ep,ds,deploy,job,po --all-namespaces -o wide
    sleep 5
done

exit 1
