#!/usr/bin/env bash
# Build the six Desktop Extension bundles (.mcpb) for one S3 provider.
# Run from the provider repository. VERSION is required (the release tag
# without the leading v). Go and the mcpb CLI run in Docker. The Go build
# cache is $HOME/.cache/sel-s3-go. Nothing is installed on the host.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

if [ -z "${VERSION:-}" ]; then
  echo "VERSION is required" >&2
  exit 1
fi
if ! printf '%s\n' "$VERSION" | grep -Eq '^[0-9A-Za-z][0-9A-Za-z._+-]*$'; then
  echo "VERSION=${VERSION} is not a safe version token" >&2
  exit 1
fi

profile=internal/provider/profile.yaml
if [ ! -f "$profile" ] || [ ! -f mcpb/manifest.json ] || [ ! -f testdata/tools/all.golden ]; then
  echo "build-mcpb: provider root is missing profile.yaml, mcpb/manifest.json or testdata/tools/all.golden" >&2
  exit 1
fi

binary=$(sed -n 's/^binary: //p' "$profile")
prefix=$(sed -n 's/^env_prefix: //p' "$profile")
if ! printf '%s\n' "$binary" | grep -Eq '^[A-Za-z0-9_-]+$'; then
  echo "build-mcpb: binary is not a safe token" >&2
  exit 1
fi
if ! printf '%s\n' "$prefix" | grep -Eq '^[A-Za-z0-9_]+$'; then
  echo "build-mcpb: env_prefix is not a safe token" >&2
  exit 1
fi

python3 - mcpb/manifest.json <<'PY'
import json
import sys

path = sys.argv[1]
with open(path, encoding="utf-8") as handle:
    doc = json.load(handle)
user_config = doc.get("user_config")
if not isinstance(user_config, dict):
    print("user_config", file=sys.stderr)
    sys.exit(1)
missing = []
for name, opt in user_config.items():
    if not isinstance(opt, dict) or (opt.get("required") is not True and "default" not in opt):
        missing.append(name)
if missing:
    for name in missing:
        print(name, file=sys.stderr)
    sys.exit(1)
PY

commit=${COMMIT:-mcpb}
out=$PWD/dist-mcpb
cache="${HOME}/.cache/sel-s3-go"
npm_cache="${HOME}/.cache/sel-s3-mcpb-npm"
go_image=golang:1.27.2
node_image=node:24.21.0-slim
uid_gid="$(id -u):$(id -g)"
mkdir -p "$cache" "$npm_cache"
rm -rf "$out"
mkdir -p "$out"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

