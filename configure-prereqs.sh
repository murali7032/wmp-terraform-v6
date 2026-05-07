#!/usr/bin/env bash
set -euo pipefail

# Configure prerequisites for this Terraform project:
# - Terraform (installs if missing)
# - AWS CLI (installs if missing)
# - AWS profile/config (optional, via flags or env vars)
#
# Usage examples:
#   ./configure-prereqs.sh
#   ./configure-prereqs.sh --region us-east-1
#   ./configure-prereqs.sh --profile devops --region us-east-1 \
#     --aws-access-key-id AKIA... --aws-secret-access-key ... --aws-session-token ...
#
# Environment variable alternatives:
#   AWS_PROFILE, AWS_REGION, AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_SESSION_TOKEN

PROFILE="${AWS_PROFILE:-default}"
REGION="${AWS_REGION:-ap-south-2}"
ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-}"
SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-}"
SESSION_TOKEN="${AWS_SESSION_TOKEN:-}"

print_usage() {
  cat <<'EOF'
Usage: configure-prereqs.sh [options]

Options:
  --profile <name>                AWS profile name (default: default or AWS_PROFILE)
  --region <region>               AWS region (default: us-east-1 or AWS_REGION)
  --aws-access-key-id <key>       AWS access key id
  --aws-secret-access-key <key>   AWS secret access key
  --aws-session-token <token>     AWS session token (optional)
  -h, --help                      Show help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile)
      PROFILE="$2"
      shift 2
      ;;
    --region)
      REGION="$2"
      shift 2
      ;;
    --aws-access-key-id)
      ACCESS_KEY_ID="$2"
      shift 2
      ;;
    --aws-secret-access-key)
      SECRET_ACCESS_KEY="$2"
      shift 2
      ;;
    --aws-session-token)
      SESSION_TOKEN="$2"
      shift 2
      ;;
    -h|--help)
      print_usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      print_usage
      exit 1
      ;;
  esac
done

ok() { printf '[OK] %s\n' "$1"; }
warn() { printf '[WARN] %s\n' "$1"; }
err() { printf '[ERROR] %s\n' "$1" >&2; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1
}

install_terraform() {
  if need_cmd terraform; then
    ok "Terraform already installed: $(terraform version | sed -n '1p')"
    return
  fi

  warn "Terraform not found. Installing..."

  if need_cmd dnf; then
    sudo dnf install -y dnf-plugins-core
    sudo dnf config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
    sudo dnf install -y terraform
  elif need_cmd apt-get; then
    sudo apt-get update -y
    sudo apt-get install -y wget gpg lsb-release
    wget -O- https://apt.releases.hashicorp.com/gpg | \
      gpg --dearmor | \
      sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg >/dev/null
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
      sudo tee /etc/apt/sources.list.d/hashicorp.list
    sudo apt-get update -y
    sudo apt-get install -y terraform
  else
    err "Unsupported package manager. Install Terraform manually and re-run."
    exit 1
  fi

  ok "Terraform installed: $(terraform version | sed -n '1p')"
}

install_aws_cli() {
  if need_cmd aws; then
    ok "AWS CLI already installed: $(aws --version 2>&1)"
    return
  fi

  warn "AWS CLI not found. Installing..."

  if need_cmd dnf; then
    sudo dnf install -y unzip curl
  elif need_cmd apt-get; then
    sudo apt-get update -y
    sudo apt-get install -y unzip curl
  else
    err "Unsupported package manager. Install AWS CLI manually and re-run."
    exit 1
  fi

  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' EXIT
  curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "${tmpdir}/awscliv2.zip"
  unzip -q "${tmpdir}/awscliv2.zip" -d "${tmpdir}"
  sudo "${tmpdir}/aws/install" --update

  ok "AWS CLI installed: $(aws --version 2>&1)"
}

configure_aws_profile() {
  mkdir -p "${HOME}/.aws"

  if [[ -n "${ACCESS_KEY_ID}" && -n "${SECRET_ACCESS_KEY}" ]]; then
    aws configure set aws_access_key_id "${ACCESS_KEY_ID}" --profile "${PROFILE}"
    aws configure set aws_secret_access_key "${SECRET_ACCESS_KEY}" --profile "${PROFILE}"
    if [[ -n "${SESSION_TOKEN}" ]]; then
      aws configure set aws_session_token "${SESSION_TOKEN}" --profile "${PROFILE}"
    fi
    aws configure set region "${REGION}" --profile "${PROFILE}"
    aws configure set output "json" --profile "${PROFILE}"
    ok "Configured AWS profile '${PROFILE}' from provided credentials."
  else
    warn "No AWS keys provided. Skipping credential write."
    warn "Set AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY or use --aws-access-key-id/--aws-secret-access-key."
    warn "Or run: aws configure --profile ${PROFILE}"
    # Ensure at least region is configured if profile already exists.
    aws configure set region "${REGION}" --profile "${PROFILE}" || true
  fi
}

validate_setup() {
  if need_cmd terraform; then
    ok "Terraform ready."
  else
    err "Terraform still not available in PATH."
    exit 1
  fi

  if ! need_cmd aws; then
    err "AWS CLI still not available in PATH."
    exit 1
  fi

  if AWS_PROFILE="${PROFILE}" aws sts get-caller-identity >/dev/null 2>&1; then
    ok "AWS credentials validated for profile '${PROFILE}'."
  else
    warn "AWS STS validation failed for profile '${PROFILE}'."
    warn "If this is expected, configure credentials and re-run:"
    warn "  aws configure --profile ${PROFILE}"
    return 1
  fi
}

echo "Configuring Terraform project prerequisites..."
install_terraform
install_aws_cli
configure_aws_profile
validate_setup || true

echo
ok "Prerequisite configuration completed."
echo "Using AWS profile: ${PROFILE}"
echo "Using AWS region : ${REGION}"
