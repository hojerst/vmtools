#!/bin/bash

main() {
    echo "SUBCOMMANDS"

    for i in "$SUBCOMMANDDIR"/*.sh ; do
        echo "   $(basename -s .sh "$i")"
    done

    cat <<EOF

NOTE
    run '$(basename "$0") subcommand --help' for subcommand specific help
EOF
}