# compiler sources
SOURCES = exceptions.d lexer.d main.d parser/declarations.d parser/expressions.d parser/lexemes.d parser/objd.d parser/start.d parser/statements.d processor.d

# binary name
PRODUCT = objective-d

# additional flags to pass to the D compiler
DFLAGS+=-debug

.PHONY: all clean install

all: $(PRODUCT)

$(PRODUCT): $(SOURCES)
	$(DC) $(DFLAGS) $(DOUTPUT_FLAG)$@ $^

clean:
	rm -f *.o
	rm -f $(PRODUCT)

install: $(PRODUCT)
	install -CpSs $(PRODUCT) $(PREFIX)$(INSTALL_BIN)
