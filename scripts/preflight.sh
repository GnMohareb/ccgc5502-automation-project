#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# preflight.sh - verify a subscription can actually host this assignment
# before spending time on terraform apply.
#
# Usage:
#   ./preflight.sh <subscription-id> [region]
#
# Checks, in order:
#   1. which regions the subscription policy allows
#   2. Total Regional vCPU quota vs the 8 vCPU this deployment needs
#   3. public IP quota vs the 5 addresses this deployment needs
#   4. whether Basic SKU public IPs (and therefore a basic LB) are possible
#   5. whether a usable small x64 VM SKU exists with non-zero family quota
#   6. CentOS 8.2 and Windows Server 2016 image availability
#   7. whether PostgreSQL Single Server can still be provisioned
#
# Every check prints PASS or FAIL with the number behind it. Nothing is
# created except in check 4, which creates and immediately deletes one
# public IP.
# ---------------------------------------------------------------------------
set -uo pipefail

SUB="${1:?usage: preflight.sh <subscription-id> [region]}"
REGION="${2:-canadacentral}"
RG="preflight-5877-rg"

# The student subscription leaks these into every shell via ~/.profile and they
# break authentication against any other subscription.
unset ARM_CLIENT_ID ARM_CLIENT_SECRET ARM_TENANT_ID ARM_ACCESS_KEY

pass() { printf '  \033[32mPASS\033[0m  %s\n' "$1"; }
fail() { printf '  \033[31mFAIL\033[0m  %s\n' "$1"; FAILURES=$((FAILURES+1)); }
info() { printf '  ....  %s\n' "$1"; }
FAILURES=0

az account set --subscription "$SUB" 2>/dev/null || { echo "cannot select subscription $SUB"; exit 1; }
echo "Subscription : $(az account show --query name -o tsv)"
echo "Region       : $REGION"
echo

# --- 1. region policy ------------------------------------------------------
echo "[1] Allowed regions"
ALLOWED=$(az policy assignment list -o json 2>/dev/null \
  | python3 -c "
import sys,json
for a in json.load(sys.stdin):
    p=(a.get('parameters') or {}).get('listOfAllowedLocations')
    if p: print(','.join(p['value']))
" | head -1)
if [ -z "$ALLOWED" ]; then
  pass "no region restriction policy - all regions available"
else
  info "policy restricts to: $ALLOWED"
  case ",$ALLOWED," in
    *",$REGION,"*) pass "$REGION is allowed" ;;
    *) fail "$REGION is NOT allowed by policy" ;;
  esac
fi
echo

# --- 2. vCPU quota ---------------------------------------------------------
echo "[2] vCPU quota (need 8 for four 2-vCPU VMs)"
read -r CUR LIM < <(az vm list-usage -l "$REGION" -o tsv \
  --query "[].{a:localName,b:currentValue,c:limit}" 2>/dev/null \
  | awk -F'\t' '$1=="Total Regional vCPUs"{print $2, $3}')
AVAIL=$(( ${LIM:-0} - ${CUR:-0} ))
info "Total Regional vCPUs: ${CUR:-?}/${LIM:-?} (${AVAIL} free)"
[ "$AVAIL" -ge 8 ] && pass "enough vCPU headroom" || fail "need 8 free vCPU, have $AVAIL"
echo

# --- 3. public IP quota ----------------------------------------------------
echo "[3] Public IP quota (need 5)"
read -r PCUR PLIM < <(az network list-usages -l "$REGION" -o tsv \
  --query "[].{a:name.localizedValue,b:currentValue,c:limit}" 2>/dev/null \
  | awk -F'\t' '$1=="Public IP Addresses"{print $2, $3}')
PAVAIL=$(( ${PLIM:-0} - ${PCUR:-0} ))
info "Public IP Addresses: ${PCUR:-?}/${PLIM:-?} (${PAVAIL} free)"
[ "$PAVAIL" -ge 5 ] && pass "enough public IPs" || fail "need 5 free public IPs, have $PAVAIL"
echo

