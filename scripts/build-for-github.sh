#!/usr/bin/env bash
set -e

echo "Building SST binaries for GitHub distribution..."

# Build all binaries using goreleaser (skip if already built)
if [ ! -d "dist" ]; then
  echo "Building Go binaries for all platforms..."
  goreleaser build --clean --snapshot
else
  echo "Using existing binaries in dist/"
fi

# Create the node_modules structure that npm expects
echo "Setting up platform-specific packages..."

# Create sdk/js/node_modules structure
mkdir -p sdk/js/node_modules

# Function to map goreleaser platform to npm platform
get_npm_platform() {
  case "$1" in
    "darwin_amd64") echo "darwin-x64" ;;
    "darwin_arm64") echo "darwin-arm64" ;;
    "linux_amd64") echo "linux-x64" ;;
    "linux_arm64") echo "linux-arm64" ;;
    "linux_386") echo "linux-x86" ;;
    "windows_amd64") echo "win32-x64" ;;
    "windows_arm64") echo "win32-arm64" ;;
    "windows_386") echo "win32-x86" ;;
    *) echo "" ;;
  esac
}

# Copy binaries to the correct locations
for goreleaser_dir in dist/sst_*; do
  if [ -d "$goreleaser_dir" ]; then
    # Extract platform info from directory name
    dir_name=$(basename "$goreleaser_dir")
    # Remove 'sst_' prefix and version suffix
    platform_arch=$(echo "$dir_name" | sed 's/^sst_//' | sed 's/_v[0-9].*//' | sed 's/_sse2//')

    # Get npm platform name
    npm_platform=$(get_npm_platform "$platform_arch")

    if [ -n "$npm_platform" ]; then
      package_name="sst-$npm_platform"
      target_dir="sdk/js/node_modules/$package_name"

      echo "Creating $package_name..."
      mkdir -p "$target_dir/bin"

      # Copy binary (handle .exe for Windows)
      if [[ "$platform_arch" == windows* ]]; then
        cp "$goreleaser_dir/sst.exe" "$target_dir/bin/sst.exe"
      else
        cp "$goreleaser_dir/sst" "$target_dir/bin/sst"
        chmod +x "$target_dir/bin/sst"
      fi

      # Create package.json for the platform package
      binary_name="sst"
      if [[ "$platform_arch" == windows* ]]; then
        binary_name="sst.exe"
      fi

      # Extract OS and CPU from npm_platform
      os_name="${npm_platform%%-*}"
      cpu_name="${npm_platform##*-}"

      cat > "$target_dir/package.json" <<EOF
{
  "name": "$package_name",
  "version": "0.0.0",
  "description": "Platform-specific SST binary for $npm_platform",
  "os": ["$os_name"],
  "cpu": ["$cpu_name"],
  "bin": {
    "sst": "./bin/$binary_name"
  }
}
EOF
    fi
  fi
done

# Build TypeScript SDK
echo "Building TypeScript SDK..."
cd sdk/js
bun install
bun run build
cd ../..

echo "Build complete! Binaries are ready in sdk/js/node_modules/"
echo ""
echo "To commit and push:"
echo "  git add -f sdk/js/node_modules/sst-*"
echo "  git commit -m 'Add platform binaries for GitHub distribution'"
echo "  git push origin $(git branch --show-current)"
echo ""
echo "Then in your app, use:"
echo '  "sst": "github:YOUR_USERNAME/sst#'$(git branch --show-current)'"'