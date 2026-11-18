#!/usr/bin/env bash
set -euo pipefail

# Deterministic, licensed font download for local iOS exports and CI.
# The source commit and Git blob hash must be updated together.
COMMIT="f8d157532fbfaeda587e826d4cd5b21a49186f7c"
EXPECTED_GIT_BLOB="dc15562470b4f842321894787a0d066879ccff8b"
FONT_PATH="assets/fonts/NotoSansCJKsc-Regular.otf"
FONT_URL="https://raw.githubusercontent.com/notofonts/noto-cjk/${COMMIT}/Sans/OTF/SimplifiedChinese/NotoSansCJKsc-Regular.otf"

mkdir -p "$(dirname "${FONT_PATH}")"
if [[ ! -f "${FONT_PATH}" ]]; then
  tmp="${FONT_PATH}.download"
  trap 'rm -f "${tmp}"' EXIT
  curl --fail --location --retry 3 --silent --show-error \
    "${FONT_URL}" --output "${tmp}"
  mv "${tmp}" "${FONT_PATH}"
fi

actual="$(git hash-object "${FONT_PATH}")"
if [[ "${actual}" != "${EXPECTED_GIT_BLOB}" ]]; then
  echo "::error::Bundled CJK font hash mismatch: ${actual}"
  rm -f "${FONT_PATH}"
  exit 1
fi

python3 - <<'PY'
from pathlib import Path
font = Path("assets/fonts/NotoSansCJKsc-Regular.otf")
data = font.read_bytes()
if len(data) < 10_000_000 or data[:4] != b"OTTO":
    raise SystemExit("Invalid Noto Sans CJK OTF payload")
print(f"[PHOSPRITE-FONT] Verified Noto Sans CJK SC: {len(data)} bytes")
PY

test -f assets/fonts/NotoSansCJKsc-License.txt
