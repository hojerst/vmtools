#!/bin/sh

cp -a bin "$HOME"

if [ ! -e "$HOME/.vmtoolsconfig" ] ; then
    cp config/sample "$HOME/.vmtoolsconfig"
fi
