#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

deps=(terraform terragrunt terraform-docs shellcheck)
missing=()
for dep in "${deps[@]}"; do
  command -v "${dep}" &>/dev/null || missing+=("${dep}")
done
if [[ ${#missing[@]} -gt 0 ]]; then
  echo "error: missing required tools: ${missing[*]}" >&2
  exit 1
fi

mapfile -t STACK_DIRS < <(find "${SCRIPT_DIR}" -name "root.hcl" -not -path "*/.terragrunt-cache/*" -exec dirname {} \; | sort)

mapfile -t MODULES_DIRS < <(
  for stack_dir in "${STACK_DIRS[@]}"; do
    modules_dir="$(dirname "${stack_dir}")/modules"
    [[ -d "${modules_dir}" ]] && echo "${modules_dir}"
  done
)

echo "==> terraform fmt: modules"
for modules_dir in "${MODULES_DIRS[@]}"; do
  terraform fmt -recursive "${modules_dir}"
done

echo "==> terraform fmt: stack"
for stack_dir in "${STACK_DIRS[@]}"; do
  while IFS= read -r dir; do
    terraform fmt "${dir}"
  done < <(find "${stack_dir}" -name "*.tf" -not -path "*/.terragrunt-cache/*" -exec dirname {} \; | sort -u)
done

echo "==> terragrunt hcl fmt: stack"
for stack_dir in "${STACK_DIRS[@]}"; do
  (cd "${stack_dir}" && terragrunt hcl fmt)
done

echo "==> terraform-docs: modules"
for modules_dir in "${MODULES_DIRS[@]}"; do
  while IFS= read -r dir; do
    echo "    ${dir#"${modules_dir}/"}"
    terraform-docs markdown table --output-file README.md "${dir}"
  done < <(find "${modules_dir}" -name "versions.tf" -exec dirname {} \; | sort)
done

echo "==> shellcheck: scripts"
while IFS= read -r script; do
  shellcheck "${script}"
done < <(find "${SCRIPT_DIR}" -name "*.sh" -not -path "*/.terragrunt-cache/*" | sort)