cat > "$work/build.sh" <<'EOF'
#!/bin/bash
set -euo pipefail
ldflags="-s -w -X main.version=${VERSION} -X main.commit=${COMMIT}"
for pair in linux-amd64 linux-arm64 darwin-amd64 darwin-arm64 windows-amd64 windows-arm64; do
  goos=${pair%-*}
  goarch=${pair##*-}
  name=$BINARY
  if [ "$goos" = windows ]; then
    name="${BINARY}.exe"
  fi
  mkdir -p "/out/${pair}/server"
  GOOS="$goos" GOARCH="$goarch" go build -trimpath -ldflags "$ldflags" \
    -o "/out/${pair}/server/${name}" "./cmd/${BINARY}"
done
EOF
chmod 755 "$work/build.sh"

docker run --rm -u "$uid_gid" \
  -e HOME=/tmp \
  -e GOCACHE=/cache/build \
  -e GOMODCACHE=/cache/mod \
  -e GOFLAGS=-buildvcs=false \
  -e CGO_ENABLED=0 \
  -e "BINARY=${binary}" \
  -e "VERSION=${VERSION}" \
  -e "COMMIT=${commit}" \
  -v "$PWD:/src:ro" \
  -v "$cache:/cache" \
  -v "$work:/out" \
  -w /src \
  "$go_image" \
  bash /out/build.sh

chmod 755 "$work/linux-amd64/server/${binary}"

UID_GID="$uid_gid" WORK="$work" GO_IMAGE="$go_image" BINARY="$binary" PREFIX="$prefix" \
  python3 - "$PWD/testdata/tools/all.golden" "$work/tools.json" <<'PY'
import json
import os
import select
import subprocess
import sys
import time

golden_path, out_path = sys.argv[1:]
binary = os.environ["BINARY"]
prefix = os.environ["PREFIX"]
cmd = [
    "docker", "run", "--rm", "-i", "--network", "none",
    "-u", os.environ["UID_GID"],
    "-e", "HOME=/tmp",
    "-e", prefix + "ACCESS_KEY_ID=fake-access-key",
    "-e", prefix + "SECRET_ACCESS_KEY=fake-secret-key",
    "-e", prefix + "ENDPOINT=http://127.0.0.1:1",
    "-e", prefix + "ALLOW_INSECURE=1",
    "-e", prefix + "ALLOW=write,delete,admin",
    "-v", os.environ["WORK"] + ":/out:ro",
    os.environ["GO_IMAGE"],
    "/out/linux-amd64/server/" + binary, "mcp",
]
proc = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
buf = b""

def send(obj):
    proc.stdin.write((json.dumps(obj) + "\n").encode())
    proc.stdin.flush()

def request(method, params, timeout):
    global buf
    rid = {"initialize": 1, "tools/list": 2}[method]
    send({"jsonrpc": "2.0", "id": rid, "method": method, "params": params})
    deadline = time.time() + timeout
    while time.time() < deadline:
        while b"\n" in buf:
            line, buf = buf.split(b"\n", 1)
            line = line.strip()
            if not line:
                continue
            try:
                msg = json.loads(line)
            except ValueError:
                continue
            if isinstance(msg, dict) and msg.get("id") == rid and "method" not in msg:
                if "error" in msg:
                    raise SystemExit("%s -> %s" % (method, msg["error"]))
                return msg.get("result", {})
        ready, _, _ = select.select([proc.stdout], [], [], 1.0)
        if ready:
            chunk = os.read(proc.stdout.fileno(), 65536)
            if not chunk:
                err = proc.stderr.read().decode("utf-8", "replace")[-2000:]
                raise SystemExit("server closed stdout during %s; stderr: %s" % (method, err))
            buf += chunk
    # Kill first: a live server that never writes to stderr would block the read.
    proc.kill()
    proc.wait()
    err = proc.stderr.read()[-2000:]
    raise SystemExit("timeout waiting for %s; stderr: %s" % (method, err.decode("utf-8", "replace")))

try:
    request("initialize", {
        "protocolVersion": "2025-06-18",
        "capabilities": {},
        "clientInfo": {"name": "build-mcpb", "version": "1"},
    }, 90)
    send({"jsonrpc": "2.0", "method": "notifications/initialized"})
    tools = []
    cursor = None
    for _ in range(100):
        params = {"cursor": cursor} if cursor else {}
        result = request("tools/list", params, 60)
        tools.extend(result.get("tools", []))
        cursor = result.get("nextCursor")
        if not cursor:
            break
finally:
    try:
        proc.stdin.close()
    except OSError:
        pass
    try:
        proc.wait(timeout=15)
    except subprocess.TimeoutExpired:
        proc.kill()
        proc.wait()

with open(golden_path, encoding="utf-8") as handle:
    golden = sorted(line.strip() for line in handle if line.strip())
names = sorted(tool.get("name") for tool in tools)
if names != golden:
    raise SystemExit("tools/list does not match all.golden:\n got %s\n want %s" % (names, golden))
for tool in tools:
    if not isinstance(tool.get("description"), str) or tool["description"] == "":
        raise SystemExit("tool %s has no description" % tool.get("name"))
with open(out_path, "w", encoding="utf-8") as handle:
    json.dump(tools, handle)
print("listed %d tools" % len(tools))
PY

VERSION="$VERSION" BINARY="$binary" WORK="$work" \
  python3 - "$PWD/mcpb/manifest.json" "$work/tools.json" "$work" <<'PY'
import json
import os
import sys

manifest_path, tools_path, work = sys.argv[1:]
version = os.environ["VERSION"]
binary = os.environ["BINARY"]
with open(manifest_path, encoding="utf-8") as handle:
    base = json.load(handle)
with open(tools_path, encoding="utf-8") as handle:
    live = json.load(handle)
base.pop("version", None)
base["version"] = version
base["tools"] = [{"name": tool["name"], "description": tool["description"]} for tool in live]
platforms = {"linux": "linux", "darwin": "darwin", "windows": "win32"}
written = 0
for name in sorted(os.listdir(work)):
    stage = os.path.join(work, name)
    if not os.path.isdir(stage) or name.count("-") != 1:
        continue
    goos = name.split("-", 1)[0]
    if goos not in platforms:
        continue
    entry = "server/%s.exe" % binary if goos == "windows" else "server/%s" % binary
    doc = json.loads(json.dumps(base))
    doc["compatibility"] = {"platforms": [platforms[goos]]}
    doc["server"]["entry_point"] = entry
    doc["server"]["mcp_config"]["command"] = "${__dirname}/" + entry
    path = os.path.join(stage, "manifest.json")
    with open(path, "w", encoding="utf-8") as handle:
        json.dump(doc, handle, indent=2)
        handle.write("\n")
    written += 1
    print("manifest %s -> %s" % (name, entry))
if written != 6:
    raise SystemExit("expected 6 platform manifests, wrote %d" % written)
PY

cat > "$work/pack.sh" <<'EOF'
#!/bin/bash
set -euo pipefail
for pair in linux-amd64 linux-arm64 darwin-amd64 darwin-arm64 windows-amd64 windows-arm64; do
  os=${pair%-*}
  arch=${pair##*-}
  npx -y @anthropic-ai/mcpb@2.1.2 pack "/out/${pair}" "/dist/${BINARY}_${VERSION}_${os}_${arch}.mcpb"
done
EOF
chmod 755 "$work/pack.sh"

docker run --rm -u "$uid_gid" \
  -e HOME=/tmp \
  -e npm_config_cache=/npm \
  -e "BINARY=${binary}" \
  -e "VERSION=${VERSION}" \
  -v "$npm_cache:/npm" \
  -v "$work:/out" \
  -v "$out:/dist" \
  "$node_image" \
  bash /out/pack.sh

found=$(find "$out" -maxdepth 1 -name '*.mcpb' | wc -l)
found=$(printf '%s' "$found" | tr -d ' ')
if [ "$found" -ne 6 ]; then
  echo "expected 6 bundles, found ${found}" >&2
  ls -la "$out" >&2
  exit 1
fi
echo "built ${found} bundles in dist-mcpb/ for ${VERSION}"
