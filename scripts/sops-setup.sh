#!/bin/bash
set -euo pipefail

# SOPS + age setup script for Flux
# This script helps with initial SOPS configuration
#
# sops-setup.sh - set up the age key that SOPS encrypts with and Flux decrypts with.
#   - the private key lives in age.agekey at the repository root (git-ignored, never committed);
#   - its public half goes into .sops.yaml, so `sops` knows whom to encrypt for;
#   - a copy of the private key goes into the cluster as the Secret flux-system/sops-age, so Flux
#     can decrypt what is committed.
# The course uses `--local` (Chapter 00): it reuses the key the kind module already generated,
# registers it for flux/secrets/local/ only and checks that the cluster holds the same key.
# The other modes are the manual steps for a platform key.
#
# Usage: scripts/sops-setup.sh --local | --generate | --create-secret | --update-config | --all
# Needs: age, sops, kubectl; KUBE_CONTEXT names the cluster (default kind-sre-control-plane).
# Changes: age.agekey (only when it is missing, or on a confirmed --generate), .sops.yaml (--local),
# the sops-age Secret in the cluster (--create-secret, --all, --local when the Secret is missing).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
AGE_KEY_FILE="${REPO_ROOT}/age.agekey"

# Every kubectl call names its cluster (Chapter 01) - never the shared current context, which
# another terminal or an AI agent may have switched to a different cluster.
# KUBE_CONTEXT=hetzner-sre-control-plane for the Hetzner cluster.
KUBE_CONTEXT="${KUBE_CONTEXT:-kind-sre-control-plane}"
# k <kubectl args> - kubectl against KUBE_CONTEXT; the only way this script talks to a cluster.
k() { kubectl --context "${KUBE_CONTEXT}" "$@"; }

echo "🔐 SOPS + age Setup for Flux"
echo "============================"
echo

# Check if tools are installed
check_tools() {
    echo "📋 Checking required tools..."

    if ! command -v age &> /dev/null; then
        echo "❌ age is not installed"
        echo "   Install: brew install age (macOS) or apt install age (Linux)"
        exit 1
    fi

    if ! command -v sops &> /dev/null; then
        echo "❌ sops is not installed"
        echo "   Install: brew install sops (macOS) or see https://github.com/getsops/sops"
        exit 1
    fi

    if ! command -v kubectl &> /dev/null; then
        echo "❌ kubectl is not installed"
        exit 1
    fi

    echo "✅ All tools are installed"
    echo
}

# Generate age key if it doesn't exist
# (an existing key is replaced only after you confirm, and kept as a timestamped .bak first -
# files encrypted for the old key need it to open).
generate_age_key() {
    if [[ -f "${AGE_KEY_FILE}" ]]; then
        echo "⚠️  age key already exists at: ${AGE_KEY_FILE}"
        echo "   Public key:"
        grep "# public key:" "${AGE_KEY_FILE}" | cut -d: -f2 | tr -d ' '
        echo
        read -p "   Generate new key? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return
        fi
        mv "${AGE_KEY_FILE}" "${AGE_KEY_FILE}.$(date +%Y%m%d-%H%M%S).bak"
        echo "   Backed up old key"
    fi

    echo "🔑 Generating new age key pair..."
    age-keygen -o "${AGE_KEY_FILE}"

    PUBLIC_KEY=$(grep "# public key:" "${AGE_KEY_FILE}" | cut -d: -f2 | tr -d ' ')

    echo
    echo "✅ Age key generated!"
    echo "   Private key: ${AGE_KEY_FILE}"
    echo "   Public key:  ${PUBLIC_KEY}"
    echo
    echo "⚠️  IMPORTANT:"
    echo "   1. Backup ${AGE_KEY_FILE} securely (DO NOT COMMIT TO GIT!)"
    echo "   2. Update .sops.yaml with the public key"
    echo "   3. Create sops-age secret in Kubernetes (see below)"
    echo
}

# Create sops-age secret in Kubernetes
# (in KUBE_CONTEXT, from age.agekey; an existing Secret is replaced only after you confirm).
create_k8s_secret() {
    if [[ ! -f "${AGE_KEY_FILE}" ]]; then
        echo "❌ Age key not found at: ${AGE_KEY_FILE}"
        echo "   Run with --generate first"
        exit 1
    fi

    echo "📦 Creating sops-age secret in Kubernetes..."
    echo

    # The named context must exist and answer
    if ! kubectl config get-contexts "${KUBE_CONTEXT}" &> /dev/null; then
        echo "❌ kubectl context '${KUBE_CONTEXT}' not found (set KUBE_CONTEXT)"
        exit 1
    fi
    if ! k cluster-info &> /dev/null; then
        echo "❌ cluster '${KUBE_CONTEXT}' does not answer"
        echo "   Make sure your cluster is running"
        exit 1
    fi
    echo "   cluster: ${KUBE_CONTEXT}"

    # Check if flux-system namespace exists
    if ! k get namespace flux-system &> /dev/null; then
        echo "❌ flux-system namespace not found"
        echo "   Make sure Flux is installed in your cluster"
        exit 1
    fi

    # Check if secret already exists
    if k get secret sops-age -n flux-system &> /dev/null; then
        echo "⚠️  sops-age secret already exists in flux-system namespace"
        read -p "   Replace it? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            k delete secret sops-age -n flux-system
        else
            echo "   Skipping secret creation"
            return
        fi
    fi

    # Create secret - the key is read from the file on stdin, never put on the command line.
    k create secret generic sops-age \
        --namespace=flux-system \
        --from-file=age.agekey=/dev/stdin < "${AGE_KEY_FILE}"

    echo "✅ sops-age secret created in flux-system namespace"
    echo
}

