import std.array;
import std.contracts;
import std.stdio;
import exceptions;
import lexer;

private pure auto selectorToMethodName (dstring selector) {
	auto ret = new dchar[selector.length];
	foreach (i, ch; selector) {
		if (ch == ':')
			ret[i] = '_';
		else
			ret[i] = ch;
	}
	
	return ret;
}

class Parser {
public:
	this (string inputFile, ref File outFD, string[] includePaths) {
		this.inputFile = inputFile;
		this.outFD = outFD;
		this.includePaths = includePaths;
	}
	
	void parse () {
		lexemes = lex(inputFile);
		
		parseNested();
		assert(peek() is null);
	}

protected:
	enum State {
		Normal,
		ClassVariableList,
		ClassMethodList,
		MethodDefinition
	}
	
	struct Parameter {
	public:
		immutable(Lexeme)[] type;
		dstring name;
	}
	
	File outFD;
	string inputFile;
	string[] includePaths;
	State state;
	
	immutable(Lexeme)[] lexemes;
	string file;
	ulong line;
	dstring className;
	
	void errorOut(T...)(immutable Lexeme lexeme, T args) {
		stderr.writef("%s:%s: ", file, line);
		stderr.writef(args);
		if (lexeme !is null)
			stderr.writefln(" near %s", lexeme.content);
		else
			stderr.writeln();
		
		throw new ParseException;
	}
	
	/* Lexeme manipulation */
	immutable(Lexeme) pop () {
		if (lexemes.length == 0)
			errorOut(cast(immutable Lexeme)null, "unexpected end-of-file");
		
		auto ret = lexemes[0];
		writefln("popping lexeme %s", ret.content);
		lexemes = lexemes[1 .. $];
		
		file = ret.file;
		auto newLine = ret.line;
		
		if (newLine == line + 1)
			outFD.writeln();
		else if (newLine > line)
			// keep line numbers up-to-date
			outFD.writefln("\n#line %s \"%s\"", newLine, file);
		
		line = newLine;
		return ret;
	}
	
	immutable(Lexeme) peek () {
		if (lexemes.length == 0)
			return null;
		else
			return lexemes[0];
	}
	
	@property bool empty () {
		return lexemes.length == 0;
	}
	
	/* Semantic parsing */
	void parseNested () {
		uint nesting = 0;
		while (!empty) {
			auto lexeme = pop();
			
			switch (lexeme.token) {
			case Token.At:
				auto identifier = pop();
				if (identifier.token == Token.Identifier) {
					// this might be an Objective-D keyword
					switch (identifier.content) {
					case "class": // @class X : Y {}
						parseClass();
						continue;
					
					case "end": // @end
						parseEndBlock();
						continue;
					
					case "selector": // @selector(test:with:)
						parseSelector();
						continue;
						
					default:
						// nope, not the case
						writeLexeme(lexeme);
						writeLexeme(identifier);
						continue;
					}
				}
			
				break;
			
			case Token.LBracket:
				parseMessageSend(lexeme);
				continue;
			
			case Token.LBrace:
				++nesting;
				break;
			
			case Token.RBrace:
				if (state != State.Normal) {
					if (state == State.ClassVariableList) {
						state = State.ClassMethodList;
						continue;
					} else if (nesting == 0)
						errorOut(cast(immutable Lexeme)null, "unexpected }");
					else if (--nesting == 0) {
						writeLexeme(lexeme);
						return;
					}
				}
				
				break;
			
			case Token.Plus:
				if (state == State.ClassMethodList) {
					parseClassMethod();
					continue;
				}
				
				break;
			
			default:
				;
			}
			
			writeLexeme(lexeme);
		}
	}
	
	void parseClass () {
		if (state != State.Normal)
			errorOut(cast(immutable Lexeme)null, "unexpected @class");
	
		auto classNameL = pop();
		if (classNameL.token != Token.Identifier)
			errorOut(classNameL, "expected identifier");
		
		className = classNameL.content;
		outFD.writefln("\nMeta%s %s;", className, className);
		outFD.writeln("static this () {");
		outFD.writefln("\t%s = new Meta%s();", className, className);
		outFD.writeln("}");
		
		outFD.writefln("class Meta%s : Class {", className);
		outFD.writeln("\tthis () {");
		
		auto next = peek();
		if (next !is null && next.token == Token.Colon) {
			// pop the token
			pop();
		
			auto inheritsL = pop();
			if (inheritsL.token != Token.Identifier)
				errorOut(inheritsL, "expected identifier");
			
			outFD.writefln("\t\tsuper(\"%s\", %s);", className, inheritsL.content);
		} else {
			outFD.writefln("\t\tsuper(\"%s\");", className);
		}
		
		outFD.writeln("\t}\n");
		
		scope(exit) state = State.ClassVariableList;
		
		auto lbrace = pop();
		if (lbrace.token != Token.LBrace)
			errorOut(lbrace, "expected {");
	}
	
