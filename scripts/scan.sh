#!/bin/bash
#
# AMV 2020/11
# Start an ADF scan from the ScanSnap - invoked by scanbd on button press
# Borrowed / modified from https://kliu.io/post/automatic-scanning-with-scansnap-s500m/

### Configuration ###

# Determine with `scanimage -L`
SCANNER="fujitsu:ScanSnap iX500:1505803"
NASHOST=tanngrisnir
NASUSER=paperless

BASEPATH=/opt/scan
SCANDIR=${BASEPATH}/tmp
SCANDIR=`mktemp -d ${SCANDIR}/scan-XXXXXX`
SCANJOB=`echo ${SCANDIR} | sed 's/^.*-//'`
OUTDIR=${BASEPATH}/out

date="$(date --utc +%Y%m%d%H%m%SZ)"
filename="$date.pdf"

# Do scan
logger "Starting scan job $SCANJOB"
scanimage --batch=${SCANDIR}/scan%d.pnm --format=pnm --mode Color -d "${SCANNER}" --source "ADF Duplex" --resolution 300
if [[ $? -ne 0 ]]; then
    logger "$SCANJOB: scanimage exited non-zero: $?"
    exit 2
fi

# Sanity check
ls ${SCANDIR}/scan*.pnm > /dev/null 2>&1
if [[ $? -ne 0 ]]; then
    echo "No pages scanned, aborting"
    exit 1
fi

# Detect orientation and rotate
PAGE=1
for SCANFILE in ${SCANDIR}/scan*.pnm; do 
    TARGET=$(echo ${SCANFILE} | sed 's/^out/rotated/')
    ROTATE=$(tesseract ${SCANFILE} stdout --oem 0 --psm 0 2>/dev/null | grep '^Rotate: ' | sed -r 's/^Rotate: ([0-9]*)$/\1/')
    if [[ $ROTATE -eq 0 ]]; then
        logger "$SCANJOB: Page $PAGE doesn't need rotation"
        mv ${SCANFILE} ${TARGET}
    else
        logger "$SCANJOB: Rotating page $PAGE by $ROTATE degress"
        convert $SCANFILE -rotate $ROTATE $TARGET
    fi
    PAGE=$(($PAGE + 1))
done
        
# Fix contrast and deskew
PAGE=1
for SCANFILE in ${SCANDIR}/rotated*.pnm; do 
    TARGET=$(echo ${SCANFILE} | sed 's/^rotated/deskewed/')
    logger "$SCANJOB: Deskewing page $PAGE"
    unpaper ${SCANFILE} ${TARGET}
    PAGE=$(($PAGE + 1))
done

# OCR
PAGE=1
for SCANFILE in ${SCANDIR}/deskewed*.pnm; do 
    TARGET=$(echo ${SCANFILE} | sed -r 's/deskewed(.*)\.pnm$/ocr\1/')
    logger "$SCANJOB: OCRing page $PAGE"
    tesseract ${SCANFILE} ${TARGET} -l eng pdf
    if [[ $? -eq 0 ]]; then
        logger "SCANJOB: Failed to OCR page $PAGE - creating non-searchable PDF"
        convert ${SCANFILE} ${TARGET}.pdf
    PAGE=$(($PAGE + 1))
done

# Optimize and compile multiple pages into a single PDF
echo -n "Compiling..."
gs -dNOPAUSE -sDEVICE=pdfwrite -sOUTPUTFILE="${OUTDIR}/${filename}" -dBATCH `ls -v ${SCANDIR}/ocr*.pdf` 
if [[ $? -eq 0 ]]; then
    echo "done"
    rm ${SCANDIR}/*.pdf
    rmdir ${SCANDIR}
else
    echo "failed"
fi

# Copy to NAS
logger "Copying scan to NAS"
scp -P 2222 -i /home/pi/.ssh/id_rsa ${OUTDIR}/${filename} ${NASUSER}@${NASHOST}:
if [[ $? -ne 0 ]]; then
    logger "$SCANJOB: Copy failed"
    mv ${OUTDIR}/${filename} ${BASEPATH}/dlq
    exit 3
else
    logger "$SCANJOB: Complete"
    mv ${OUTDIR}/${filename} ${BASEPATH}/completed
fi

# Clean up
# rm -vf /${OUTDIR}/${filename}
