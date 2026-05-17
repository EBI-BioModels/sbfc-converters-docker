#!/bin/bash
# Copies large binary dependencies from sibling directories into this
# directory so it can be built standalone. Run once after cloning the
# parent monorepo, or before pushing sbfcOnline.war and JARs to EC2.
#
# On EC2, if the parent monorepo is not available, copy the files manually:
#   sbfcOnline.war        -> sbfc-converters-aws-ec2/sbfcOnline.war
#   sbfc-converters/sbfc/lib/  -> sbfc-converters-aws-ec2/sbfc/lib/
#   sbfc-converters/sbfc/miriam.xml -> sbfc-converters-aws-ec2/sbfc/miriam.xml

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

copy_file() {
    local src="$1" dst="$2"
    if [ -f "$src" ]; then
        cp "$src" "$dst"
        echo "  copied: $(basename "$src")"
    else
        echo "  WARNING: not found — $src"
    fi
}

copy_dir() {
    local src="$1" dst="$2"
    if [ -d "$src" ]; then
        mkdir -p "$dst"
        cp -r "$src/." "$dst/"
        echo "  copied: $(basename "$src")/ ($(du -sh "$dst" | cut -f1))"
    else
        echo "  WARNING: not found — $src"
    fi
}

echo "Fetching dependencies from sibling directories..."

copy_file "$ROOT/sbfc-webapp-k8s/sbfcOnline.war"         "$SCRIPT_DIR/sbfcOnline.war"
mkdir -p "$SCRIPT_DIR/sbfc"
copy_dir  "$ROOT/sbfc-converters/sbfc/lib"                "$SCRIPT_DIR/sbfc/lib"
copy_file "$ROOT/sbfc-converters/sbfc/miriam.xml"         "$SCRIPT_DIR/sbfc/miriam.xml"

echo ""
echo "Done. You can now run: docker compose up --build"
