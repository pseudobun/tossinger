#!/usr/bin/env bash
set -euo pipefail

PBXPROJ="toss.xcodeproj/project.pbxproj"
MARKETING_VERSION=""
BUILD_NUMBER=""

usage() {
  cat <<'EOF'
Usage:
  ./scripts/update_xcode_versions.sh [--marketing <x.y.z>] [--build <number>]

Examples:
  ./scripts/update_xcode_versions.sh --marketing 1.2.0
  ./scripts/update_xcode_versions.sh --build 2301
  ./scripts/update_xcode_versions.sh --marketing 1.2.0 --build 2301
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --marketing)
      MARKETING_VERSION="${2:-}"
      shift 2
      ;;
    --build)
      BUILD_NUMBER="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "$MARKETING_VERSION" && -z "$BUILD_NUMBER" ]]; then
  echo "You must provide --marketing and/or --build." >&2
  usage >&2
  exit 1
fi

if [[ ! -f "$PBXPROJ" ]]; then
  echo "Could not find $PBXPROJ" >&2
  exit 1
fi

if [[ -n "$MARKETING_VERSION" ]]; then
  perl -0pi -e "s/MARKETING_VERSION = [^;]+;/MARKETING_VERSION = ${MARKETING_VERSION};/g" "$PBXPROJ"
fi

if [[ -n "$BUILD_NUMBER" ]]; then
  perl -0pi -e "s/CURRENT_PROJECT_VERSION = [^;]+;/CURRENT_PROJECT_VERSION = ${BUILD_NUMBER};/g" "$PBXPROJ"
fi

echo "Updated versions in ${PBXPROJ}:"
grep -nE "MARKETING_VERSION =|CURRENT_PROJECT_VERSION =" "$PBXPROJ"
