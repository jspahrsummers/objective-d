# compiler sources
SOURCES = exceptions.d lexer.d main.d parser.d processor.d

# binary name
PRODUCT = objective-d

.PHONY: all clean install

all: $(PRODUCT)

$(PRODUCT): $(SOURCES)
	$(DC) $(DFLAGS) $(DOUTPUT_FLAG)$@ $^

clean:
	rm -f *.o
	rm -f $(PRODUCT)

install: $(PRODUCT)
	install -CpSs $(PRODUCT) $(PREFIX)$(INSTALL_BIN)
