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
      # Use '#' as separator instead of '/' to handle slashes in URLs
      sed -i -E "s#([\"']?${var_name}[\"']?[: ]*[\"'])([^\"']*)([\"'])#\1${var_value}\3#g" "$path"
    done
  else
    echo "Skipping $var_name (No value provided)"
  fi
}

# 1. Primary replacements (Unified to use API_URL as the main source)
# We support both if provided, but typically the app code reads API_URL
replace_env_var "API_URL"
replace_env_var "API_URI"
replace_env_var "APP_MOUNT_URI"

# 2. Domain Synchronization & Fixes
# Ensure any hardcoded 'origin-prod.kyeol.click' or relative '/graphql/' paths
# are updated to the target API host if API_URL is provided.
if [ -n "$API_URL" ]; then
  # Extract domain only (e.g., api.kyeol.click) for hostname replacement
  NEW_HOST=$(echo "$API_URL" | sed -E 's|https?://([^/]+).*|\1|')
  
  echo "Syncing domains: replacing 'origin-prod.kyeol.click' with '$NEW_HOST'"
  for path in $TARGET_FILES; do
    # Replace the host
    sed -i "s#origin-prod.kyeol.click#$NEW_HOST#g" "$path"
    
    # Replace relative /graphql/ with absolute API_URL to prevent 308 redirects
    sed -i "s#\"/graphql/\"#\"$API_URL\"#g" "$path"
    sed -i "s#'/graphql/'#'$API_URL'#g" "$path"
  done
fi

# 3. Cleanup: Delete pre-compressed files (.gz, .br)
# Forces Nginx to serve the modified uncompressed files.
echo "Cleaning up compressed files..."
find /app -type f \( -name "*.gz" -o -name "*.br" \) -delete

echo "--- Runtime Injection Complete ---"
