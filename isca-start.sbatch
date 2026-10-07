#!/bin/bash -l

#SBATCH --account ddomeise_default
#SBATCH --mail-type NONE
#SBATCH --mail-user Regan.Mudhar@unil.ch

#SBATCH --output=logs/%x.job.%j

#SBATCH --partition cpu

#SBATCH --nodes 1
#SBATCH --ntasks 16
#SBATCH --cpus-per-task 1
#SBATCH --mem 8G
#SBATCH --time 00:29:59
#SBATCH --export ALL

#SBATCH --dependency singleton

# List available experiments
ISCA_PREFIX="isca_"

declare -a EXP=(
[0]="held-suarez"            # Held-Suarez
[1]="real-cont"              # Realistic Continents (qflux)
[2]="soc-aquaplanet"         # Socrates Aquaplanet
[3]="soc-simple-clouds"      # Socrates Simple Clouds
[4]="soc-topo-clouds"        # Socrates Aquaplanet Topo Clouds
[5]="cg-drag"                # cg-drag
[6]="soc-mg-drag"            # Socrates mg-drag
)

declare -a EXP_PATH=(
[0]="test_cases/held_suarez/held_suarez_test_case.py"
[1]="test_cases/realistic_continents/realistic_continents_variable_qflux_test_case.py"
[2]="test_cases/socrates_test/socrates_aquaplanet.py"
[3]="test_cases/simple_clouds/socrates_simcloud.py"
[4]="test_cases/socrates_test/socrates_aquaplanet_amip_with_topo_clouds.py"
[5]="test_cases/cg_drag/cg_drag_qbo_test_case.py"
[6]="test_cases/mg_drag/mg_drag_socrates_topo_test_case.py"
)

# Usage and help
usage() {
  echo "Usage: sbatch [-J EXPERIMENT | --job-name EXPERIMENT] $(basename -- "$BASH_SOURCE")"
  echo
  echo "Available experiments:"
  echo
  for ((i = 0; i < ${#EXP[@]}; i++)); do
    echo "${ISCA_PREFIX}${EXP[$i]}"
  done
  echo
  echo "Default experiment: ${ISCA_PREFIX}${EXP[0]}"
}

parse_args() {
  while test $# -gt 0; do local arg=$1; shift; case "$arg" in
    -h|--help) usage; exit 0 ;;
  esac; done
}

parse_args "$@"

# Load required modules
dcsrsoft use 20260114

module load openmpi/5.0.8
module load netcdf-c/4.9.3
module load netcdf-fortran/4.6.2

# Set environment
WORK=$(pwd)

export SLURM_EXPORT_ENV=ALL

export GFDL_BASE=${WORK}/Isca
export GFDL_SOC=${WORK}/socrates
export GFDL_ENV=curnagl-gfortran
export GFDL_WORK=${WORK}/isca_work
export GFDL_DATA=${WORK}/isca_data

export C_INCLUDE_PATH=${NETCDF_C_ROOT}/include
export LIBRARY_PATH=${NETCDF_C_ROOT}/lib

export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$NETCDF_FORTRAN_ROOT/lib
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$NETCDF_C_ROOT/lib

source ${WORK}/socrates/set_rad_env

# Clean files from previous runs
rm -rf ${GFDL_WORK}/experiment/*/run/{INPUT,RESTART,*.nc,*.out}
rm -rf ${GFDL_DATA}

for ((i = 0; i < ${#EXP[@]}; i++)); do
  if [[ x"${SLURM_JOB_NAME}" == x"${ISCA_PREFIX}${EXP[i]}" ]]; then
    sed -i "s/^NCORES =.*$/NCORES = $(echo ${SLURM_NTASKS:-1})/" "${GFDL_BASE}/exp/${EXP_PATH[$i]}"
    ${WORK}/isca_venv/bin/python $GFDL_BASE/exp/${EXP_PATH[$i]}
    exit $?
  fi
done

echo "Unrecognised experiment: ${SLURM_JOB_NAME}"
echo
usage

exit 1
