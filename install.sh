#!/bin/sh

cp -a bin "$HOME"

CONFDIR = "$HOME/.vmtools"
if [ ! -e "$CONFDIR" ] ; then
    mkdir -p "$CONFDIR"
    cp -r config "$CONFDIR"
fi