	void parseEndBlock () {
		if (state != State.ClassMethodList)
			errorOut(cast(immutable Lexeme)null, "unexpected @end");
		
		outFD.writeln("}");
		state = State.Normal;
	}
	
	bool parseMessageSend (immutable Lexeme lexeme, immutable(Lexeme)[] nested...) {
		auto receiver = pop();
		if (receiver.token != Token.Identifier && receiver.token != Token.LBracket) {
			// this is apparently *not* a message send
			foreach (parent; nested)
				writeLexeme(parent);
			
			writeLexeme(lexeme);
			writeLexeme(receiver);
			return false;
		}
		
		if (receiver.token == Token.LBracket) {
			// nested message send
			if (!parseMessageSend(receiver, nested ~ lexeme))
				return false;
		}
		
		auto firstWord = pop();
		if (firstWord.token != Token.Identifier) {
			// this is apparently *not* a message send
			foreach (parent; nested)
				writeLexeme(parent);
			
			writeLexeme(lexeme);
			writeLexeme(receiver);
			writeLexeme(firstWord);
			return false;
		}
		
		if (receiver.token == Token.Identifier) {
			// write out receiver of the message
			outFD.write(receiver.content);
		}
		
		auto selector = firstWord.content.dup;
		immutable(Lexeme)[] arguments;
		
		// todo: parse nested parens with identifiers
		for (;;) {
			auto next = pop();
			if (next.token == Token.RBracket)
				break;
			else if (next.token == Token.Colon) {
				selector ~= ":";
				arguments ~= pop();
			} else if (next.token == Token.Identifier) {
				selector ~= next.content;
			} else
				arguments ~= pop();
		}
		
		// write out finalized message send
		outFD.writef(".msgSend!id(sel_registerName(\"%s\")", selector);
		foreach (arg; arguments) {
			outFD.write(", ");
			writeLexeme(arg);
		}
		
		outFD.writef(") ");
		return true;
	}
	
	void parseClassMethod () {
		parseMethod();
	}
	
	void parseMethod () {
		auto lparen = pop();
		if (lparen.token != Token.LParen)
			errorOut(lparen, "expected (");
		
		immutable(Lexeme)[] returnType;
		for (;;) {
			auto next = pop();
			if (next.token == Token.RParen)
				break;
			else
				returnType ~= next;
		}
		
		auto firstWord = pop();
		if (firstWord.token != Token.Identifier)
			errorOut(firstWord, "expected method name");
		
		auto selector = firstWord.content.dup;
		Parameter[] parameters;
		
		for (;;) {
			auto next = peek();
			if (next is null)
				errorOut(next, "expected {");
			else if (next.token == Token.LBrace)
				break;
			
			pop();
			if (next.token == Token.Colon) {
				selector ~= ":";
				parameters ~= parseParameter();
			} else if (next.token == Token.Identifier)
				selector ~= next.content;
			else
				errorOut(next, "expected parameter or method name");
		}
		
		outFD.write('\t');
		foreach (lexeme; returnType)
			writeLexeme(lexeme);
		
		outFD.writef("%s (id self, SEL cmd", selectorToMethodName(assumeUnique(selector)));
		foreach (ref param; parameters) {
			outFD.write(", ");
		
			foreach (lexeme; param.type)
				writeLexeme(lexeme);
			
			outFD.write(param.name);
		}
		
		outFD.write(") ");
		
		// recursively parse method body
		parseNested();
	}
	
	Parameter parseParameter () {
		Parameter param;
	
		auto lparen = pop();
		if (lparen.token != Token.LParen)
			errorOut(lparen, "expected (");
		
		for (;;) {
			auto next = pop();
			if (next.token == Token.RParen)
				break;
			else
				param.type ~= next;
		}
		
		auto identifier = pop();
		if (identifier.token != Token.Identifier)
			errorOut(identifier, "expected argument name");
		
		param.name = identifier.content;
		return param;
	}
	
	void parseSelector () {
		auto lparen = pop();
		if (lparen.token != Token.LParen)
			errorOut(lparen, "expected (");
		
		auto firstWord = pop();
		if (firstWord.token != Token.Identifier)
			errorOut(firstWord, "expected selector name");
		
		auto selector = firstWord.content.dup;
		for (;;) {
			auto next = pop();
			if (next.token == Token.RParen)
				break;
			else if (next.token == Token.Colon)
				selector ~= ":";
			else if (next.token == Token.Identifier)
				selector ~= next.content;
			else
				errorOut(next, "expected selector name or closing parenthesis");
		}
		
		outFD.writef("sel_registerName(\"%s\") ", selector);
	}
	
	void writeLexeme (immutable Lexeme lexeme) {
		lexeme.writeToFile(outFD);
	}
}
