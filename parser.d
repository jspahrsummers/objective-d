import std.array;
import std.contracts;
import std.stdio;
import std.string;
import exceptions;
import lexer;

private void errorOut(T...)(immutable Lexeme lexeme, T args) {
	stderr.writef("%s:%s: ", lexeme.file, lexeme.line);
	stderr.writef(args);
	stderr.writefln(" near %s", lexeme.content);
	
	throw new ParseException;
}

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

private struct Parameter {
public:
	immutable Lexeme[] type;
	dstring name;
}

immutable(Lexeme[]) parse (immutable Lexeme[] lexemes) {
	auto ret = parseTopLevel(lexemes);
	assert(lexemes.length == 0);
	
	return ret;
}

// TODO: bounds checking
private immutable(Lexeme[]) parseTopLevel (ref immutable(Lexeme)[] lexemes) {
	immutable(Lexeme)[] output;

	while (lexemes.length) {
		auto lexeme = lexemes[0];
		
		switch (lexeme.token) {
		case Token.At:
			auto identifier = lexemes[1];
			switch (identifier.content) {
			case "class": // @class X : Y {} ... @end
				lexemes = lexemes[2 .. $];
				output ~= parseClass(lexemes);
				break;
			
			case "selector": // @selector(test:with:)
				lexemes = lexemes[2 .. $];
				output ~= parseSelector(lexemes);
				break;
				
			default:
				// not an Objective-D keyword
				output ~= [ lexeme, identifier ];
				lexemes = lexemes[2 .. $];
			}
			
			break;
		
		case Token.LBracket:
			output ~= parseMessageSend(lexemes);
			
			// skip closing bracket
			assert(lexemes[0].token == Token.RBracket);
			lexemes = lexemes[1 .. $];
			break;
		
		default:
			output ~= lexeme;
			lexemes = lexemes[1 .. $];
		}
	}
	
	return assumeUnique(output);
}

private immutable(Lexeme[]) parseClass (ref immutable(Lexeme)[] lexemes) {
	immutable(Lexeme)[] output;

	auto classNameL = lexemes[0];
	lexemes = lexemes[1 .. $];
	if (classNameL.token != Token.Identifier)
		errorOut(classNameL, "expected identifier");
	
	auto className = classNameL.content;
	auto metaClass = newIdentifier("Meta" ~ className);
	
	// MetaClassName ClassName;
	output ~= metaClass;
	output ~= classNameL;
	output ~= newToken(";");
	
	// static this () {
	output ~= newIdentifier("static");
	output ~= newIdentifier("this");
	output ~= newToken("(");
	output ~= newToken(")");
	output ~= newToken("{");
	
	//  ClassName = new MetaClassName();
	output ~= classNameL;
	output ~= newToken("=");
	output ~= newIdentifier("new");
	output ~= metaClass;
	output ~= newToken("(");
	output ~= newToken(")");
	output ~= newToken(";");
	
	// } /* static this () */
	output ~= newToken("}");
	
	// class MetaClassName : Class {
	output ~= newIdentifier("class");
	output ~= metaClass;
	output ~= newToken(":");
	output ~= newIdentifier("Class");
	output ~= newToken("{");
	
	//  this () {
	output ~= newIdentifier("this");
	output ~= newToken("(");
	output ~= newToken(")");
	output ~= newToken("{");
	
	auto next = lexemes[0];
	if (next.token == Token.Colon) {
		// class inherits from a superclass
		auto inheritsL = lexemes[1];
		if (inheritsL.token != Token.Identifier)
			errorOut(inheritsL, "expected identifier");
		
		//  super("ClassName", SuperclassName);
		output ~= newIdentifier("super");
		output ~= newToken("(");
		output ~= newString(className);
		output ~= newToken(",");
		output ~= inheritsL;
		output ~= newToken(")");
		output ~= newToken(";");
		
		lexemes = lexemes[2 .. $];
	} else {
		//  super("ClassName");
		output ~= newIdentifier("super");
		output ~= newToken("(");
		output ~= newString(className);
		output ~= newToken(")");
		output ~= newToken(";");
	}
	
	//  } /* this () */
	output ~= newToken("}");
	
	output ~= parseVariableDefinitions(lexemes);
	output ~= parseMethodDefinitions(lexemes);
	
	if (lexemes[0].token != Token.At || lexemes[1].content != "end")
		errorOut(lexemes[0], "expected @end");
	
	lexemes = lexemes[2 .. $];
	
	// } /* class */
	output ~= newToken("}");
	
	return assumeUnique(output);
}

