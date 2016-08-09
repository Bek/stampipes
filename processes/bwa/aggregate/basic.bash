
source $MODULELOAD
module load bedops/2.4.19
module load jdk/1.8.0_92
module load gcc/4.7.2
module load R/3.2.5
module load picard/1.120
module load samtools/1.3
module load git/2.3.3
module load coreutils/8.25

WIN=75
BINI=20

cd $AGGREGATION_FOLDER

BAM_COUNT=`ls $BAM_FILES | wc -l`

JOB_BASENAME=".AGG#${AGGREGATION_ID}"

export FINAL_BAM=${LIBRARY_NAME}.${GENOME}.sorted.bam
export TEMP_UNIQUES_BAM=${LIBRARY_NAME}.${GENOME}.uniques.sorted.bam
export TAGCOUNTS_FILE=${LIBRARY_NAME}.tagcounts.txt
export DENSITY_STARCH=${LIBRARY_NAME}.${WIN}_${BINI}.${GENOME}.uniques-density.bed.starch
export DENSITY_BIGWIG=${LIBRARY_NAME}.${WIN}_${BINI}.${GENOME}.bw
export CUTCOUNTS_BIGWIG=$AGGREGATION_FOLDER/$LIBRARY_NAME.${GENOME}.cutcounts.$READ_LENGTH.bw

export HOTSPOT_DIR=peaks
export HOTSPOT_CALLS=$HOTSPOT_DIR/$LIBRARY_NAME.$GENOME.uniques.sorted.hotspots.fdr0.05.starch

# Hotspot hack
export PATH="/home/nelsonjs/code/hotspot2/bin:$PATH"
export HOTSPOT_SCRIPT="/home/nelsonjs/code/hotspot2/scripts/hotspot2.sh"
export EXCLUDE_REGIONS=${EXCLUDE_REGIONS:-$BWAINDEX.K${READ_LENGTH}.unmappable.bed}
export CHROM_SIZES=${CHROM_SIZES:-$BWAINDEX.chrom_sizes.bed}

if [ -n "$REDO_AGGREGATION" ]; then
    bash $STAMPIPES/scripts/bwa/aggregate/basic/reset.bash
fi

MERGE_DUP_JOBNAME=${JOB_BASENAME}_merge_dup
COUNT_JOBNAME=${JOB_BASENAME}_count
HOTSPOT_JOBNAME=${JOB_BASENAME}_hotspot
DENSITY_JOBNAME=${JOB_BASENAME}_density
CUTCOUNTS_JOBNAME=${JOB_BASENAME}_cutcounts

# Check out files match first
#python3 $STAMPIPES/scripts/utility/md5check.py bamfiles.txt || exit 1

PROCESSING=""

if [[ ! -e ${FINAL_BAM}.bai ]] ; then

PROCESSING="$PROCESSING,${MERGE_DUP_JOBNAME}"

# If we are  UMI, we will need a lot of power for sorting!
if [ "$UMI" = "True" ]; then
  echo "Processing with UMI"
  export SUBMIT_SLOTS="-pe threads 4"
  echo "Excluding duplicates from uniques bam"
  export EXCLUDE_FLAG=1536
fi

qsub ${SUBMIT_SLOTS} -N "${MERGE_DUP_JOBNAME}" -V -cwd -S /bin/bash > /dev/stderr << __SCRIPT__
  set -x -e -o pipefail

  echo "Hostname: "
  hostname

  echo "START: "
  date

  export BAM_COUNT=$BAM_COUNT

  if [ ! -s "$FINAL_BAM" ] ; then
    bash $STAMPIPES/scripts/bwa/aggregate/merge.bash
  fi

  if [ ! -s "$TEMP_UNIQUES_BAM.bai" ] ; then
    make -f $STAMPIPES/makefiles/bwa/process_paired_bam.mk SAMPLE_NAME=${LIBRARY_NAME} INBAM=${FINAL_BAM} OUTBAM=${TEMP_UNIQUES_BAM} info uniques metrics indices
  fi

  echo "FINISH: "
  date

__SCRIPT__

