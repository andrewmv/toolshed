#!/bin/bash
#
# AMV 2020/11
# Start an ADF scan from the ScanSnap - invoked by scanbd on button press
# Borrowed / modified from https://kliu.io/post/automatic-scanning-with-scansnap-s500m/

### Configuration ###

# Determine with `scanimage -L`
SCANNER="fujitsu:ScanSnap iX500:1505803"

BASEPATH=/opt/scan/var
SCANDIR=${BASEPATH}/in
SCANDIR=`mktemp -d ${SCANDIR}/scan-XXXXXX`
OUTDIR=${BASEPATH}/out

date="$(date --utc +%Y%m%d%H%m%SZ)"
filename="$date.pdf"

# Do scan
logger "Starting scan"
scanimage --batch=${SCANDIR}/out%d.pnm --format=pnm --mode Color -d "${SCANNER}" --source "ADF Duplex" --resolution 300
if [[ $? -ne 0 ]]; then
    logger "scanimage exited non-zero: $?"
    exit 2
fi

# Convert scans to PDFs
for SCANFILE in ${SCANDIR}/out*.pnm; do 
    TARGET=$(echo ${SCANFILE} | sed 's/\.pnm$/\.pdf/')
    echo -n "Converting ${SCANFILE} to ${TARGET}..."
    convert ${SCANFILE} ${TARGET} 
    if [[ $? -eq 0 ]]; then
        echo "done"
        rm ${SCANFILE}
    else
        echo "failed"
    fi
done

# Compile multiple pages into a single PDF
ls ${SCANDIR}/out*.pdf > /dev/null 2>&1
if [[ $? -ne 0 ]]; then
    echo "No pages scanned, aborting"
    exit 1
fi
echo -n "Compiling..."
gs -dNOPAUSE -sDEVICE=pdfwrite -sOUTPUTFILE="${OUTDIR}/${filename}" -dBATCH `ls -v ${SCANDIR}/out*.pdf` 
if [[ $? -eq 0 ]]; then
    echo "done"
    rm ${SCANDIR}/*.pdf
    rmdir ${SCANDIR}
else
    echo "failed"
fi
