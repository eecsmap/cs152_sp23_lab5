#!/usr/bin/env bash

# exit script if any command fails
set -e
set -o pipefail

# Check that git version is at least 1.7.8
MYGIT=$(git --version)
MYGIT=${MYGIT#'git version '} # Strip prefix
case ${MYGIT} in
[1-9]*) ;;
*) echo 'warning: unknown git version' ;;
esac
MINGIT="1.7.8"
if [ "$MINGIT" != "$(echo -e "$MINGIT\n$MYGIT" | sort -V | head -n1)" ]; then
  echo "This script requires git version $MINGIT or greater. Exiting."
  false
fi

RDIR=$(git rev-parse --show-toplevel)

# Ignore toolchain submodules
cd "$RDIR"
for name in toolchains/*-tools/*/ ; do
    git config submodule."${name%/}".update none
done
git config submodule.toolchains/libgloss.update none
git config submodule.toolchains/qemu.update none

# Don't automatically initialize generators with big submodules (e.g. linux source)
git config submodule.generators/sha3.update none
# git config submodule.generators/ariane.update none

# Disable updates to the FireSim submodule until explicitly requested
git config submodule.sims/firesim.update none
# Disable updates to the hammer tool plugins repos
git config submodule.vlsi/hammer-cadence-plugins.update none
git config submodule.vlsi/hammer-synopsys-plugins.update none
git config submodule.vlsi/hammer-mentor-plugins.update none
git config submodule.software/firemarshal.update none
git submodule update --init --recursive #--jobs 8

# Un-ignore toolchain submodules
for name in toolchains/*-tools/*/ ; do
    git config --unset submodule."${name%/}".update
done
git config --unset submodule.toolchains/libgloss.update
git config --unset submodule.toolchains/qemu.update

git config --unset submodule.vlsi/hammer-cadence-plugins.update
git config --unset submodule.vlsi/hammer-synopsys-plugins.update
git config --unset submodule.vlsi/hammer-mentor-plugins.update

git config --unset submodule.generators/sha3.update
# git config --unset submodule.generators/ariane.update
git config --unset submodule.software/firemarshal.update

# Non-recursive clone to exclude riscv-linux
git submodule update --init generators/sha3
# git submodule update --init generators/ariane

git config --unset submodule.sims/firesim.update
# Minimal non-recursive clone to initialize sbt dependencies
git submodule update --init sims/firesim
(
    cd sims/firesim
    # Initialize dependencies for MIDAS-level RTL simulation
    git submodule update --init sim/midas
)
git config submodule.sims/firesim.update none

# Only shallow clone needed for basic SW tests
git submodule update --init software/firemarshal

# Configure firemarshal to know where our firesim installation is
if [ ! -f $RDIR/software/firemarshal/marshal-config.yaml ]; then
  echo "firesim-dir: '../../sims/firesim/'" > $RDIR/software/firemarshal/marshal-config.yaml
fi
echo "PATH=\$( realpath \$(dirname "\${BASH_SOURCE[0]:-\${\(%\):-%x}}") )/software/firemarshal:\$PATH" >> $RDIR/env.sh
