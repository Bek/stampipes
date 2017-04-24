source "$MODULELOAD"
module load samtools/1.3
module load gcc/4.7.2     # for adapter trimming
module load coreutils/8.25 # parallel sort
module load STAR/2.4.2a
module load perl/5.16.3

source "$PYTHON3_ACTIVATE"

outdir=$(pwd)

scriptdir="$STAMPIPES/scripts/rna-star/"
script="$scriptdir/STAR_ONLY.sh"

REFDIR=$(dirname "$BWAINDEX")

# $STAR_DIR is set by the process template, and are relative to the reference directory
export STARdir="$REFDIR/$STAR_DIR"

TRIMDIR="trimmed/"
TRIM_R1=$TRIMDIR/$(basename "$R1_FASTQ")
TRIM_R2=$TRIMDIR/$(basename "$R2_FASTQ")
mkdir -p "$TRIMDIR"

dataType="str_PE"  # 4 types; str_SE str_PE unstr_SE unstr_PE

ADAPTER_FILE=${SAMPLE_NAME}.adapters.txt
VERSION_FILE=${SAMPLE_NAME}.versions.txt

bash "$STAMPIPES/scripts/versions.bash" &> "$VERSION_FILE"
if [[ ( -n "$ADAPTER_P7" ) && ( -n "$ADAPTER_P5" ) ]] ; then
  echo -e "P7\t$ADAPTER_P7\nP5\t$ADAPTER_P5" > "$ADAPTER_FILE"
fi

python3 "$STAMPIPES/scripts/lims/upload_data.py" \
  -a "$LIMS_API_URL"             \
  -t "$LIMS_API_TOKEN"           \
  --alignment_id "$ALIGNMENT_ID" \
  --start_alignment_progress     \
  --adapter_file "$ADAPTER_FILE" \
  --version_file "$VERSION_FILE"

# Collate FastQ files
if [[ ( ! -e "$R1_FASTQ" ) || ( ! -e "$R2_FASTQ" ) ]] ; then
  bash "$STAMPIPES/processes/fastq/collate_fastq.bash"
fi

# Perform trimming
if [[ ( "$ADAPTER_P7"  == "NOTAVAILABLE" ) || ( "$ADAPTER_P5" == "NOTAVAILABLE" ) ]] ; then
  TRIM_R1=$R1_FASTQ
  TRIM_R2=$R2_FASTQ
else 
  if [[ ( ! -e "$TRIM_R1" ) || ( ! -e "$TRIM_R2" ) ]] ; then
    trim-adapters-illumina -f "$ADAPTER_FILE" \
      --threads=2 \
      -1 P5 -2 P7 \
      "$R1_FASTQ" \
      "$R2_FASTQ" \
      "$TRIM_R1.tmp" \
      "$TRIM_R2.tmp" \
      &> "$outdir/adapter_trimming.txt"

    mv "$TRIM_R1.tmp" "$TRIM_R1"
    mv "$TRIM_R2.tmp" "$TRIM_R2"
  fi
fi

jobbase="${SAMPLE_NAME}-ALIGN#${ALIGNMENT_ID}"
starjob=".rs$jobbase"
uploadjob=".up$jobbase"

# Run STAR
if ! "$STAMPIPES/scripts/rna-star/checkcomplete.bash" ; then
  star_jobid=$(sbatch --export=ALL -J "$starjob" -o "$starjob.o%A" -e "$starjob.e%A" --partition=$QUEUE --cpus-per-task=4 --ntasks=1 --mem-per-cpu=16000 --parsable --oversubscribe <<__RNA-STAR__
#!/bin/bash
    set -x

    STARdir=\$("$STAMPIPES/scripts/cache.sh" "$STARdir")
    nThreadsSTAR=\$((SLURM_CPUS_PER_TASK * 2))

    cd "$outdir"
    "$script" "$TRIM_R1" "$TRIM_R2" "\$STARdir" "$dataType" "\$nThreadsSTAR" 

__RNA-STAR__
)
fi

# Check for completeness and upload files.
sbatch --export=ALL -J "$uploadjob" --dependency=afterok:$star_jobid -o "$uploadjob.o%A" -e "$uploadjob.e%A" --partition=$QUEUE --cpus-per-task=1 --ntasks=1 --mem-per-cpu=1000 --parsable --oversubscribe <<__UPLOAD__
#!/bin/bash

  set -e
  bash "$STAMPIPES/scripts/rna-star/checkcomplete.bash"
  bash "$STAMPIPES/scripts/rna-star/attachfiles.sh"

  python3 "$STAMPIPES/scripts/lims/upload_data.py" \
    -a "$LIMS_API_URL"             \
    -t "$LIMS_API_TOKEN"           \
    --alignment_id "$ALIGNMENT_ID" \
    --finish_alignment

__UPLOAD__
