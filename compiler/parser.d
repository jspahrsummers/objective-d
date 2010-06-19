/*
 * parser.d
 * Objective-D compiler
 *
 * Copyright (c) 2010 Justin Spahr-Summers <Justin.SpahrSummers@gmail.com>
 * 
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

import std.array;
import std.contracts;
import std.stdio;
import std.string;
import std.traits;
import exceptions;
import lexer;

private void LexemeDebug(uint L = __LINE__) (immutable Lexeme lexeme) {
	debug {
		writefln("DEBUG: source line %s, lexeme %s", L, lexeme.description);
	}
}

private void errorOut(T...)(immutable Lexeme lexeme, T args) {
	stderr.writef("%s:%s: ", lexeme.file, lexeme.line);
	stderr.writef(args);
	stderr.writefln(" near %s", lexeme.content);
	
	throw new ParseException;
}

private immutable(Lexeme) newToken (dstring content) {
	return new Lexeme(tokenForString(content), content);
}

private immutable(Lexeme) newIdentifier (dstring content) {
	return new Lexeme(Token.Identifier, content, null, 0);
}

private immutable(Lexeme) newString (dstring content) {
	return new Lexeme(Token.String, content, null, 0);
}

private pure auto selectorToIdentifier (dstring selector) {
	auto ret = new dchar[selector.length];
	foreach (i, ch; selector) {
		if (ch == ':')
			ret[i] = '_';
		else
			ret[i] = ch;
	}
	
	return "_objd_sel_" ~ assumeUnique(ret);
}

private pure auto metaClassName (dstring name) {
	return "Meta" ~ name;
}

private pure auto classInstanceName (dstring name) {
	return name ~ "Inst";
}

private immutable(Lexeme[]) objdNamespace (dstring moduleName = "runtime") {
	return [
		newIdentifier("objd"),
		newToken("."),
		newIdentifier(moduleName),
		newToken(".")
	];
}

private immutable struct Parameter {
public:
	immutable Lexeme[] type;
	dstring name;
	
	this (immutable Lexeme[] type, dstring name) {
		this.type = type;
		this.name = name;
	}
}

private immutable class Method {
public:
	immutable Lexeme[] returnType;
	dstring selector;
	immutable Lexeme[] implementationBody;
	immutable Parameter[] parameters;
	bool classMethod;
	
	this (bool classMethod, immutable Lexeme[] returnType, dstring selector, immutable Parameter[] parameters, immutable Lexeme[] implementationBody) {
		this.returnType = returnType;
		this.selector = selector;
		this.parameters = parameters;
		this.implementationBody = implementationBody;
		this.classMethod = classMethod;
	}
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
		case Token.ObjD_class:
			lexemes = lexemes[1 .. $];
			output ~= parseClass(lexemes);
			break;
			
		case Token.ObjD_objc:
			lexemes = lexemes[1 .. $];
			output ~= parseObjectiveCClass(lexemes);
			break;
			
		case Token.ObjD_selector:
			lexemes = lexemes[1 .. $];
			output ~= parseSelector(lexemes);
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
	auto metaClass = newIdentifier(metaClassName(className));
	auto classInstance = newIdentifier(classInstanceName(className));
	
	// MetaClassName ClassName;
	output ~= metaClass;
	output ~= classNameL;
	output ~= newToken(";");
	
	// class MetaClassName : objd.runtime.Class {
	output ~= newIdentifier("class");
	output ~= metaClass;
	output ~= newToken(":");
	output ~= objdNamespace();
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
		lexemes = lexemes[1 .. $];
		auto inheritsL = parseNamespacedIdentifier(lexemes);
		
		//  super("ClassName", SuperclassName);
		output ~= newIdentifier("super");
		output ~= newToken("(");
		output ~= newString(className);
		output ~= newToken(",");
		output ~= inheritsL;
		output ~= newToken(")");
		output ~= newToken(";");
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
	
	// } /* class MetaClassName */
	output ~= newToken("}");
	
	// class ClassNameInst : objd.runtime.Instance {
	output ~= newIdentifier("class");
	output ~= classInstance;
	output ~= newToken(":");
	output ~= objdNamespace();
	output ~= newIdentifier("Instance");
	output ~= newToken("{");
	
	output ~= parseVariableDefinitions(className, lexemes);
	
	// } /* class ClassNameInst */
	output ~= newToken("}");
	
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
	
	// ClassName.isa.addMethod(sel_registerName("alloc")
	output ~= classNameL;
	output ~= newToken(".");
	output ~= newIdentifier("isa");
	output ~= newToken(".");
	output ~= newIdentifier("addMethod");
	output ~= newToken("(");
	output ~= objdNamespace();
	output ~= newIdentifier("sel_registerName");
	output ~= newToken("(");
	output ~= newString("alloc");
	output ~= newToken(")");
	
	// , function id (id self, SEL cmd) {
	output ~= newToken(",");
	output ~= newIdentifier("function");
	output ~= newIdentifier("id");
	output ~= newToken("(");
	output ~= newIdentifier("id");
	output ~= newIdentifier("self");
	output ~= newToken(",");
	output ~= newIdentifier("SEL");
	output ~= newIdentifier("cmd");
	output ~= newToken(")");
	output ~= newToken("{");
	
	// id obj = new ClassNameInst;
	output ~= newIdentifier("id");
	output ~= newIdentifier("obj");
	output ~= newToken("=");
	output ~= newIdentifier("new");
	output ~= classInstance;
	output ~= newToken(";");
	
	// obj.isa = ClassName;
	output ~= newIdentifier("obj");
	output ~= newToken(".");
	output ~= newIdentifier("isa");
	output ~= newToken("=");
	output ~= classNameL;
	output ~= newToken(";");
	
	// return obj;
	output ~= newIdentifier("return");
	output ~= newIdentifier("obj");
	output ~= newToken(";");
	
	// }); /* ClassName.isa.addMethod() */
	output ~= newToken("}");
	output ~= newToken(")");
	output ~= newToken(";");
	
	// includes @end
	auto methods = parseMethodDefinitions(lexemes);
	
	foreach (method; methods) {
		// this is inside a module constructor, so we can add methods
		// ClassName.
		output ~= classNameL;
		output ~= newToken(".");
		
		if (method.classMethod) {
			// isa.
			output ~= newIdentifier("isa");
			output ~= newToken(".");
		}
		
		// addMethod(
		output ~= newIdentifier("addMethod");
		output ~= newToken("(");
		
		// sel_registerName("name")
		output ~= objdNamespace();
		output ~= newIdentifier("sel_registerName");
		output ~= newToken("(");
		output ~= newString(method.selector);
		output ~= newToken(")");
		
		// , function return_type (
		output ~= newToken(",");
		output ~= newIdentifier("function");
		output ~= method.returnType;
		output ~= newToken("(");
		
		if (method.classMethod)
			// ClassName
			output ~= metaClass;
		else
			// ClassNameInst
			output ~= classInstance;
			
		// self, SEL cmd
		output ~= newIdentifier("self");
		output ~= newToken(",");
		output ~= newIdentifier("SEL");
		output ~= newIdentifier("cmd");
		
		foreach (ref param; method.parameters) {
			// , parameter_type parameter_name
			output ~= newToken(",");
			output ~= param.type;
			output ~= newIdentifier(param.name);
		}
		
		// ) /* function */
		output ~= newToken(")");
		
		output ~= method.implementationBody;
		
		// ) /* addMethod */ ;
		output ~= newToken(")");
		output ~= newToken(";");
	}
	
	// } /* static this () */
	output ~= newToken("}");
	
	foreach (method; methods) {
		// mixin _objDAliasTypeToSelectorReturnType!(method_return_type, "selector:name:", "_objd_sel_methodNameWith__rettype");
		output ~= newIdentifier("mixin");
		output ~= newIdentifier("_objDAliasTypeToSelectorReturnType");
		output ~= newToken("!");
		output ~= newToken("(");
		output ~= method.returnType;
		output ~= newToken(",");
		output ~= newString(method.selector);
		output ~= newToken(",");
		output ~= newString(selectorToIdentifier(method.selector) ~ "_rettype");
		output ~= newToken(")");
		output ~= newToken(";");
	}
	
	return assumeUnique(output);
}