# Update .sops.yaml with public key
# (prints the public key and what to put in .sops.yaml; it does not edit the file).
update_sops_config() {
    if [[ ! -f "${AGE_KEY_FILE}" ]]; then
        echo "❌ Age key not found at: ${AGE_KEY_FILE}"
        exit 1
    fi

    PUBLIC_KEY=$(grep "# public key:" "${AGE_KEY_FILE}" | cut -d: -f2 | tr -d ' ')
    SOPS_CONFIG="${REPO_ROOT}/.sops.yaml"

    echo "📝 Update .sops.yaml with public key:"
    echo "   ${PUBLIC_KEY}"
    echo
    echo "   Replace all 'age:' lines in ${SOPS_CONFIG} with:"
    echo "   age: ${PUBLIC_KEY}"
    echo
}

# Register the local key in .sops.yaml (local profile rule only).
# The platform rules keep the SafeOps key; learners only ever encrypt under
# flux/secrets/local/, which is what the local Flux profile decrypts.
update_local_sops_rule() {
    if [[ ! -f "${AGE_KEY_FILE}" ]]; then
        echo "❌ Age key not found at: ${AGE_KEY_FILE}"
        exit 1
    fi
    PUBLIC_KEY=$(grep "# public key:" "${AGE_KEY_FILE}" | cut -d: -f2 | tr -d ' ')
    SOPS_CONFIG="${REPO_ROOT}/.sops.yaml"

    if ! grep -q "path_regex: flux/secrets/local/" "${SOPS_CONFIG}"; then
        echo "❌ No flux/secrets/local rule in ${SOPS_CONFIG}"
        exit 1
    fi
    # Replace only the recipient on the line that follows the local path rule.
    awk -v key="${PUBLIC_KEY}" '
        /path_regex: flux\/secrets\/local\// { in_local = 1 }
        in_local && /^[[:space:]]*age: / { sub(/age: .*/, "age: " key); in_local = 0 }
        { print }
    ' "${SOPS_CONFIG}" > "${SOPS_CONFIG}.tmp" && mv "${SOPS_CONFIG}.tmp" "${SOPS_CONFIG}"

    echo "✅ .sops.yaml: flux/secrets/local/** now encrypts to ${PUBLIC_KEY}"
    echo "   Commit .sops.yaml in your fork; keep ${AGE_KEY_FILE} out of Git."
    echo
}

# Show usage
usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Setup SOPS + age encryption for Flux GitOps

OPTIONS:
    --generate          Generate new age key pair
    --create-secret     Create sops-age secret in Kubernetes
    --update-config     Show instructions for updating .sops.yaml
    --all               Run all steps (generate, create secret, show config)
    --local             Local (kind) profile: generate key if missing, register
                        its public half for flux/secrets/local/ in .sops.yaml,
                        and create/refresh the sops-age secret in the cluster
    -h, --help          Show this help message

Every kubectl call uses the context in KUBE_CONTEXT (default: kind-sre-control-plane).

EXAMPLES:
    # Initial setup (all steps)
    $0 --all

    # Just generate age key
    $0 --generate

    # Create Kubernetes secret (after generating key)
    $0 --create-secret

EOF
}

# Main
# main <option> - run the steps of one option (see usage).
main() {
    case "${1:-}" in
        --generate)
            check_tools
            generate_age_key
            update_sops_config
            ;;
        --create-secret)
            check_tools
            create_k8s_secret
            ;;
        --update-config)
            update_sops_config
            ;;
        --all)
            check_tools
            generate_age_key
            create_k8s_secret
            update_sops_config
            ;;
        --local)
            check_tools
            if [[ ! -f "${AGE_KEY_FILE}" ]]; then
                generate_age_key
            else
                echo "🔑 Using existing key: ${AGE_KEY_FILE}"
            fi
            # The cluster side first: .sops.yaml is changed only once the cluster is known to hold
            # this key, so a failure here leaves the configuration untouched.
            # infra/terraform/kind_cluster already created sops-age from this key file; only create
            # it when it is missing (no prompts - this runs inside course labs and CI).
            if k -n flux-system get secret sops-age &> /dev/null; then
                # Present is not enough: it must hold THIS key, or Flux cannot decrypt what you encrypt.
                # Each step is checked on its own, so a read error is never mistaken for a mismatch.
                if ! encoded="$(k -n flux-system get secret sops-age -o jsonpath='{.data.age\.agekey}')"; then
                    echo "❌ could not read the sops-age secret in ${KUBE_CONTEXT}"
                    exit 1
                fi
                if [[ -z "${encoded}" ]]; then
                    echo "❌ the sops-age secret in ${KUBE_CONTEXT} has no age.agekey field"
                    exit 1
                fi
                if ! printf '%s' "${encoded}" | base64 -d > /dev/null 2>&1; then
                    echo "❌ the age.agekey field of sops-age in ${KUBE_CONTEXT} is not valid base64"
                    exit 1
                fi
                if printf '%s' "${encoded}" | base64 -d | cmp -s - "${AGE_KEY_FILE}"; then
                    echo "✅ sops-age secret in ${KUBE_CONTEXT} holds this key (created by Terraform)"
                else
                    echo "❌ sops-age secret in ${KUBE_CONTEXT} holds a DIFFERENT key than ${AGE_KEY_FILE}"
                    echo "   Flux could not decrypt what you encrypt now. Rebuild the cluster with this key"
                    echo "   (Chapter 00, Tear Down and Rebuild), or replace the secret: $0 --create-secret"
                    exit 1
                fi
            else
                create_k8s_secret
            fi
            update_local_sops_rule
            ;;
        -h|--help)
            usage
            ;;
        *)
            usage
            exit 1
            ;;
    esac
}

main "$@"
