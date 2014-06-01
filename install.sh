#!/bin/sh

cp -a bin "$HOME"

CONFDIR="$HOME/.vmtools"
if [ ! -e "$CONFDIR" ] ; then
    cp -a config/ "$CONFDIR"
fi

IMAGEDIR="$CONFDIR/images"
mkdir -p "$IMAGEDIR"
