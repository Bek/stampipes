# Uploads important files as attachments to an aggregation object on the LIMS
# Required environment names:
#  * STAMPIPES
#  * LIBRARY_NAME
#  * GENOME
#  * AGGREGATION_DIR
#  * AGGREGATION_ID

UPLOAD_SCRIPT=$STAMPIPES/scripts/lims/upload_data.py

# All peaks files start with this:
PEAKS_PREFIX="peaks_v2_1_1/$LIBRARY_NAME.$GENOME.uniques.sorted"

ATTACH_AGGREGATION="python3 $UPLOAD_SCRIPT --attach_file_contenttype AggregationData.aggregation --attach_file_objectid ${AGGREGATION_ID}"

$ATTACH_AGGREGATION --attach_directory `pwd` --attach_file_purpose aggregation-directory 
$ATTACH_AGGREGATION --attach_file ${LIBRARY_NAME}.${GENOME}.sorted.bam --attach_file_purpose all-alignments-bam --attach_file_type bam
$ATTACH_AGGREGATION --attach_file ${LIBRARY_NAME}.${GENOME}.sorted.bam.bai --attach_file_purpose bam-index --attach_file_type bam-index

# Densities
$ATTACH_AGGREGATION --attach_file ${LIBRARY_NAME}.75_20.${GENOME}.bw --attach_file_purpose density-bigwig-windowed --attach_file_type bigwig
$ATTACH_AGGREGATION --attach_file ${LIBRARY_NAME}.75_20.${GENOME}.uniques-density.bed.starch --attach_file_purpose density-bed-starch-windowed --attach_file_type starch
$ATTACH_AGGREGATION --attach_file ${LIBRARY_NAME}.75_20.normalized.${GENOME}.bw --attach_file_purpose normalized-density-bigwig-windowed --attach_file_type bigwig
$ATTACH_AGGREGATION --attach_file ${LIBRARY_NAME}.75_20.normalized.${GENOME}.uniques-density.bed.starch --attach_file_purpose normalized-density-bed-starch --attach_file_type starch
$ATTACH_AGGREGATION --attach_file ${LIBRARY_NAME}.75_20.${GENOME}.uniques-density.bed.starch.bgz --attach_file_purpose density-tabix-bgz --attach_file_type bgz
$ATTACH_AGGREGATION --attach_file ${LIBRARY_NAME}.75_20.normalized.${GENOME}.uniques-density.bed.starch.bgz --attach_file_purpose normalized-density-tabix-bgz --attach_file_type bgz

# Cut counts
$ATTACH_AGGREGATION --attach_file $LIBRARY_NAME.${GENOME}.cutcounts.$READ_LENGTH.bw --attach_file_type bigwig --attach_file_purpose cutcounts-bw
$ATTACH_AGGREGATION --attach_file $LIBRARY_NAME.${GENOME}.cuts.sorted.bed.starch --attach_file_type starch --attach_file_purpose cuts-starch
$ATTACH_AGGREGATION --attach_file $LIBRARY_NAME.${GENOME}.cutcounts.sorted.bed.starch --attach_file_type starch --attach_file_purpose cutcounts-starch
$ATTACH_AGGREGATION --attach_file $LIBRARY_NAME.${GENOME}.cutcounts.sorted.bed.starch.bgz --attach_file_type bgz --attach_file_purpose cutcounts-tabix-bgz

# hotspot2 output
$ATTACH_AGGREGATION --attach_file $PEAKS_PREFIX.allcalls.starch --attach_file_purpose hotspot-per-base --attach_file_type starch
$ATTACH_AGGREGATION --attach_file $PEAKS_PREFIX.hotspots.fdr0.05.starch --attach_file_purpose hotspot-calls --attach_file_type starch
$ATTACH_AGGREGATION --attach_file $PEAKS_PREFIX.hotspots.fdr0.01.starch --attach_file_purpose hotspot-calls-1per --attach_file_type starch
$ATTACH_AGGREGATION --attach_file $PEAKS_PREFIX.hotspots.fdr0.001.starch --attach_file_purpose hotspot-calls-point1per --attach_file_type starch

$ATTACH_AGGREGATION --attach_file $PEAKS_PREFIX.peaks.fdr0.05.starch --attach_file_purpose hotspot-calls --attach_file_type starch
$ATTACH_AGGREGATION --attach_file $PEAKS_PREFIX.peaks.fdr0.01.starch --attach_file_purpose hotspot-calls-1per --attach_file_type starch
$ATTACH_AGGREGATION --attach_file $PEAKS_PREFIX.peaks.fdr0.001.starch --attach_file_purpose hotspot-calls-point1per --attach_file_type starch
$ATTACH_AGGREGATION --attach_file $PEAKS_PREFIX.peaks.fdr0.05.starch --attach_file_purpose hotspot-peaks --attach_file_type starch
$ATTACH_AGGREGATION --attach_file $PEAKS_PREFIX.peaks.fdr0.01.starch --attach_file_purpose hotspot-peaks-1per --attach_file_type starch
$ATTACH_AGGREGATION --attach_file $PEAKS_PREFIX.peaks.fdr0.001.starch --attach_file_purpose hotspot-peaks-point1per --attach_file_type starch

#TODO: We're effectively generating these twice, simplify
#$ATTACH_AGGREGATION --attach_file $PEAKS_PREFIX.cutcounts.starch --attach_file_purpose cutcounts-starch --attach_file_type starch
#$ATTACH_AGGREGATION --attach_file $PEAKS_PREFIX.density.starch --attach_file_purpose density-bed-starch-windowed --attach_file_type starch

python3 $UPLOAD_SCRIPT \
    --aggregation_id ${AGGREGATION_ID} \
    --insertsfile ${LIBRARY_NAME}.CollectInsertSizeMetrics.picard 

if [ -e ${LIBRARY_NAME}.MarkDuplicates.picard ]; then
python3 $UPLOAD_SCRIPT \
    --aggregation_id ${AGGREGATION_ID} \
    --dupsfile ${LIBRARY_NAME}.MarkDuplicates.picard
fi

if [ -e ${LIBRARY_NAME}.${GENOME}.fragments.sorted.bed.starch ]; then
    $ATTACH_AGGREGATION --attach_file $LIBRARY_NAME.${GENOME}.fragments.sorted.bed.starch --attach_file_type starch --attach_file_purpose fragments-starch
fi
