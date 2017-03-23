prefix=/usr/local

.PHONY: all install

all:

install:
	mkdir -p ${prefix}/share/vmtools/subcommands ${prefix}/bin
	install share/vmtools/subcommands/*.sh ${prefix}/share/vmtools/subcommands
	install bin/* ${prefix}/bin