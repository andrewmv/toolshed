#!/bin/bash
#
# AMV 2020/11
# Start an ADF scan from the ScanSnap - invoked by scanbd on button press

### Configuration ###

# Determine with `scanimage -L`
SCANNER="fujitsu:ScanSnap iX500:1505803"

BASEPATH=/opt/scan
SCANDIR=${BASEPATH}/tmp
SCANDIR=`mktemp -d ${SCANDIR}/scan-XXXXXX`
SCANJOB=`echo ${SCANDIR} | sed 's/^.*-//'`

# Do scan
logger "Scan job $SCANJOB: Starting scan"
scanimage --batch=${SCANDIR}/scan%d.pnm --format=pnm --mode Color -d "${SCANNER}" --source "ADF Duplex" --resolution 300
if [[ $? -ne 0 ]]; then
    logger "scan job $SCANJOB: scanimage exited non-zero: $?"
    exit 2
fi

# Sanity check
ls ${SCANDIR}/scan*.pnm > /dev/null 2>&1
if [[ $? -ne 0 ]]; then
    logger "scan job $SCANJOB: No pages scanned, aborting"
    exit 1
fi

# Processing takes a while - fork it off into the background and release the
# scanner for new jobs
${BASEPATH}/process_scan_job.sh $SCANDIR $SCANJOB & 
