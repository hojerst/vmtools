#!/bin/sh

CONFDIR="$HOME/.vmtools"
IMAGEDIR="$CONFDIR/images"

cp -a bin "$HOME"
if [ ! -e "$CONFDIR" ] ; then
    cp -a config/ "$CONFDIR"
fi

mkdir -p "$IMAGEDIR"
