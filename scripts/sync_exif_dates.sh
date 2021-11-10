#!/bin/sh

# AMV 2021-11

# Overwrite the "digital creation" datetime metadata with the "date created" metadata
# The former is written by the camera, and the latter is written by Lightroom
# Useful when syncing clocks between bodies in post, and wanting the resulting album 
# to display correctly

exiftool -tagsFromFile @ $1 "-IPTC:DigitalCreationDate<IPTC:DateCreated" "-IPTC:DigitalCreationTime<IPTC:TimeCreated"

