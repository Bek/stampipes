# Requires SAMPLE_NAME and GENOME to be in the environment
# Checks that important files exist and are not size 0

EXIT=0

files=( \
    "${SAMPLE_NAME}.adapters.txt" \
    "${SAMPLE_NAME}.versions.txt" \
    "Aligned.sortedByCoord.out.bam" \
    "Aligned.toTranscriptome.out.bam" \
    "anaquin_star/RnaAlign_sequins.csv" \
    "anaquin_star/RnaAlign_summary.stats" \
    "trimmed/{SAMPLE_NAME}.trimmed.R1.fastq" \
    "trimmed/{SAMPLE_NAME}.trimmed.R2.fastq"
)

for FILE in "${files[@]}"; do
if [ ! -s $FILE ]; then
    echo "Missing $FILE"
    EXIT=1
fi
done

exit $EXIT
