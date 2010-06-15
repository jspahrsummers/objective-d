SOURCES = exceptions.d lexer.d main.d parser.d processor.d
RUNTIME_SOURCES = objd/nsobject.d objd/objc.d objd/runtime.d objd/types.d

all: objective-d

objective-d:
	dmd -w -unittest -ofobjective-d $(SOURCES)

check: objective-d
	./objective-d -o testing.d test/syntax.d
	dmd -L-lobjc -L-framework -LFoundation -oftesting testing.d $(RUNTIME_SOURCES)
	./testing

clean:
	rm -rf objective-d testing testing.d
	rm -rf *.o
