#!/bin/bash

set -eu

ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo "ArgoCD password: "
echo "${ARGOCD_PASSWORD}"

# echo -n "${ARGOCD_PASSWORD}" | xclip -selection clipboard
# echo "ArgoCD password in clipboard"