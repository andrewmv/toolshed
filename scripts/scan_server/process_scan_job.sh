#!/bin/bash
#
# AMV 2020/11
# Working thread for single scan job. Normally invoked by scan_dispatch.sh

### Invocation Check ### 
if [[ $# -lt 2 ]]; then
    echo "Usage: $0 scandirectory jobnumber"
    exit 1
fi

### Configuration ###

BASEPATH=/opt/scan
OUTDIR=${BASEPATH}/out
NASHOST=tanngrisnir
NASUSER=paperless

### Let's get down to business ###

SCANDIR=$1
SCANJOB=$2

# The filename at the end of the tunnel
date="$(date +%F_%H.%M.%S)"
OUTFILE="$date.pdf"

PAGE=0
for SCANFILE in ${SCANDIR}/scan*.pnm; do 
    PAGE=$(($PAGE + 1))
    ${BASEPATH}/process_scan_page.sh ${SCANJOB} ${PAGE} ${SCANFILE} &
done

# Wait for page processing threads to return
FAILCOUNT=0
for JOB in `seq $PAGE`; do
    wait -n
    if [[ $? -ne 0 ]]; then
        FAILCOUNT=$(($FAILCOUNT + 1))
    fi
done
if [[ $FAILCOUNT -ne 0 ]]; then
    logger "scan job $SCANJOB: $FAILCOUNT of $PAGE pages did not process successfully. Aborting compilation.\
            Job files can be found in ${BASEPATH}/dlq/scan-${SCANJOB}"
    mv ${SCANDIR} ${BASEPATH}/dlq
    exit 1
fi

# Optimize and compile multiple pages into a single PDF
logger "scan job $SCANJOB: Compiling Pages"
gs -dNOPAUSE -sDEVICE=pdfwrite -sOUTPUTFILE="${OUTDIR}/${OUTFILE}" -dBATCH `ls -v ${SCANDIR}/ocr*.pdf` 
if [[ $? -eq 0 ]]; then
    logger "scan job $SCANJOB: Compiling Done"
    rm ${SCANDIR}/ocr*.pdf
else
    logger "scan job $SCANJOB: Compiling Failed"
    mv ${SCANDIR} ${BASEPATH}/dlq
    exit 2
fi
#rmdir ${SCANDIR}

# Copy to NAS
logger "scan job $SCANJOB: Copying scan to NAS"
scp -P 2222 -i ${BASEPATH}/.ssh/id_rsa ${OUTDIR}/${OUTFILE} ${NASUSER}@${NASHOST}:
if [[ $? -ne 0 ]]; then
    logger "scan job $SCANJOB: Copy failed"
    mv ${OUTDIR}/${OUTFILE} ${BASEPATH}/dlq
    mv ${SCANDIR} ${BASEPATH}/dlq
    exit 3
else
    logger "scan job $SCANJOB: Complete"
    mv ${OUTDIR}/${OUTFILE} ${BASEPATH}/completed
    mv ${SCANDIR} ${BASEPATH}/completed
fi
