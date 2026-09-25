
#!/bin/bash
set -euo pipefail

NODE_INDEX="${1:-}"
MASTER_IP="${2:-}"
MASTER_COUNT="${3:-}"

K3S_VERSION="${K3S_VERSION:-v1.33.3+k3s1}"
SSH_KEY="/home/ubuntu/.ssh/id_rsa"

if [ -z "$NODE_INDEX" ] || [ -z "$MASTER_IP" ] || [ -z "$MASTER_COUNT" ]; then
  echo "Usage: $0 <NODE_INDEX> <MASTER_IP> <MASTER_COUNT>"
  exit 1
fi

echo "[+] NODE_INDEX=$NODE_INDEX"
echo "[+] MASTER_IP=$MASTER_IP"
echo "[+] MASTER_COUNT=$MASTER_COUNT"
echo "[+] K3S_VERSION=$K3S_VERSION"

# ============================================================
# FIRST MASTER
# ============================================================

if [ "$NODE_INDEX" -eq 0 ]; then

  echo "[+] Installing first master (cluster-init)"

  curl -sfL https://get.k3s.io | \
    INSTALL_K3S_VERSION="$K3S_VERSION" \
    INSTALL_K3S_EXEC="server \
      --cluster-init \
      --write-kubeconfig-mode 644 \
      --disable local-storage \
      --disable traefik" \
    sh -

  echo "[+] Waiting for K3s API..."

  export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

  MAX_RETRIES=60
  DELAY=5

  for i in $(seq 1 "$MAX_RETRIES"); do
    if kubectl get nodes >/dev/null 2>&1; then
      echo "[+] K3s API is ready"
      break
    fi

    echo "[+] Waiting for API... ($i/$MAX_RETRIES)"
    sleep "$DELAY"
  done

  if ! kubectl get nodes >/dev/null 2>&1; then
    echo "[-] K3s API did not become ready"
    exit 1
  fi

  echo "[+] First master is ready"

# ============================================================
# ADDITIONAL MASTERS / WORKERS
# ============================================================

else

  echo "[+] Waiting for master API..."

  MAX_RETRIES=60
  DELAY=5

  for i in $(seq 1 "$MAX_RETRIES"); do

    if curl -kfsS \
      "https://${MASTER_IP}:6443/readyz" \
      >/dev/null 2>&1; then

      echo "[+] Master API is ready"
      break
    fi

    echo "[+] Waiting for master API... ($i/$MAX_RETRIES)"
    sleep "$DELAY"
  done

  if ! curl -kfsS \
    "https://${MASTER_IP}:6443/readyz" \
    >/dev/null 2>&1; then

    echo "[-] Master API did not become ready"
    exit 1
  fi

  # ==========================================================
  # GET K3S TOKEN
  # ==========================================================

  echo "[+] Waiting for K3s token..."

  TOKEN=""

  for i in $(seq 1 "$MAX_RETRIES"); do

    TOKEN=$(ssh \
      -o StrictHostKeyChecking=no \
      -o ConnectTimeout=5 \
      -o BatchMode=yes \
      -i "$SSH_KEY" \
      ubuntu@"$MASTER_IP" \
      "sudo cat /var/lib/rancher/k3s/server/node-token" \
      2>/dev/null || true)

    if [ -n "$TOKEN" ]; then
      echo "[+] Successfully retrieved K3s token"
      break
    fi

    echo "[+] Token not available yet... ($i/$MAX_RETRIES)"
    sleep "$DELAY"
  done

  if [ -z "$TOKEN" ]; then
    echo "[-] Failed to get K3s token"
    exit 1
  fi

  # ==========================================================
  # ADDITIONAL MASTER
  # ==========================================================

  if [ "$NODE_INDEX" -lt "$MASTER_COUNT" ]; then

    echo "[+] Joining as additional master"

    curl -sfL https://get.k3s.io | \
      INSTALL_K3S_VERSION="$K3S_VERSION" \
      K3S_URL="https://${MASTER_IP}:6443" \
      K3S_TOKEN="$TOKEN" \
      INSTALL_K3S_EXEC="server \
        --disable local-storage \
        --disable traefik" \
      sh -

    echo "[+] Additional master joined"

  # ==========================================================
  # WORKER
  # ==========================================================

  else

    echo "[+] Joining as worker"

    curl -sfL https://get.k3s.io | \
      INSTALL_K3S_VERSION="$K3S_VERSION" \
      K3S_URL="https://${MASTER_IP}:6443" \
      K3S_TOKEN="$TOKEN" \
      INSTALL_K3S_EXEC="agent" \
      sh -

    echo "[+] Worker joined"

  fi

fi

# ============================================================
# FIRST MASTER ONLY
# HELM + NGINX INGRESS
# ============================================================

if [ "$NODE_INDEX" -eq 0 ]; then

  echo "[+] Installing Helm if needed..."

  if ! command -v helm >/dev/null 2>&1; then
    curl -fsSL \
      https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 \
      | bash
  fi

  export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

  echo "[+] Adding ingress-nginx Helm repository..."

  helm repo add ingress-nginx \
    https://kubernetes.github.io/ingress-nginx \
    2>/dev/null || true

  helm repo update

  echo "[+] Installing NGINX Ingress Controller..."

  helm upgrade --install ingress-nginx \
    ingress-nginx/ingress-nginx \
    --namespace ingress-nginx \
    --create-namespace \
    --set controller.publishService.enabled=true \
    --wait \
    --timeout 5m

  echo "[+] Waiting for NGINX Ingress Controller..."

  kubectl rollout status \
    deployment/ingress-nginx-controller \
    -n ingress-nginx \
    --timeout=300s

  echo ""
  echo "[+] K3s cluster status:"
  kubectl get nodes -o wide

  echo ""
  echo "[+] NGINX Ingress status:"
  kubectl get pods -n ingress-nginx

  echo ""
  echo "[+] NGINX Ingress service:"
  kubectl get svc -n ingress-nginx

  echo ""
  echo "[+] K3s bootstrap completed successfully"

fi
