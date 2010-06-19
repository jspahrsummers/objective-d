# D compiler
export DC=dmd

# flags to pass to the D compiler
# compilation and linking is performed in one step, so linker flags can go here
export DFLAGS=-debug -g -w -wi -unittest

# how to pass the name of the desired output file to the D compiler
# because of a dmd quirk, the argument is passed *with no spacing* after this flag
export DOUTPUT_FLAG=-of

# tool to invoke to compile and generate libraries
export DLT=$(DC)

# flags to pass to the tool specified with DLT
# compilation and linking is performed in one step, so linker flags can go here
# an invocation of the tool specified with DLT is expected to produce .di headers
export DLTFLAGS=$(DFLAGS) -lib -H

# how to pass the name of the desired output file to the tool specified with DLIBTOOL
# because of a dmd quirk, the argument is passed *with no spacing* after this flag
export DLTOUTPUT_FLAG=-of

# installation paths
export PREFIX=/usr/local/
export INSTALL_BIN=bin
export INSTALL_LIB=lib
export INSTALL_INCLUDE=include/d

# compiler flags when using the Objective-C compatibility layer
# this should include the library in which NSObject is defined
export D_OBJCFLAGS=-L-lobjc -L-framework -LFoundation

.PHONY: all check clean compiler install lib test

all: compiler lib
check: test

clean:
	cd compiler && $(MAKE) clean
	cd lib && $(MAKE) clean
	cd test && $(MAKE) clean

compiler:
	cd compiler && $(MAKE)

install:
	cd compiler && $(MAKE) install
	cd lib && $(MAKE) install

lib:
	cd lib && $(MAKE)

test: compiler lib
	cd test && $(MAKE)
