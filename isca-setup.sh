#!/bin/bash -l
set -e

# Load required modules - latest available in our system as of 2026/09/01
dcsrsoft use 20260114

module load netcdf-c/4.9.3
module load netcdf-fortran/4.6.2
module load python/3.14.0

# Fetch Isca and merge with the
#   * Gravity Wave Drag schemes of PR 303 (https://github.com/ExeClim/Isca/pull/303)
#   * SST and ice physics improvements of PR 306 (https://github.com/ExeClim/Isca/pull/306)
git clone https://github.com/ExeClim/Isca 2> /dev/null &&
(
  cd Isca
  # Basic repo git config to be able to work with it
  git config user.name "Regan Mudhar"
  git config user.email "Regan.Mudhar@unil.ch"
  # Fetch and rebase PR 303
  git remote add -t gwd_merge_orographic_nonorographic -t uob_fftw_sit23_physics_2026 sit23 https://github.com/sit23/Isca
  git fetch sit23
  git checkout -B PR-303+306-merge d1321ac372698bcbe054da1cc5b4eef9f998a096   # Last commit in origin/master as of 2026/10/07
  git rebase 773a532e8e703913d1d18baaca05fd7255c2b990                         # Last commit in sit23/gwd_merge_orographic_nonorographic as of 2026/10/07
  git rebase 6c4c17d50af8b4278a8eb49bc56388378a08d61c                         # Last commit in sit23/uob_fftw_sit23_physics_2026 as of 2026/10/07
  # Apply patches and copy/update a couple of files
  git apply ../isca.patch
  cp ../curnagl-gfortran src/extra/env/curnagl-gfortran
  cp ../path_names src/extra/model/socrates/path_names
  # Commit and reset config
  git commit -m "Updated SOCRATES \`path_names\` file"
  git config remove-section user
) || echo "Warning: cannot clone into destination path 'Isca' (does it already exist?), skipping"

# Fetch and compile SOCRATES
git clone https://github.com/MetOffice/socrates 2> /dev/null &&
(
  cd socrates
  # Fetch SOCRATES, move to the targetted version and apply relevant patches
  git checkout um13.7
  git apply ../socrates.patch
  # Build and small fix
  export LIBRARY_PATH=$NETCDF_FORTRAN_ROOT/lib
  ./build_code
  sed -i '/LIBCDF_PATH/d' set_rad_env # We remove the lines exporting LIBCDF_PATH to the PATH, since we already take care of that in the SLURM script in a separate way
) || echo "Warning: cannot clone into destination path 'socrates' (does it already exist?), skipping"

# Setup the Isca python virtual environment
test ! -d isca_venv &&
(
  python -m venv isca_venv
  isca_venv/bin/pip install -e ./Isca/src/extra/python
  isca_venv/bin/pip install tqdm # Missing dependency in Isca requirements
) || echo "Warning: Isca python virtual environment seems to exist, skipping"
