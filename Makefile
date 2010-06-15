SOURCES = exceptions.d lexer.d main.d parser.d processor.d
RUNTIME_SOURCES = objd/runtime.d

all: objective-d

objective-d:
	dmd -w -unittest -ofobjective-d $(SOURCES)

check: objective-d
	./objective-d -o testing.d test/syntax.d && dmd -oftesting testing.d $(RUNTIME_SOURCES) && ./testing

clean:
	rm -rf objective-d testing testing.d
	rm -rf *.o
