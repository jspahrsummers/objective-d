# the path to the Objective-D compiler
# this binary must exist before trying to run tests
OBJDC=../compiler/objective-d

# flags to the Objective-D compiler
OBJDCFLAGS=

# additional flags to add to the D compiler
DFLAGS+=-I../lib -L../lib/objd/libobjd.a

# Objective-D test source files
TEST_OBJD_SOURCES=syntax.dm objc.dm

# the above source files after being passed through the Objective-D compiler
# note that changing this variable will *not* change the build process
TEST_D_PROCESSED_SOURCES=$(TEST_OBJD_SOURCES:.dm=.d)

# test binaries
TEST_PRODUCTS=$(TEST_OBJD_SOURCES:.dm=)

# TESTS are marked as phony to always build
.PHONY: all check clean

all: check
check: | $(TEST_PRODUCTS) clean

clean:
	rm -f *.o
	rm -f $(TEST_PRODUCTS)
	rm -f $(TEST_D_PROCESSED_SOURCES)

# the Objective-C test is a special case since it has dependencies
#objc:
#	$(OBJDC) -o objc.d objc.dm
#	$(DC) $(DFLAGS) $(D_OBJCFLAGS) $(DOUTPUT_FLAG)$@ objc.d
#	./$@

% :: %.dm
	$(OBJDC) -o $@.d $<
	$(DC) $(DFLAGS) $(D_OBJCFLAGS) $(DOUTPUT_FLAG)$@ $@.d
	./$@
