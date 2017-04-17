prefix=/usr/local

.PHONY: all install

all:

install:
	rsync -rpE bin share "${prefix}"