#!/bin/bash
set -e

VERSION_FILE="/VERSION"

if [[ -f "$VERSION_FILE" ]]; then
  VERSION=$(<"$VERSION_FILE")
else
  VERSION="unknown"
fi

echo "SFCLI VERSION: $VERSION"

SFCLI_NOSSL="${SFCLI_NOSSL:-false}"
SFCLI_DL="${SFCLI_DL:-5242880}"
SFCLI_UL="${SFCLI_UL:-5242880}"

start_sync() {
  local library_vars
  library_vars=$(env | grep '^SFCLI_LIBS_' || true)

  if [ -z "$library_vars" ]; then
    echo "⚠️ No SFCLI_LIBS_* environment variables found. Nothing to sync."
    return
  fi

  while IFS='=' read -r var_name lib_id; do
    local lib_name="${var_name#SFCLI_LIBS_}"
    lib_name="${lib_name,,}"

    local lib_local_path="${SFCLI_LIB_DIR}/${lib_name}"

    echo "⏳ Processing library: name='${lib_name}', id='${lib_id}'"
    mkdir -p "${lib_local_path}"

    local sync_args=(
      seaf-cli sync
      -l "$lib_id"
      -d "$lib_local_path"
      -s "$SFCLI_URL"
      -u "$SFCLI_USERNAME"
      -p "$SFCLI_PASSWORD"
      -c "${SFCLI_CONFIG_DIR}"
    )

    if [ -n "$SFCLI_TOTP" ]; then
      echo "⏳ Generating TOTP token via oathtool..."

      local totp
      totp=$(oathtool --base32 --totp "$SFCLI_TOTP" 2>/dev/null)

      if [ -z "$totp" ]; then
        echo "⏳ Error: Failed to generate TOTP token. Check your SFCLI_TOTP secret."
        exit 1
      fi

      local prev_totp
      local attempts=0

      while true; do
        sleep 1
        totp=$(oathtool --base32 --totp "$SFCLI_TOTP" 2>/dev/null)

        if [ -z "$totp" ]; then
          echo "❌ Error: Failed to generate TOTP token. Check your SFCLI_TOTP secret."
          exit 1
        fi

        if [ "$totp" != "$prev_totp" ]; then
          prev_totp="$totp"
          break
        fi

        if ((attempts % 5 == 0)); then
          local remaining=$((30 - ($(date +%s) % 30)))
          echo "⏳ Waiting ~${remaining}s for new token..."
        fi

        attempts=$((attempts + 1))

        if [ "$attempts" -ge 30 ]; then
          echo "⚠️ Warning: TOTP token has not rotated after $attempts tries. Proceeding anyway with token: ${totp}"
          break
        fi
      done

      sync_args+=(-a "$totp")
    fi

    echo "⏳ Running sync command for '${lib_name}'..."
    if ! "${sync_args[@]}"; then
      echo "❌ Error: Failed to sync library '${lib_name}' (ID: '${lib_id}')."
      exit 1
    fi

  done <<<"$library_vars"
}

echo "⏳ Validating environment variables..."

if [ -z "$SFCLI_URL" ]; then
  echo "❌ Error: SFCLI_URL is required but not set."
  exit 1
fi

if [ -z "$SFCLI_USERNAME" ]; then
  echo "❌ Error: SFCLI_USERNAME is required but not set."
  exit 1
fi

if [ -z "$SFCLI_PASSWORD" ]; then
  echo "❌ Error: SFCLI_PASSWORD is required but not set."
  exit 1
fi

echo "⏳ Initializing Seafile CLI client..."
echo "   → Base directory      : ${SFCLI_BASE_DIR}"
echo "   → Config directory    : ${SFCLI_CONFIG_DIR}"
echo "   → Libraries directory : ${SFCLI_LIB_DIR}"
echo "   → Server URL          : ${SFCLI_URL}"
echo "   → SSL verification    : $([[ "$SFCLI_NOSSL" == "true" ]] && echo "disabled" || echo "enabled")"
echo "   → Download limit      : ${SFCLI_DL} bytes"
echo "   → Upload limit        : ${SFCLI_UL} bytes"

if ! seaf-cli init -c "${SFCLI_CONFIG_DIR}" -d "${SFCLI_BASE_DIR}"; then
  echo "❌ Failed to initialize Seafile client. Check permissions or existing state."
  exit 1
fi

if [ "$SFCLI_NOSSL" = "true" ]; then
  echo "⚠️  SFCLI_NOSSL=true: Disabling SSL certificate verification."
  if ! seaf-cli config -k disable_verify_certificate -v true -c "${SFCLI_CONFIG_DIR}"; then
    echo "❌ Failed to configure SSL verification option."
    exit 1
  fi
fi

echo "⏳ Starting Seafile daemon..."
if ! seaf-cli start -c "${SFCLI_CONFIG_DIR}"; then
  echo "❌ Failed to start Seafile daemon."
  exit 1
fi

echo "⏳ Waiting 5 seconds for the daemon to fully initialize..."
sleep 5

if [ "$SFCLI_DL" -gt 0 ]; then
  if ! seaf-cli config -k download_limit -v $SFCLI_DL -c "${SFCLI_CONFIG_DIR}"; then
    echo "❌ Failed to configure download speed limit."
    exit 1
  fi
fi

if [ "$SFCLI_UL" -gt 0 ]; then
  if ! seaf-cli config -k upload_limit -v $SFCLI_UL -c "${SFCLI_CONFIG_DIR}"; then
    echo "❌ Failed to configure upload speed limit."
    exit 1
  fi
fi

echo "⏳ Attempting to sync Seafile libraries..."
start_sync

echo "✅ All setup steps complete. Tailing seafile.log to keep container running..."
echo "✅ Log path: ${SFCLI_CONFIG_DIR}/logs/seafile.log"
tail -f "${SFCLI_CONFIG_DIR}/logs/seafile.log"