# --- 4. Basic SKU ----------------------------------------------------------
echo "[4] Basic SKU public IP (the assignment asks for a *basic* load balancer)"
az group create -n "$RG" -l "$REGION" -o none 2>/dev/null
if az network public-ip create -g "$RG" -n preflight-basic-pip \
     --sku Basic --allocation-method Static -l "$REGION" -o none 2>/dev/null; then
  pass "Basic SKU available - a basic load balancer can be used as specified"
  az network public-ip delete -g "$RG" -n preflight-basic-pip 2>/dev/null
else
  fail "Basic SKU blocked - the load balancer must be Standard (documented deviation)"
fi
echo

# --- 5. usable VM SKU ------------------------------------------------------
echo "[5] Usable x64 VM SKU at 1-2 vCPU with non-zero family quota"
az vm list-usage -l "$REGION" -o json > /tmp/pf_usage.json 2>/dev/null
az vm list-skus -l "$REGION" --resource-type virtualMachines --all -o json > /tmp/pf_skus.json 2>/dev/null
python3 - <<'PY'
import json
def num(x):
    try: return int(x)
    except: return 0
usage={u['name']['value']:(num(u['currentValue']),num(u['limit'])) for u in json.load(open('/tmp/pf_usage.json'))}
rows=[]
for s in json.load(open('/tmp/pf_skus.json')):
    if s.get('restrictions'): continue
    cap={c['name']:c['value'] for c in s.get('capabilities',[])}
    v=num(cap.get('vCPUs',0))
    if not (0 < v <= 2): continue
    if cap.get('CpuArchitectureType','x64') != 'x64': continue
    cur,lim=usage.get(s.get('family'),(0,0))
    if lim >= 8: rows.append((v,s['name'],f'{cur}/{lim}'))
rows.sort()
if rows:
    for v,n,q in rows[:5]:
        print(f'  ....  {v} vCPU  {n:22s} family quota {q}')
    print(f'  \033[32mPASS\033[0m  {len(rows)} usable SKU(s); recommend {rows[0][1]}')
else:
    print('  \033[31mFAIL\033[0m  no x64 SKU at 1-2 vCPU has family quota >= 8')
PY
echo

# --- 6. images -------------------------------------------------------------
echo "[6] Required OS images"
if az vm image list-skus -l "$REGION" -p OpenLogic -f CentOS -o tsv --query "[].name" 2>/dev/null | grep -qx "8_2"; then
  pass "CentOS 8_2 available"
else
  fail "CentOS 8_2 NOT available in $REGION"
fi
if az vm image list -p MicrosoftWindowsServer -f WindowsServer --sku 2016-Datacenter --all -o tsv --query "[0].urn" 2>/dev/null | grep -q 2016; then
  pass "Windows Server 2016 Datacenter available"
else
  fail "Windows Server 2016 NOT available"
fi
echo

# --- 7. PostgreSQL Single Server ------------------------------------------
echo "[7] PostgreSQL Single Server (assignment specifies Single, not Flexible)"
SS=$(az provider show -n Microsoft.DBforPostgreSQL -o json 2>/dev/null | python3 -c "
import sys,json
d=json.load(sys.stdin)
for rt in d['resourceTypes']:
    if rt['resourceType']=='servers':
        av=rt.get('apiVersions',[])
        print(av[0] if av else 'NONE')
")
info "newest 'servers' API version: ${SS:-unknown}"
case "$SS" in
  2017-12-01*) fail "Single Server API is frozen - expect InvalidElasticServerType; use Flexible Server" ;;
  NONE|"")     fail "Single Server unavailable - use Flexible Server" ;;
  *)           pass "Single Server API looks current" ;;
esac
echo

az group delete -n "$RG" --yes --no-wait 2>/dev/null

echo "==========================================="
if [ "$FAILURES" -eq 0 ]; then
  echo "  ALL CHECKS PASSED - safe to terraform apply"
else
  echo "  $FAILURES CHECK(S) FAILED - see above before applying"
fi
echo "==========================================="
exit 0
