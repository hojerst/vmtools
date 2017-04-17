#!/bin/bash

usage() {
    cat <<EOF
NAME
    images - list available images

SYNOPSIS
    images
EOF
    exit 1
}

main() {
    list_images
}