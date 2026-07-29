#!/usr/bin/env bash
# Deploy (or destroy) the multi-cluster lifecycle ShadowTraffic aggregator
# after instructor-led account applies.
#
# Usage:
#   scripts/wsa-deploy-lifecycle-st.sh apply  --run-id <id> [--cloud azure|aws]
#   scripts/wsa-deploy-lifecycle-st.sh destroy --run-id <id> [--cloud azure|aws]
#
# Teardown order for instructor-led:
#   1) this script destroy   (while shared VM SSH still works)
#   2) wsa clean             (accounts, then shared)
#
# Env:
#   WSA_OUTPUT_DIR  — parent of run dirs (default: sibling workshop-setup-accelerator/wsa-output
#                     or ./wsa-output if present)

set -euo pipefail

ACTION="${1:-}"
shift || true

CLOUD="azure"
RUN_ID="${WSA_RUN_ID:-}"
AUTO_APPROVE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-id) RUN_ID="$2"; shift 2 ;;
    --cloud) CLOUD="$2"; shift 2 ;;
    --auto-approve|-auto-approve) AUTO_APPROVE=true; shift ;;
    -y) AUTO_APPROVE=true; shift ;;
    *)
      echo "Unknown arg: $1" >&2
      exit 2
      ;;
  esac
done

if [[ -z "$ACTION" || -z "$RUN_ID" ]]; then
  echo "Usage: $0 apply|destroy --run-id <id> [--cloud azure|aws] [--auto-approve]" >&2
  exit 2
fi

case "$CLOUD" in
  azure|aws) ;;
  *)
    echo "cloud must be azure or aws" >&2
    exit 2
    ;;
esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [[ -n "${WSA_OUTPUT_DIR:-}" ]]; then
  OUTPUT_ROOT="$WSA_OUTPUT_DIR"
elif [[ -d "$REPO_ROOT/wsa-output" ]]; then
  OUTPUT_ROOT="$REPO_ROOT/wsa-output"
elif [[ -d "$REPO_ROOT/../Tools/workshop-setup-accelerator/wsa-output" ]]; then
  OUTPUT_ROOT="$(cd "$REPO_ROOT/../Tools/workshop-setup-accelerator/wsa-output" && pwd)"
elif [[ -d "$REPO_ROOT/../../Tools/workshop-setup-accelerator/wsa-output" ]]; then
  OUTPUT_ROOT="$(cd "$REPO_ROOT/../../Tools/workshop-setup-accelerator/wsa-output" && pwd)"
else
  OUTPUT_ROOT="$REPO_ROOT/wsa-output"
fi

RUN_DIR="$OUTPUT_ROOT/$RUN_ID"
if [[ ! -d "$RUN_DIR" ]]; then
  # cleaned runs are renamed
  if [[ -d "$OUTPUT_ROOT/${RUN_ID}-cleaned" ]]; then
    echo "Run $RUN_ID looks cleaned ($OUTPUT_ROOT/${RUN_ID}-cleaned). Cannot deploy." >&2
    exit 1
  fi
  echo "Run directory not found: $RUN_DIR" >&2
  echo "Set WSA_OUTPUT_DIR if wsa-output lives elsewhere." >&2
  exit 1
fi

ACCOUNT_TF="$RUN_DIR/terraform/$CLOUD"
SHARED_TF="$RUN_DIR/terraform/${CLOUD}-shared"
LIFE_NAME="${CLOUD}-lifecycle-st"
# Prefer staged copy under the run dir (wsa stages terraform/); fall back to repo.
if [[ -f "$RUN_DIR/terraform/$LIFE_NAME/main.tf" ]]; then
  LIFE_TF="$RUN_DIR/terraform/$LIFE_NAME"
else
  LIFE_TF="$REPO_ROOT/terraform/$LIFE_NAME"
  mkdir -p "$RUN_DIR/terraform/$LIFE_NAME"
fi

if [[ ! -d "$ACCOUNT_TF" ]]; then
  echo "Missing account terraform root: $ACCOUNT_TF" >&2
  exit 1
fi
if [[ ! -d "$SHARED_TF" ]]; then
  echo "Missing shared terraform root: $SHARED_TF" >&2
  exit 1
fi
if [[ ! -f "$LIFE_TF/main.tf" ]]; then
  echo "Missing lifecycle-st root: $LIFE_TF" >&2
  exit 1
fi

tf_shared() {
  terraform -chdir="$SHARED_TF" "$@"
}

tf_account() {
  local ws="$1"
  shift
  terraform -chdir="$ACCOUNT_TF" workspace select "$ws" >/dev/null
  terraform -chdir="$ACCOUNT_TF" "$@"
}

collect_clusters_json() {
  local workspaces
  workspaces="$(terraform -chdir="$ACCOUNT_TF" workspace list 2>/dev/null | sed 's/[* ]//g' | grep -E '^account-' || true)"
  if [[ -z "$workspaces" ]]; then
    echo "No account-* workspaces found under $ACCOUNT_TF" >&2
    exit 1
  fi

  local clusters='[]'
  local ws raw
  for ws in $workspaces; do
    echo "Reading lifecycle_st_cluster from workspace $ws..." >&2
    if ! raw="$(tf_account "$ws" output -json lifecycle_st_cluster 2>/dev/null)"; then
      echo "WARN: workspace $ws missing lifecycle_st_cluster — skipping" >&2
      continue
    fi
    clusters="$(jq -c --argjson c "$raw" '. + [$c]' <<<"$clusters")"
  done

  if [[ "$(jq 'length' <<<"$clusters")" -eq 0 ]]; then
    echo "No clusters collected — cannot deploy lifecycle ST" >&2
    exit 1
  fi
  echo "$clusters"
}