private immutable(Lexeme[]) parseObjectiveCClass (ref immutable(Lexeme)[] lexemes) {
	immutable(Lexeme)[] output;
	
	auto className = lexemes[0];
	if (className.token != Token.Identifier)
		errorOut(className, "expected Objective-C class name");
		
	if (lexemes[1].token != Token.Semicolon)
		errorOut(lexemes[1], "expected ;");
		
	lexemes = lexemes[2 .. $];
	
	// objd.objc.Class ClassName;
	output ~= objdNamespace("objc");
	output ~= newIdentifier("Class");
	output ~= className;
	output ~= newToken(";");
	
	// static this () {
	output ~= newIdentifier("static");
	output ~= newIdentifier("this");
	output ~= newToken("(");
	output ~= newToken(")");
	output ~= newToken("{");
	
	// ClassName = new objd.objc.Class("ClassName")
	output ~= className;
	output ~= newToken("=");
	output ~= newIdentifier("new");
	output ~= objdNamespace("objc");
	output ~= newIdentifier("Class");
	output ~= newToken("(");
	output ~= newString(className.content);
	output ~= newToken(")");
	output ~= newToken(";");
	
	// } /* static this () */
	output ~= newToken("}");
	
	return output;
}

private immutable(Lexeme[]) parseVariableDefinitions (dstring className, ref immutable(Lexeme)[] lexemes) {
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

private immutable(Method[]) parseMethodDefinitions (ref immutable(Lexeme)[] lexemes) {
	immutable(Method)[] output;
	
	for (;;) {
		auto next = lexemes[0];
		lexemes = lexemes[1 .. $];
		
		if (next.token == Token.ObjD_end) {
			break;
		} else if (next.token == Token.Minus) {
			output ~= parseMethod(lexemes, false);
		} else if (next.token == Token.Plus) {
			output ~= parseMethod(lexemes, true);
		} else {
		 	errorOut(next, "expected method definition");
		 }
	}
	
	return assumeUnique(output);
}

private immutable(Method) parseMethod (ref immutable(Lexeme)[] lexemes, bool classMethod) {
	auto returnType = parseType(lexemes);
	
	auto firstWord = lexemes[0];
	if (firstWord.token != Token.Identifier)
		errorOut(firstWord, "expected method name");
	
	lexemes = lexemes[1 .. $];
	
	auto selector = firstWord.content.idup;
	immutable(Parameter)[] parameters;
	
	while (lexemes[0].token != Token.LBrace) {
		if (lexemes[0].token == Token.Colon) {
			selector ~= ":";
			lexemes = lexemes[1 .. $];
			parameters ~= parseParameter(lexemes);
		} else if (lexemes[0].token == Token.Identifier) {
			selector ~= lexemes[0].content;
			lexemes = lexemes[1 .. $];
		} else
			errorOut(lexemes[0], "expected method name");
	}
	
	auto impl = parseImplementationBody(lexemes);
	return new Method(classMethod, returnType, selector, parameters, impl);
}

private immutable(Lexeme[]) parseImplementationBody (ref immutable(Lexeme)[] lexemes) {
	immutable(Lexeme)[] output;
	
	auto lbrace = lexemes[0];
	if (lbrace.token != Token.LBrace)
		errorOut(lbrace, "expected {");
	
	output ~= lbrace;
	
	lexemes = lexemes[1 .. $];
	uint nesting = 1;
	do {
		switch (lexemes[0].token) {
		case Token.LBrace:
			++nesting;
			goto default;
		
		case Token.RBrace:
			if (--nesting > 0)
				goto default;
			
			break;
			
		case Token.ObjD_selector:
			lexemes = lexemes[1 .. $];
			output ~= parseSelector(lexemes);
			break;
		
		case Token.LBracket:
			output ~= parseMessageSend(lexemes);
			
			// skip closing bracket
			assert(lexemes[0].token == Token.RBracket);
			lexemes = lexemes[1 .. $];
			break;
		
		default:
			output ~= lexemes[0];
			lexemes = lexemes[1 .. $];
		}
	} while (nesting > 0);
	
	output ~= lexemes[0];
	lexemes = lexemes[1 .. $];
	
	return assumeUnique(output);
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
	
	return objdNamespace() ~ [
		newIdentifier("sel_registerName"),
		newToken("("),
		newString(selector),
		newToken(")")
	];
}

private immutable(Lexeme[]) parseMessageSend (ref immutable(Lexeme)[] lexemes) {
	// TODO: this will break with associative arrays and some slices
	auto lbracket = lexemes[0];
	assert(lbracket.token == Token.LBracket);
	
	lexemes = lexemes[1 .. $];
	auto original = lexemes;
	
	immutable(Lexeme)[] output;
	
	auto receiver = lexemes[0];
	bool recursive = false;
	if (receiver.token == Token.LBracket) {
		// possibly a recursive message send
		output ~= parseMessageSend(lexemes);
		recursive = true;
	} else if (receiver.token == Token.RBracket) {
		// array slice/vector operation syntax
		return [ lbracket, receiver ];
	}
	
	immutable(Lexeme[]) parseToEndBracket (immutable(Lexeme)[] start) {
		// this is apparently *not* a message send
		immutable(Lexeme)[] ret = [ lbracket ];
		
		uint nesting = 1;
		do {
			if (start[0].token == Token.RBracket)
				--nesting;
			else if (start[0].token == Token.LBracket)
				++nesting;
			
			ret ~= start[0];
			start = start[1 .. $];
		} while (nesting > 0);
		
		lexemes = start;
		return ret;
	}
	
	// TODO: is .5 valid syntax for numbers? if so, this might break
	if (!recursive && receiver.token != Token.Identifier && receiver.token != Token.Dot)
		return parseToEndBracket(original);
	
	immutable(Lexeme[]) receiverL = (receiver.token == Token.Identifier ? parseNamespacedIdentifier(lexemes) : null);
	if (receiver.token != Token.Identifier)
		lexemes = lexemes[1 .. $];
	
	auto firstWord = lexemes[0];
	if (firstWord.token != Token.Identifier)
		return parseToEndBracket(original);
	
	lexemes = lexemes[1 .. $];
	if (receiver.token == Token.Identifier) {
		// include the receiver of the message
		output ~= receiverL;
	}
	
	auto selector = firstWord.content.idup;
	immutable(Lexeme)[][] arguments;
	
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
	
	// .msgSend!(
	output ~= newToken(".");
	output ~= newIdentifier("msgSend");
	output ~= newToken("!");
	output ~= newToken("(");
	
	// _objDMethodReturnTypeAlias!("_objd_sel_methodNameWith__rettype")
	output ~= newIdentifier("_objDMethodReturnTypeAlias");
	output ~= newToken("!");
	output ~= newToken("(");
	output ~= newString(selectorToIdentifier(selector) ~ "_rettype");
	output ~= newToken(")");
	
	// )(
	output ~= newToken(")");
	output ~= newToken("(");
	
	// sel_registerName("name")
	output ~= objdNamespace();
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
		output ~= lexemes[0];
	
		lexemes = lexemes[1 .. $];
		output ~= parseExpression(lexemes);
	}
	
	size_t pos;
	for (pos = 0;pos < lexemes.length;) {
		if (lexemes[pos].token == Token.RParen) {
			output ~= lexemes[pos++];
			break;
		} else if (lexemes[pos].token == Token.RBracket)
			break;
		else if (lexemes[pos].token == Token.Identifier) {
			// TODO: identifiers in expressions are broken
			//output ~= lexemes[pos++];
			break;
		} else if (lexemes[pos].token == Token.ObjD_selector) {
			auto moving = lexemes[pos + 1 .. $];
			output ~= parseSelector(moving);
			
			lexemes = moving;
			pos = 0;
			continue;
		} else if (lexemes[pos].token == Token.LBracket) {
			auto moving = lexemes[pos .. $];
			output ~= parseMessageSend(moving);
			
			// skip closing bracket
			assert(moving[0].token == Token.RBracket);
			lexemes = moving[1 .. $];
			pos = 0;
		}
		
		output ~= lexemes[pos++];
	}
	
	lexemes = lexemes[pos .. $];
	return assumeUnique(output);
}

