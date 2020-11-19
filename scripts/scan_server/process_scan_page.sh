#!/bin/bash
#
# AMV 2020/11
# Working thread for single scan page. Normally invoked by process_scan_job.sh

### Invocation Check ### 
if [[ $# -lt 3 ]]; then
    echo "Usage: $0 jobnumber pagenumber file"
    exit 1
fi

### Configuration ###

# Trim sensitivity (ImageMagick)
FUZZ_FACTOR="8%"

# Extra deskewing controls
UNPAPER_EXTRA_ARGS="--layout single --deskew-scan-range 10 --no-grayfilter --mask-scan-threshold 0.55"
SKIP_DESKEWING=False 

### The Good Stuff ###

SCANJOB=$1
PAGE=$2
SCANFILE=$3

# Detect orientation, rotate, and trim

TARGET=$(echo ${SCANFILE} | sed -r 's/scan([0-9]*\.pnm)/rotated\1/')
ROTATE=$(tesseract ${SCANFILE} stdout --oem 0 --psm 0 2>/dev/null | grep '^Rotate: ' | sed -r 's/^Rotate: ([0-9]*)$/\1/')
logger "scan job $SCANJOB: Rotating page $PAGE by $ROTATE degress"
convert $SCANFILE -rotate $ROTATE -trim -fuzz ${FUZZ_FACTOR} $TARGET
#    rm ${SCANFILE}
SCANFILE=${TARGET}

# Fix contrast and deskew

TARGET=$(echo ${SCANFILE} | sed -r 's/rotated([0-9]*\.pnm)/deskewed\1/')
logger "scan job $SCANJOB: Deskewing page $PAGE"
unpaper ${SCANFILE} ${TARGET} ${UNPAPER_EXTRA_ARGS}
SCANFILE=${TARGET}

# OCR

TARGET=$(echo ${SCANFILE} | sed -r 's/(deskewed|rotated)(.*)\.pnm$/ocr\2/')
logger "scan job $SCANJOB: OCRing page $PAGE"
tesseract ${SCANFILE} ${TARGET} -l eng pdf
if [[ $? -ne 0 ]]; then
    logger "scan job $SCANJOB: Failed to OCR page $PAGE - creating non-searchable PDF"
    convert ${SCANFILE} ${TARGET}.pdf
fi

# Fix the tesseract bug that fails to embed DPI value correct

mogrify -set units PixelsPerInch -density 300 ${TARGET}.pdf

# Return successful even if mogrification failed
logger "scan job $SCANJOB: Finished processing page $PAGE"
exit 0

