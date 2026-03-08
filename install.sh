#!/usr/bin/env bash

set -e

REPO="https://github.com/yourname/bashket.git"
TMP_DIR="$(mktemp -d)"

echo "Installing Bashket..."

if ! command -v swift >/dev/null 2>&1; then
echo "Swift is required to build Bashket."
echo "Install it from https://swift.org/download/"
exit 1
fi

if ! command -v git >/dev/null 2>&1; then
echo "Git is required to install Bashket."
exit 1
fi

echo "Downloading source..."
git clone --depth 1 "$REPO" "$TMP_DIR/bashket"

cd "$TMP_DIR/bashket"

echo "Building..."
swift build -c release

echo "Installing..."

if [ -w /usr/local/bin ]; then
install -m 755 .build/release/bashket /usr/local/bin/bashket
else
sudo install -m 755 .build/release/bashket /usr/local/bin/bashket
fi

cd /
rm -rf "$TMP_DIR"

echo "Bashket installed successfully!"
echo
echo "Run:"
echo "  bashket help"
