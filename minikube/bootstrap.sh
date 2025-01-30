#!/bin/bash

set -eu

# Fonction pour afficher les logs
# Utilise des codes de couleur ANSI pour la mise en forme
function log_msg() {
    local log_type=$1
    local column2=$2

    # Codes de couleur ANSI
    local color_reset="\e[0m"
    local color_bold="\e[1m"
    local color_blue="\e[34m"
    local color_yellow="\e[33m"
    local color_red="\e[31m"

    # Déterminer la couleur en fonction du type de log
    local log_color=""
    case "${log_type}" in
        "INFO")
            log_color="${color_blue}"
            ;;
        "WARN")
            log_color="${color_yellow}"
            ;;
        "ERROR")
            log_color="${color_red}"
            ;;
        *)
            # Par défaut, aucune couleur spécifique
            log_color="${color_reset}"
            ;;
    esac

    # Affichage de la ligne de log
    printf "%b%s%b\t%b%s%b\n" "${color_bold}${log_color}" "[${log_type}]" "${color_reset}" "${color_reset}" "${column2}" "${color_reset}"
}

###############################
## Configuration de minikube
###############################

# Démarrer un nouveau cluster Minikube si nécéssaire
if minikube status > /dev/null 2>&1; then
  log_msg "INFO" "Minikube est déjà en cours d'exécution. Pas besoin de créer un nouveau cluster."
else
  log_msg "INFO" "Minikube n'est pas en cours d'exécution. Démarrage d'un nouveau cluster..."
  minikube start \
    --cpus=max --memory=max \
    --addons=ingress,ingress-dns \
    --install-addons=true \
    --driver=docker || true

  # Vérifier si le démarrage a réussi
  if [ $? -eq 0 ]; then
    log_msg "INFO" "Cluster Minikube démarré avec succès."
  else
    log_msg "ERROR" "Erreur lors du démarrage du cluster Minikube. Veuillez vérifier les logs pour plus d'informations."
    exit 1
  fi
fi


# Configuration de CoreDNS
currentconfig=$(kubectl -n kube-system get configmap coredns -o jsonpath='{ .data.Corefile }')
if [[ $currentconfig == *"test:53"* ]]; then
    log_msg "INFO" "CoreDNS déja configuré, modification de la configuration ignorée"
else
    log_msg "INFO" "CoreDNS non configuré, modification de la configuration..."
    newconfig=$(
    cat <<EOF
    ${currentconfig}
    test:53 {
    errors
    cache 30
    forward . $(minikube ip)
    }
EOF
    )
    patch=$(jq -Rrsc '{"data":{"Corefile":.}}' <<< "${newconfig}")
    kubectl -n kube-system patch configmap coredns -p "${patch}"
fi


###############################
## Configuration de ArgoCD
###############################

kubectl create ns argocd || true
kubectl apply -k argocd/ -n argocd
kubectl apply -f argocd/argocd-project.yaml -n argocd
kubectl apply -f argocd/argocd-ingress.yaml -n argocd

ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo "ArgoCD password: ${ARGOCD_PASSWORD}"
