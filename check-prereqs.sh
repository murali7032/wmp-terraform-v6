#!/usr/bin/env bash
set -euo pipefail

ok() {
  printf '[OK] %s\n' "$1"
}

warn() {
  printf '[WARN] %s\n' "$1"
}

err() {
  printf '[ERROR] %s\n' "$1" >&2
}

failed=0

echo "Checking Terraform + AWS prerequisites..."

# 1) Terraform must be in PATH.
if command -v terraform >/dev/null 2>&1; then
  tf_version="$(terraform version | sed -n '1p')"
  ok "Terraform found in PATH: ${tf_version}"
else
  err "Terraform is not in PATH. Install Terraform and re-run."
  failed=1
fi

# 2) AWS credentials must be configured (profile or env vars).
aws_method=""
if [[ -n "${AWS_PROFILE:-}" ]]; then
  aws_method="AWS_PROFILE=${AWS_PROFILE}"
elif [[ -n "${AWS_ACCESS_KEY_ID:-}" && -n "${AWS_SECRET_ACCESS_KEY:-}" ]]; then
  aws_method="AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY environment variables"
elif [[ -f "${HOME}/.aws/credentials" || -f "${HOME}/.aws/config" ]]; then
  aws_method="shared AWS config files under ~/.aws/"
fi

if [[ -z "${aws_method}" ]]; then
  err "AWS credentials not detected (no profile, env vars, or ~/.aws files)."
  failed=1
else
  ok "AWS credential source detected: ${aws_method}"
fi

# Optional validation with AWS CLI (recommended).
if command -v aws >/dev/null 2>&1; then
  if aws sts get-caller-identity >/dev/null 2>&1; then
    ok "AWS credentials are valid (sts get-caller-identity succeeded)."
  else
    err "AWS CLI is installed, but credentials failed validation (sts call failed)."
    failed=1
  fi
else
  warn "AWS CLI not found. Skipping live credential validation."
fi

if [[ "${failed}" -ne 0 ]]; then
  echo
  err "Prerequisite check failed."
  exit 1
fi

echo
ok "All prerequisite checks passed."