write_tfvars() {
  local clusters_json="$1"
  local ssh_host ssh_user ssh_key

  if [[ "$CLOUD" == "azure" ]]; then
    ssh_host="$(tf_shared output -raw postgres_public_ip)"
    ssh_user="$(tf_shared output -raw postgres_ssh_username 2>/dev/null || echo azureuser)"
    ssh_key="$(tf_shared output -raw postgres_ssh_private_key_path)"
  else
    # Prefer public IP for SSH; hostname also works
    ssh_host="$(tf_shared output -raw postgres_public_ip 2>/dev/null || tf_shared output -raw postgres_hostname)"
    ssh_user="$(tf_shared output -raw postgres_ssh_username 2>/dev/null || echo ec2-user)"
    ssh_key="$(tf_shared output -raw postgres_ssh_private_key_path 2>/dev/null || tf_shared output -raw private_key_path)"
  fi

  # Ensure absolute path (outputs should already be abspath)
  if [[ "$ssh_key" != /* ]]; then
    ssh_key="$(cd "$(dirname "$ssh_key")" && pwd)/$(basename "$ssh_key")"
  fi

  local out="$LIFE_TF/clusters.auto.tfvars.json"
  # When using repo LIFE_TF with state in run dir, still write tfvars next to config
  # and also copy into run-dir state home for operators.
  jq -n \
    --argjson clusters "$clusters_json" \
    --arg ssh_host "$ssh_host" \
    --arg ssh_user "$ssh_user" \
    --arg ssh_private_key_path "$ssh_key" \
    '{
      clusters: $clusters,
      ssh_host: $ssh_host,
      ssh_user: $ssh_user,
      ssh_private_key_path: $ssh_private_key_path,
      enabled: true
    }' >"$out"

  # When LIFE_TF is already the run-dir copy, $out lives there — skip no-op cp
  # (macOS `cp identical identical` exits non-zero and trips set -e).
  local run_out="$RUN_DIR/terraform/$LIFE_NAME/clusters.auto.tfvars.json"
  mkdir -p "$RUN_DIR/terraform/$LIFE_NAME"
  if [[ "$(cd "$(dirname "$out")" && pwd)/$(basename "$out")" != "$(cd "$(dirname "$run_out")" && pwd)/$(basename "$run_out")" ]]; then
    cp "$out" "$run_out"
  fi
  echo "Wrote $out ($(jq '.clusters | length' "$out") clusters)" >&2
}

apply_or_destroy() {
  local tf_args=()
  if [[ "$AUTO_APPROVE" == true ]]; then
    tf_args+=(-auto-approve)
  fi

  # Keep state under the run directory even if code is from the workshop tree.
  local state_dir="$RUN_DIR/terraform/$LIFE_NAME"
  mkdir -p "$state_dir"

  # If LIFE_TF is the run-dir copy, normal state path is fine.
  # If LIFE_TF is the workshop tree, pass -state explicitly.
  local -a extra=()
  if [[ "$LIFE_TF" != "$state_dir" ]]; then
    extra+=(-state="$state_dir/terraform.tfstate")
  fi

  terraform -chdir="$LIFE_TF" init -input=false

  # Under `set -u`, empty "${arr[@]}" can error on some bash builds — expand safely.
  if [[ "$ACTION" == "apply" ]]; then
    terraform -chdir="$LIFE_TF" apply -input=false ${extra[@]+"${extra[@]}"} ${tf_args[@]+"${tf_args[@]}"}
  else
    terraform -chdir="$LIFE_TF" destroy -input=false ${extra[@]+"${extra[@]}"} ${tf_args[@]+"${tf_args[@]}"}
  fi
}

case "$ACTION" in
  apply)
    clusters="$(collect_clusters_json)"
    write_tfvars "$clusters"
    apply_or_destroy
    echo "Lifecycle multi-cluster ShadowTraffic applied (container: shadowtraffic-lifecycle)."
    ;;
  destroy)
    if [[ -f "$LIFE_TF/clusters.auto.tfvars.json" || -f "$RUN_DIR/terraform/$LIFE_NAME/clusters.auto.tfvars.json" ]]; then
      if [[ ! -f "$LIFE_TF/clusters.auto.tfvars.json" && -f "$RUN_DIR/terraform/$LIFE_NAME/clusters.auto.tfvars.json" ]]; then
        cp "$RUN_DIR/terraform/$LIFE_NAME/clusters.auto.tfvars.json" "$LIFE_TF/clusters.auto.tfvars.json"
      fi
      apply_or_destroy
    else
      echo "No clusters.auto.tfvars.json — attempting destroy with empty clusters (no-op deploy)."
      # Still try destroy if state exists
      apply_or_destroy
    fi
    echo "Lifecycle multi-cluster ShadowTraffic destroyed."
    ;;
  *)
    echo "Action must be apply or destroy" >&2
    exit 2
    ;;
esac
