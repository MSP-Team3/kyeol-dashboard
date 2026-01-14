#!/bin/sh

# Replaces environment variables in the bundle's index.html file with their respective values.
# This script is automatically picked up by the nginx entrypoint on startup.

set -e

# Find all index.html files in /app and subdirectories to be safe
INDEX_BUNDLE_PATHS=$(find /app -name "index.html")

# Function to replace environment variables
replace_env_var() {
  var_name=$1
  var_value=$(eval echo \$"$var_name")
  if [ -n "$var_value" ]; then
    echo "Setting $var_name to: $var_value"
    for path in $INDEX_BUNDLE_PATHS; do
      echo "Applying to $path"
      sed -i "s#$var_name: \".*\"#$var_name: \"$var_value\"#" "$path"
    done
  else
    echo "No $var_name provided, using defaults."
  fi
}

# Replace each environment variable
replace_env_var "API_URL"
replace_env_var "API_URI"
replace_env_var "APP_MOUNT_URI"

# Fallback: Force replace the known incorrect origin-prod URL if API_URL is provided
if [ -n "$API_URL" ]; then
  echo "Force replacing any residue origin-prod URLs with $API_URL"
  for path in $INDEX_BUNDLE_PATHS; do
    echo "Applying force-replacement to $path"
    sed -i "s#https://origin-prod.kyeol.click/graphql/#$API_URL#g" "$path"
  done
fi

echo "Environment variable replacement complete."
