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

# Trim sensitivity (ImageMagick)
FUZZ_FACTOR="8%"

# Extra deskewing controls
UNPAPER_EXTRA_ARGS="--layout single --deskew-scan-range 10 --no-grayfilter --mask-scan-threshold 0.55"
SKIP_DESKEWING=False 

date="$(date --utc +%Y%m%d%H%m%SZ)"
filename="$date.pdf"

# Do scan
logger "Starting scan job $SCANJOB"
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

# Detect orientation, rotate, and trim
PAGE=1
for SCANFILE in ${SCANDIR}/scan*.pnm; do 
    TARGET=$(echo ${SCANFILE} | sed -r 's/scan([0-9]*\.pnm)/rotated\1/')
    ROTATE=$(tesseract ${SCANFILE} stdout --oem 0 --psm 0 2>/dev/null | grep '^Rotate: ' | sed -r 's/^Rotate: ([0-9]*)$/\1/')
    logger "scan job $SCANJOB: Rotating page $PAGE by $ROTATE degress"
    convert $SCANFILE -rotate $ROTATE -trim -fuzz ${FUZZ_FACTOR} $TARGET
    PAGE=$(($PAGE + 1))
#    rm ${SCANFILE}
done
        
# Fix contrast and deskew
if [[ ${SKIP_DESKEW} != "True" ]]; then
    OCR_GLOB="deskewed*.pnm"
    PAGE=1
    for SCANFILE in ${SCANDIR}/rotated*.pnm; do 
        TARGET=$(echo ${SCANFILE} | sed -r 's/rotated([0-9]*\.pnm)/deskewed\1/')
        logger "scan job $SCANJOB: Deskewing page $PAGE"
        unpaper ${SCANFILE} ${TARGET} ${UNPAPER_EXTRA_ARGS}
        PAGE=$(($PAGE + 1))
        rm ${SCANFILE}
    done
else
    OCR_GLOB="rotated*.pnm"
fi

# OCR
PAGE=1
for SCANFILE in ${SCANDIR}/${OCR_GLOB}; do 
    TARGET=$(echo ${SCANFILE} | sed -r 's/(deskewed|rotated)(.*)\.pnm$/ocr\2/')
    logger "scan job $SCANJOB: OCRing page $PAGE"
    tesseract ${SCANFILE} ${TARGET} -l eng pdf
    if [[ $? -ne 0 ]]; then
        logger "scan job $SCANJOB: Failed to OCR page $PAGE - creating non-searchable PDF"
        convert ${SCANFILE} ${TARGET}.pdf
    fi
    # Fix the tesseract bug that fails to embed DPI value correct
    mogrify -set units PixelsPerInch -density 300 ${TARGET}.pdf
    PAGE=$(($PAGE + 1))
    rm ${SCANFILE}
done

# Optimize and compile multiple pages into a single PDF
logger "scan job $SCANJOB: Compiling Pages"
gs -dNOPAUSE -sDEVICE=pdfwrite -sOUTPUTFILE="${OUTDIR}/${filename}" -dBATCH `ls -v ${SCANDIR}/ocr*.pdf` 
if [[ $? -eq 0 ]]; then
    logger "scan job $SCANJOB: Compiling Done"
else
    logger "scan job $SCANJOB: Compiling Failed"
fi
rm ${SCANDIR}/ocr*.pdf
#rmdir ${SCANDIR}

# Copy to NAS
logger "scan job $SCANJOB: Copying scan to NAS"
scp -P 2222 -i ${BASEPATH}/.ssh/id_rsa ${OUTDIR}/${filename} ${NASUSER}@${NASHOST}:
if [[ $? -ne 0 ]]; then
    logger "scan job $SCANJOB: Copy failed"
    mv ${OUTDIR}/${filename} ${BASEPATH}/dlq
    exit 3
else
    logger "scan job $SCANJOB: Complete"
    mv ${OUTDIR}/${filename} ${BASEPATH}/completed
fi

