#!/usr/bin/env bash
set -euo pipefail
command="${1:?shared check name required}"; shift
kit="${S3_KIT_ROOT:-$PWD/.kit}"
if [[ ! -f "$kit/go.mod" ]]; then
  mkdir -p "$HOME/.cache/sel-s3-go"
  docker run --rm -u "$(id -u):$(id -g)" -e HOME=/tmp -e GOCACHE=/cache/build -e GOMODCACHE=/cache/mod -v "$HOME/.cache/sel-s3-go:/cache" -v "$PWD:/src" -w /src golang:1.27.2 sh -c 'go mod download github.com/stufently/s3-mcp-ai-cli-kit && dir=$(go list -m -f "{{.Dir}}" github.com/stufently/s3-mcp-ai-cli-kit) && mkdir -p .kit && cp -R "$dir/." .kit/ && chmod -R u+w .kit'
fi
export S3_KIT_ROOT="$kit"
case "$command" in
 go|verify|conformance|mcp_smoke|mutation_gate|check_docs) exec bash "$kit/scripts/$command.sh" "$@";;
 *) printf 'unknown shared check: %s\n' "$command" >&2; exit 2;;
esac
