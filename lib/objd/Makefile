# runtime sources
SOURCES = objc.d runtime.d types.d

# generated runtime "header" files
HEADERS = $(SOURCES:.d=.di)

# library name
PRODUCT = libobjd

# D package name for this library's modules
PACKAGE_NAME = objd

.PHONY: all clean install

all: $(PRODUCT)

$(PRODUCT): $(SOURCES)
	$(DLT) $(DLTFLAGS) $(DLTOUTPUT_FLAG)$@ $^

clean:
	rm -f *.o
	rm -f $(PRODUCT)*
	rm -f $(HEADERS)

install: $(PRODUCT)
	install -CpS $(PRODUCT)* $(PREFIX)$(INSTALL_LIB)
	mkdir -p $(PREFIX)$(INSTALL_INCLUDE)/$(PACKAGE_NAME)
	cp -f $(HEADERS) $(PREFIX)$(INSTALL_INCLUDE)/$(PACKAGE_NAME)