private immutable(Lexeme[]) parseVariableDefinitions (ref immutable(Lexeme)[] lexemes) {
	immutable(Lexeme)[] output;
	
	auto lbrace = lexemes[0];
	if (lbrace.token != Token.LBrace)
		errorOut(lbrace, "expected {");
	
	lexemes = lexemes[1 .. $];
	while (lexemes[0].token != Token.RBrace) {
		output ~= lexemes[0];
		lexemes = lexemes[1 .. $];
	}
	
	lexemes = lexemes[1 .. $];
	return assumeUnique(output);
}

private immutable(Lexeme[]) parseMethodDefinitions (ref immutable(Lexeme)[] lexemes) {
	// TODO: everything
	return [];
}
	
private immutable(Lexeme[]) parseSelector (ref immutable(Lexeme)[] lexemes) {
	auto lparen = lexemes[0];
	if (lparen.token != Token.LParen)
		errorOut(lparen, "expected (");
	
	auto firstWord = lexemes[1];
	if (firstWord.token != Token.Identifier)
		errorOut(firstWord, "expected selector name");
	
	auto selector = firstWord.content.idup;
	lexemes = lexemes[2 .. $];
	for (;;) {
		auto next = lexemes[0];
		lexemes = lexemes[1 .. $];
		
		if (next.token == Token.RParen)
			break;
		else if (next.token == Token.Colon)
			selector ~= ":";
		else if (next.token == Token.Identifier)
			selector ~= next.content;
		else
			errorOut(next, "expected selector name or closing parenthesis");
	}
	
	return [
		newIdentifier("sel_registerName"),
		newToken("("),
		newString(selector),
		newToken(")")
	];
}

private immutable(Lexeme[]) parseMessageSend (ref immutable(Lexeme)[] lexemes) {
	auto lbracket = lexemes[0];
	assert(lbracket.token == Token.LBracket);
	lexemes = lexemes[1 .. $];
	
	immutable(Lexeme)[] output;
	
	auto receiver = lexemes[0];
	bool recursive = false;
	if (lexemes[0].token == Token.LBracket) {
		// possibly a recursive message send
		writefln("recursive message send on line %s", lexemes[0].line);
		
		output ~= parseMessageSend(lexemes);
		recursive = true;
	}
	
	auto firstWord = lexemes[1];
	if ((!recursive && receiver.token != Token.Identifier) || firstWord.token != Token.Identifier) {
		// this is apparently *not* a message send
		output = lbracket ~ output;
		
		uint nesting = 1;
		do {
			if (lexemes[0].token == Token.RBracket)
				--nesting;
			else if (lexemes[0].token == Token.LBracket)
				++nesting;
			
			output ~= lexemes[0];
			lexemes = lexemes[1 .. $];
		} while (nesting > 0);
		
		return output;
	}
	
	lexemes = lexemes[2 .. $];
	if (receiver.token == Token.Identifier) {
		// include the receiver of the message
		output ~= receiver;
	}
	
	auto selector = firstWord.content.idup;
	immutable(Lexeme)[][] arguments;
	
	// todo: parse nested parens with identifiers
	for (;;) {
		auto next = lexemes[0];
		
		if (next.token == Token.RBracket)
			break;
			
		lexemes = lexemes[1 .. $];
		if (next.token == Token.Colon) {
			selector ~= ":";
			auto expr = parseExpression(lexemes);
			arguments ~= expr;
		} else if (next.token == Token.Identifier) {
			selector ~= next.content;
		} else
			errorOut(next, "expected message name");
	}
	
	// .msgSend!id(
	output ~= newToken(".");
	output ~= newIdentifier("msgSend");
	output ~= newToken("!");
	output ~= newIdentifier("id");
	output ~= newToken("(");
	
	// sel_registerName("name")
	output ~= newIdentifier("sel_registerName");
	output ~= newToken("(");
	output ~= newString(selector);
	output ~= newToken(")");
	
	foreach (expr; arguments) {
		// , argument_data
		output ~= newToken(",");
		output ~= expr;
	}
	
	// ) /* msgSend */
	output ~= newToken(")");
	
	return assumeUnique(output);
}

private immutable(Lexeme[]) parseExpression (ref immutable(Lexeme)[] lexemes) {
	immutable(Lexeme)[] output;
	
	if (lexemes[0].token == Token.LParen) {
		lexemes = lexemes[1 .. $];
		output ~= parseExpression(lexemes);
	}
	
	size_t pos;
	for (pos = 0;pos < lexemes.length;++pos) {
		if (lexemes[pos].token == Token.RParen)
			break;
		else if (lexemes[pos].token == Token.Identifier) {
			// TODO: this could be much better
			// right now, it basically just looks for two identifiers next to each other
			if (pos > 0 && lexemes[pos - 1].token == Token.Identifier)
				break;
		}
		
		output ~= lexemes[pos];
	}
	
	lexemes = lexemes[pos .. $];
	return assumeUnique(output);
}
	
	/+
	/* Semantic parsing */
	
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
	+/
