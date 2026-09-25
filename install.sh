
#!/bin/bash
set -e

NODE_INDEX=$1
MASTER_IP=$2
MASTER_COUNT=$3

if [ "$NODE_INDEX" -eq 0 ]; then
  echo "[+] Installing first master (cluster-init)"
  curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server --cluster-init --write-kubeconfig-mode 644 --disable local-storage --disable traefik" sh -
else
  echo "[+] Waiting for token from master..."
  MAX_RETRIES=20
  DELAY=5
  for i in $(seq 1 $MAX_RETRIES); do
    TOKEN=$(ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa ubuntu@$MASTER_IP "sudo cat /var/lib/rancher/k3s/server/node-token" 2>/dev/null) && break
    echo "Retrying... ($i/$MAX_RETRIES)"
    sleep $DELAY
  done

  if [ -z "$TOKEN" ]; then
    echo "Failed to get token after $MAX_RETRIES tries"
    exit 1
  fi

  if [ "$NODE_INDEX" -lt "$MASTER_COUNT" ]; then
    echo "[+] Joining as additional master"
    curl -sfL https://get.k3s.io | K3S_URL="https://$MASTER_IP:6443" K3S_TOKEN="$TOKEN" INSTALL_K3S_EXEC="server --disable local-storage --disable traefik" sh -
  else
    echo "[+] Joining as worker"
    curl -sfL https://get.k3s.io | K3S_URL="https://$MASTER_IP:6443" K3S_TOKEN="$TOKEN" sh -
  fi
fi

if [ "$NODE_INDEX" -eq 0 ]; then
  echo "[+] Installing Helm if needed..."
  if ! command -v helm &> /dev/null; then
    curl -fsSL https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
  fi

  echo "[+] Waiting for K3s API to become available..."
  export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

  for i in {1..30}; do
    kubectl get nodes && break
    echo "Waiting for API... ($i/30)"
    sleep 5
  done

  if ! kubectl get nodes; then
    echo "K3s API did not become ready in time"
    exit 1
  fi
  echo "[+] Installing NGINX Ingress Controller"
  helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
  helm repo update
  helm install ingress-nginx ingress-nginx/ingress-nginx \
    --namespace ingress-nginx \
    --create-namespace \
    --set controller.publishService.enabled=true

  echo "[+] NGINX Ingress installed. Use 'kubectl get pods -A' to check readiness."
fi

