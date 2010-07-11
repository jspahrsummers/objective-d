# D compiler
export DC=dmd

# flags to pass to the D compiler
# compilation and linking is performed in one step, so linker flags can go here
export DFLAGS=-g -w -wi -unittest -version=objc_compat

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
# this should include any available Foundation and AppKit frameworks
export D_OBJCFLAGS=-L-lobjc -L-framework -LFoundation -L-framework -LAppKit

# flags to use when benchmarking Objective-D
# to accurately compare timings vs. Objective-C, this turns off type safety
BENCHMARK_FLAGS=$(DFLAGS) -O -inline -release -version=unsafe

.PHONY: all benchmark check clean compiler dist distclean install lib test

all: | compiler lib
check: test

distclean: clean
dist: | check distclean
	tar -cj --exclude ".*" --exclude "*.bz2" * > objective-d-`date -j "+%F"`.tar.bz2

clean:
	cd compiler && $(MAKE) clean
	cd lib && $(MAKE) clean
	cd test && $(MAKE) clean

compiler:
	cd compiler && $(MAKE)

install:
	cd compiler && $(MAKE) install
	cd lib && $(MAKE) install

lib: | compiler
	cd lib && $(MAKE)

test: | compiler lib
	cd test && $(MAKE)

benchmark: clean
	cd compiler && DFLAGS="$(BENCHMARK_FLAGS)" $(MAKE)
	cd lib && DFLAGS="$(BENCHMARK_FLAGS)" $(MAKE)
	cd test && DFLAGS="$(BENCHMARK_FLAGS)" $(MAKE) benchmark
