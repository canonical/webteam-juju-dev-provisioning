#!/bin/bash
set -e

REPO="${REPO:-pedoch/local-juju-env-provisioning}"
BACKEND="${BACKEND:-}"
VERSION="${VERSION:-main}"
BASE="https://raw.githubusercontent.com/$REPO/$VERSION"

if [ -z "$BACKEND" ] || [[ "$BACKEND" != "vm" && "$BACKEND" != "lxd" ]]; then
  echo "Usage: BACKEND=<vm|lxd> [VERSION=<vX.Y.Z|main>] [REPO=org/repo] bash $0"
  echo ""
  echo "Examples:"
  echo "  BACKEND=lxd bash $0"
  echo "  BACKEND=vm VERSION=v1.2.0 bash $0"
  exit 1
fi

SHARED="setup-juju-env.sh utils.sh juju_local.yaml.example"

if [ "$BACKEND" = "vm" ]; then
  FILES="cloud-init-juju.yaml launch_instance.sh $SHARED"
else
  FILES="cloud-init-juju-lxd.yaml launch_instance_lxd.sh $SHARED"
fi

echo "Fetching $BACKEND files ($VERSION) ..."
for f in $FILES; do
  curl -fsSL "$BASE/$f" -o "$f"
  echo "  $f"
done

chmod +x ./*.sh

echo ""
echo "Done. Edit juju_local.yaml.example and save as juju_local.yaml, then run:"
if [ "$BACKEND" = "vm" ]; then
  echo "  ./launch_instance.sh [NAME]"
else
  echo "  ./launch_instance_lxd.sh [NAME]"
fi
