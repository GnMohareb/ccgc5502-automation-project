#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# bootstrap-backend.sh - create the Terraform remote state backend in a new
# subscription, then rewrite backend.tf to point at it.
#
# Usage:
#   ./bootstrap-backend.sh <subscription-id> [region]
#
# The current backend lives in the Azure for Students subscription
# (sttfn01275877lab06 / rg-tfstate-n01275877). Moving to pay-as-you-go means
# creating a fresh state container there, because the marking video runs a
# plain `terraform init` with no -backend-config flags - so backend.tf must
# contain real values.
#
# Safe to re-run: every step is idempotent.
# ---------------------------------------------------------------------------
set -euo pipefail

SUB="${1:?usage: bootstrap-backend.sh <subscription-id> [region]}"
REGION="${2:-canadacentral}"

RG="rg-tfstate-5877"
CONTAINER="tfstate"
# Storage account names must be globally unique, 3-24 chars, lowercase
# alphanumeric only, and start with a letter.
SA="sttf5877$(echo -n "$SUB" | md5sum | cut -c1-8)"

unset ARM_CLIENT_ID ARM_CLIENT_SECRET ARM_TENANT_ID ARM_ACCESS_KEY

az account set --subscription "$SUB"
echo "Subscription : $(az account show --query name -o tsv)"
echo "Region       : $REGION"
echo "Storage acct : $SA"
echo

echo "==> resource group"
az group create -n "$RG" -l "$REGION" -o none
echo "    $RG ready"

echo "==> storage account"
if az storage account show -g "$RG" -n "$SA" -o none 2>/dev/null; then
  echo "    $SA already exists"
else
  az storage account create \
    -g "$RG" -n "$SA" -l "$REGION" \
    --sku Standard_LRS --kind StorageV2 \
    --min-tls-version TLS1_2 \
    --allow-blob-public-access false \
    -o none
  echo "    $SA created"
fi

echo "==> blob container"
az storage container create \
  --account-name "$SA" --name "$CONTAINER" \
  --auth-mode login -o none
echo "    $CONTAINER ready"

echo "==> rewriting backend.tf"
BACKEND="$(dirname "$0")/../backend.tf"
cat > "$BACKEND" <<TFEOF
terraform {
  backend "azurerm" {
    resource_group_name  = "$RG"
    storage_account_name = "$SA"
    container_name       = "$CONTAINER"
    key                  = "assignment1-5877.terraform.tfstate"
  }
}
TFEOF
echo "    backend.tf now points at $SA"

echo
echo "Done. Next:"
echo "  export ARM_SUBSCRIPTION_ID=$SUB"
echo "  cd $(cd "$(dirname "$0")/.." && pwd)"
echo "  terraform init -reconfigure"
