#!/bin/sh
set -e

# This script replaces environment variables in the built app files at runtime.
# It is placed in /docker-entrypoint.d/ so it runs automatically when the container starts.

# Find all HTML and JS files in the app directory
TARGET_FILES=$(find /app -type f \( -name "*.html" -o -name "*.js" \))

echo "--- Starting Runtime Environment Variable Injection ---"

# Function to replace a specific variable
# Handles formats like: API_URL: "...", "API_URL": "...", API_URL: '...' etc.
replace_env_var() {
  var_name=$1
  var_value=$(eval echo \$"$var_name")
  
  if [ -n "$var_value" ]; then
    echo "Injecting $var_name -> $var_value"
    for path in $TARGET_FILES; do
      # Use a robust regex to find and replace the value regardless of surrounding quotes or spacing
      sed -i -E "s/([\"']?${var_name}[\"']?[: ]*[\"'])([^\"']*)([\"'])/\1${var_value}\3/g" "$path"
    done
  else
    echo "Skipping $var_name (No value provided)"
  fi
}

# 1. Primary replacements based on environment variable names
replace_env_var "API_URL"
replace_env_var "API_URI"
replace_env_var "APP_MOUNT_URI"

# 2. Nuclear Option: Force domain synchronization
# If API_URL is provided, we ensure any leftover references to 'origin-prod.kyeol.click'
# or relative '/graphql/' paths are updated to the target API host.
if [ -n "$API_URL" ]; then
  # Extract domain only (e.g., api.kyeol.click)
  NEW_HOST=$(echo "$API_URL" | sed -E 's|https?://([^/]+).*|\1|')
  
  echo "Force syncing domains: replacing 'origin-prod.kyeol.click' with '$NEW_HOST'"
  for path in $TARGET_FILES; do
    # Replace the hostname
    sed -i "s#origin-prod.kyeol.click#$NEW_HOST#g" "$path"
    
    # Also replace relative /graphql/ if it exists (prevents 308 redirects)
    # This ensures the browser calls the absolute URL directly.
    sed -i "s#\"/graphql/\"#\"$API_URL\"#g" "$path"
    sed -i "s#'/graphql/'#'$API_URL'#g" "$path"
  done
fi

# 3. Cleanup: Delete pre-compressed files (.gz, .br)
# This forces Nginx to serve the modified uncompressed files, or re-compress them on the fly if enabled.
echo "Deleting pre-compressed files to force live replacement..."
find /app -type f \( -name "*.gz" -o -name "*.br" \) -delete

echo "--- Runtime Injection Complete ---"