fi

# Run Hotspot2
if [[ ! -s "$HOTSPOT_CALLS" ]] ; then
  PROCESSING="$PROCESSING,${HOTSPOT_JOBNAME}"
  qsub ${SUBMIT_SLOTS} -hold_jid "${MERGE_DUP_JOBNAME}" -N "${HOTSPOT_JOBNAME}" -V -cwd -S /bin/bash > /dev/stderr << __SCRIPT__
    "$HOTSPOT_SCRIPT"  -F 0.5 -s 12345 -e "$EXCLUDE_REGIONS" -c "$CHROM_SIZES" "$TEMP_UNIQUES_BAM"  "$HOTSPOT_DIR"
__SCRIPT__
fi

if [ ! -e $TAGCOUNTS_FILE ]; then

PROCESSING="$PROCESSING,${COUNT_JOBNAME}"

qsub -N "${COUNT_JOBNAME}" -hold_jid ${MERGE_DUP_JOBNAME} -V -cwd -S /bin/bash > /dev/stderr << __SCRIPT__
  set -x -e -o pipefail

  echo "Hostname: "
  hostname

  echo "START: "
  date

  python3 $STAMPIPES/scripts/bwa/bamcounts.py $FINAL_BAM $TAGCOUNTS_FILE

  echo "FINISH: "
  date

__SCRIPT__

fi

if [ ! -e $DENSITY_BIGWIG ]; then

PROCESSING="$PROCESSING,${DENSITY_JOBNAME}"

qsub -N "${DENSITY_JOBNAME}" -hold_jid "${MERGE_DUP_JOBNAME}" -V -cwd -S /bin/bash > /dev/stderr << __SCRIPT__
  set -x -e -o pipefail

  echo "Hostname: "
  hostname

  echo "START: "
  date

  make -f $STAMPIPES/makefiles/densities/density.mk FAI=${GENOME_INDEX}.fai SAMPLE_NAME=${LIBRARY_NAME} GENOME=${GENOME} \
     BAMFILE=${TEMP_UNIQUES_BAM} STARCH_OUT=${DENSITY_STARCH} BIGWIG_OUT=${DENSITY_BIGWIG}
  make -f "$STAMPIPES/makefiles/densities/normalize-density.mk" BAMFILE=${TEMP_UNIQUES_BAM} SAMPLE_NAME=${LIBRARY_NAME} FAI=${GENOME_INDEX}.fai

  echo "FINISH: "
  date

__SCRIPT__

fi

if [ ! -e $CUTCOUNTS_BIGWIG ]; then

PROCESSING="$PROCESSING,${CUTCOUNTS_JOBNAME}"

qsub -N "${CUTCOUNTS_JOBNAME}" -hold_jid "${MERGE_DUP_JOBNAME}" -V -cwd -S /bin/bash > /dev/stderr << __SCRIPT__

  set -x -e -o pipefail

  echo "Hostname: "
  hostname

  echo "START: "
  date

  bash $STAMPIPES/scripts/bwa/aggregate/basic/cutcounts.bash

  echo "FINISH: "
  date

__SCRIPT__

fi

if [ -n ${PROCESSING} ]; then

UPLOAD_SCRIPT=$STAMPIPES/scripts/lims/upload_data.py
ATTACH_AGGREGATION="python3 $UPLOAD_SCRIPT --attach_file_contenttype AggregationData.aggregation --attach_file_objectid ${AGGREGATION_ID}"
qsub -N "${JOB_BASENAME}_complete" -hold_jid "${PROCESSING}" -V -cwd -S /bin/bash > /dev/stderr << __SCRIPT__
  set -x -e -o pipefail

  echo "Hostname: "
  hostname

  echo "START: "
  date

  bash $STAMPIPES/scripts/bwa/aggregate/basic/checkcomplete.bash
  bash $STAMPIPES/scripts/bwa/aggregate/basic/attachfiles.bash

  #rm ${TEMP_UNIQUES_BAM} ${TEMP_UNIQUES_BAM}.bai

  echo "FINISH: "
  date

__SCRIPT__

fi