private immutable(Parameter) parseParameter (ref immutable(Lexeme)[] lexemes) {
	auto type = parseType(lexemes);
	
	auto identifier = lexemes[0];
	if (identifier.token != Token.Identifier)
		errorOut(identifier, "expected argument name");
	
	lexemes = lexemes[1 .. $];
	return Parameter(assumeUnique(type), identifier.content);
}

private immutable(Lexeme[]) parseType (ref immutable(Lexeme)[] lexemes) {
	immutable(Lexeme)[] type;
	
	if (lexemes[0].token != Token.LParen)
		errorOut(lexemes[0], "expected (");
	
	lexemes = lexemes[1 .. $];
	for (;;) {
		auto next = lexemes[0];
		lexemes = lexemes[1 .. $];
		
		if (next.token == Token.RParen)
			break;
		else
			type ~= next;
	}
	
	return assumeUnique(type);
}

private immutable(Lexeme[]) parseNamespacedIdentifier (ref immutable(Lexeme)[] lexemes) {
	immutable(Lexeme)[] output;
	
	if (lexemes[0].token == Token.Dot) {
		output ~= lexemes[0];
		lexemes = lexemes[1 .. $];
	}
	
	for (;;) {
		if (lexemes[0].token == Token.Identifier) {
			output ~= lexemes[0];
			lexemes = lexemes[1 .. $];
			
			if (lexemes[0].token != Token.Dot)
				break;
			
			// continue with another sublevel
			output ~= lexemes[0];
			lexemes = lexemes[1 .. $];
		} else
			errorOut(lexemes[0], "expected identifier");
	}
	
	return assumeUnique(output);
}
