# Objective-D standard header sources
OBJD_SOURCES = mobject.dm

# runtime sources
# TODO: objc.d causes problems; libobjd needs to not depend on libobjc
SOURCES = hash.d hashset.d hashtable.d objc.d runtime.d types.d $(OBJD_SOURCES:.dm=.d)

# generated runtime "header" files
HEADERS = $(SOURCES:.d=.di)

# library name
PRODUCT = libobjd

# D package name for this library's modules
PACKAGE_NAME = objd

# the path to the Objective-D compiler
# this binary must exist before compiling the library
OBJDC=../../compiler/objective-d

# flags to the Objective-D compiler
OBJDCFLAGS=

.PHONY: all clean install

all: $(PRODUCT)

$(PRODUCT): $(SOURCES)
	$(DLT) $(DLTFLAGS) $(DLTOUTPUT_FLAG)$@ $^

%.d : %.dm
	$(OBJDC) -o $@ $<

clean:
	rm -f *.o
	rm -f $(PRODUCT)*
	rm -f $(HEADERS)
	rm -f $(OBJD_SOURCES:.dm=.d)

install: $(PRODUCT)
	install -CpS $(PRODUCT)* $(PREFIX)$(INSTALL_LIB)
	mkdir -p $(PREFIX)$(INSTALL_INCLUDE)/$(PACKAGE_NAME)
	cp -f $(HEADERS) $(PREFIX)$(INSTALL_INCLUDE)/$(PACKAGE_NAME)
