#!/bin/sh

# Script for IPFS Init Container - based on Kubo/bin/container_daemon
# Runs with root permissions
set -e

function init_function() {
  if [ -e "$IPFS_PATH/config" ]; then
    echo "Found IPFS fs-repo at $IPFS_PATH"
  else
    ipfs init ${IPFS_PROFILE:+"--profile=$IPFS_PROFILE"}
    ipfs config Addresses.API /ip4/0.0.0.0/tcp/5001
    ipfs config Addresses.Gateway /ip4/0.0.0.0/tcp/8080

    # Set up the swarm key, if provided

    SWARM_KEY_FILE="$IPFS_PATH/swarm.key"
    SWARM_KEY_PERM=0400

    # Create a swarm key from a given environment variable
    if [ -n "$IPFS_SWARM_KEY" ] ; then
      echo "Copying swarm key from variable..."
      printf "%s\n" "$IPFS_SWARM_KEY" >"$SWARM_KEY_FILE" || exit 1
      chmod $SWARM_KEY_PERM "$SWARM_KEY_FILE"
    fi

    # Unset the swarm key variable
    unset IPFS_SWARM_KEY

    # Check during initialization if a swarm key was provided and
    # copy it to the ipfs directory with the right permissions
    # WARNING: This will replace the swarm key if it exists
    if [ -n "$IPFS_SWARM_KEY_FILE" ] ; then
      echo "Copying swarm key from file..."
      install -m $SWARM_KEY_PERM "$IPFS_SWARM_KEY_FILE" "$SWARM_KEY_FILE" || exit 1
    fi

    # Unset the swarm key file variable
    unset IPFS_SWARM_KEY_FILE
  fi
}

if [ "$(id -u)" -eq 0 ]; then
  # Ensure ipfs folder has correct permissions
  setpriv --reuid 1000 --regid 100 --clear-groups test -w "$IPFS_PATH" || chown -R -- ipfs:users "$IPFS_PATH"
  # re-execute script as ipfs user
  setpriv --reuid 1000 --regid 100 --clear-groups $0
else
  init_function
fi


