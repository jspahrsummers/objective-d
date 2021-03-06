/*
 * objd.d
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

module parser.objd;
import exceptions;
import hash;
import parser.declarations;
import parser.expressions;
import parser.lexemes;
import parser.statements;
import std.contracts;
import std.conv;
import std.string;
import std.utf;

enum dstring OBJD_METHOD_PREFIX = "msg_";

private dstring[hash_value] knownSelectors;

pure auto selectorToIdentifier (dstring selector, dstring prefix = "_objd_sel_") {
	auto ret = new dchar[selector.length];
	foreach (i, ch; selector) {
		if (ch == ':')
			ret[i] = '_';
		else
			ret[i] = ch;
	}
	
	return prefix ~ assumeUnique(ret);
}

pure auto metaClassName (dstring name) {
	return "_Meta" ~ name;
}

pure auto classInstanceName (dstring name) {
	return "_" ~ name ~ "Inst";
}

pure auto protocolInstanceName (dstring name) {
	return "_Protocol" ~ name;
}

immutable(Lexeme) registerSelector (dstring selector) {
	auto conv = toUTF8(selector);
	hash_value hash = murmur_hash(conv);
	for (;;) {
		// selector 0 is reserved
		if (hash == 0)
			hash = 1;
	
		auto entry = hash in knownSelectors;
		if (entry is null) {
			knownSelectors[hash] = selector;
			break;
		} else if (*entry == selector)
			break;
		
		hash = murmur_hash(conv, hash);
	}
	
	return new Lexeme(Token.Number, to!(dstring)(hash) ~ "U"d, null, 0);
}

immutable(Lexeme[]) objdNamespace (dstring moduleName = "runtime") {
	return [
		newIdentifier("objd"),
		newToken("."),
		newIdentifier(moduleName),
		newToken(".")
	];
}

immutable(Lexeme[]) objdCaches () {
	immutable(Lexeme)[] output;
	
	if (knownSelectors.length > 0) {
		// static this () {
		output ~= newIdentifier("static");
		output ~= newIdentifier("this");
		output ~= newToken("(");
		output ~= newToken(")");
		output ~= newToken("{");
		
		// enum string[SEL] mapping = [
		output ~= newIdentifier("enum");
		output ~= newIdentifier("string");
		output ~= newToken("[");
		output ~= objdNamespace("types");
		output ~= newIdentifier("SEL");
		output ~= newToken("]");
		output ~= newIdentifier("mapping");
		output ~= newToken("=");
		output ~= newToken("[");
		
		bool first = true;
		foreach (sel, name; knownSelectors) {
			if (!first)
				output ~= newToken(",");
			else
				first = false;
		
			output ~= new Lexeme(Token.Number, to!(dstring)(sel) ~ "U"d, null, 0);
			output ~= newToken(":");
			output ~= newString(name);
		}
		
		// ];
		output ~= newToken("]");
		output ~= newToken(";");
		
		// sel_preloadMapping(mapping);
		output ~= objdNamespace();
		output ~= newIdentifier("sel_preloadMapping");
		output ~= newToken("(");
		output ~= newIdentifier("mapping");
		output ~= newToken(")");
		output ~= newToken(";");
		
		// } /* static this */
		output ~= newToken("}");
	}
	
	return output;
}

immutable(Lexeme[]) parseObjDType (ref immutable(Lexeme)[] lexemes) {
	if (lexemes[0].token != Token.LParen)
		errorOut(lexemes[0], "expected (");
	
	lexemes = lexemes[1 .. $];
	auto type = parseDType(lexemes);
	
	if (lexemes[0].token != Token.RParen)
		errorOut(lexemes[0], "expected )");
	
	lexemes = lexemes[1 .. $];
	return type;
}

immutable(Parameter) parseParameter (ref immutable(Lexeme)[] lexemes) {
	auto type = parseObjDType(lexemes);
	
	auto identifier = lexemes[0];
	if (identifier.token != Token.Identifier)
		errorOut(identifier, "expected argument name");
	
	lexemes = lexemes[1 .. $];
	return Parameter(assumeUnique(type), identifier.content);
}

immutable(Lexeme[]) parseCategory (ref immutable(Lexeme)[] lexemes) {
	immutable(Lexeme)[] output;

	auto classNameL = lexemes[0];
	lexemes = lexemes[1 .. $];
	if (classNameL.token != Token.Identifier)
		errorOut(classNameL, "expected class name");
	
	dstring categoryName = null;
	if (lexemes[0].token == Token.LParen) {
		if (lexemes[1].token != Token.Identifier)
			errorOut(lexemes[1], "expected category name");
		
		if (lexemes[2].token != Token.RParen)
			errorOut(lexemes[2], "expected )");
		
		categoryName = lexemes[1].content;
		lexemes = lexemes[3 .. $];
	}
	
	auto className = classNameL.content;
	auto metaClass = newIdentifier(metaClassName(className));
	auto classInstance = newIdentifier(classInstanceName(className));
	
	// includes @end
	auto methods = parseMethodDefinitions(lexemes);
	
	// static this () {
	output ~= newIdentifier("static");
	output ~= newIdentifier("this");
	output ~= newToken("(");
	output ~= newToken(")");
	output ~= newToken("{");
	
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
		
		// replaceMethod(
		output ~= newIdentifier("replaceMethod");
		output ~= newToken("(");
		
		// sel_registerName("name")
		output ~= registerSelector(method.selector);
		
		// , function return_type (
		output ~= newToken(",");
		output ~= newIdentifier("function");
		output ~= method.returnType;
		output ~= newToken("(");
		
		if (method.classMethod)
			// MetaClassName
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

immutable(Lexeme[]) parseProtocol (ref immutable(Lexeme)[] lexemes) {
	immutable(Lexeme)[] output;

	assert(0);
/+
	auto protocolNameL = lexemes[0];
	lexemes = lexemes[1 .. $];
	if (protocolNameL.token != Token.Identifier)
		errorOut(protocolNameL, "expected protocol name");
	
	if (lexemes[0].token == Token.Less) {
		// TODO: parse protocol list
	}
	
	auto protocolName = protocolNameL.content;
	auto protocolInstance = newIdentifier(protocolInstanceName(protocolName));
	
	// includes @end
	auto methods = parseMethodDefinitions(lexemes);
	
	// static this () {
	output ~= newIdentifier("static");
	output ~= newIdentifier("this");
	output ~= newToken("(");
	output ~= newToken(")");
	output ~= newToken("{");
	
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
		
		// replaceMethod(
		output ~= newIdentifier("replaceMethod");
		output ~= newToken("(");
		
		// sel_registerName("name")
		output ~= registerSelector(method.selector);
		
		// , function return_type (
		output ~= newToken(",");
		output ~= newIdentifier("function");
		output ~= method.returnType;
		output ~= newToken("(");
		
		if (method.classMethod)
			// MetaClassName
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
+/
}

immutable(Lexeme[]) parseClass (ref immutable(Lexeme)[] lexemes) {
	immutable(Lexeme)[] output;

	auto classNameL = lexemes[0];
	lexemes = lexemes[1 .. $];
	if (classNameL.token != Token.Identifier)
		errorOut(classNameL, "expected class name");
	
	auto className = classNameL.content;
	auto metaClass = newIdentifier(metaClassName(className));
	auto classInstance = newIdentifier(classInstanceName(className));
	
	// __gshared MetaClassName ClassName;
	output ~= newIdentifier("__gshared");
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
	immutable(Lexeme)[] inheritsL;
	if (next.token == Token.Colon) {
		// class inherits from a superclass
		lexemes = lexemes[1 .. $];
		inheritsL = parsePrimaryExpression(lexemes);
		
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
	
	auto vars = parseVariableDefinitions(className, lexemes);
	
	// includes @end
	auto methods = parseMethodDefinitions(lexemes);
	
	{
		immutable(Lexeme)[] allocMethodBody;
		
		// {
		allocMethodBody ~= newToken("{");
		
		// id obj = new ClassNameInst;
		allocMethodBody ~= newIdentifier("id");
		allocMethodBody ~= newIdentifier("obj");
		allocMethodBody ~= newToken("=");
		allocMethodBody ~= newIdentifier("new");
		allocMethodBody ~= classInstance;
		allocMethodBody ~= newToken(";");
		
		// obj.isa = ClassName;
		allocMethodBody ~= newIdentifier("obj");
		allocMethodBody ~= newToken(".");
		allocMethodBody ~= newIdentifier("isa");
		allocMethodBody ~= newToken("=");
		allocMethodBody ~= classNameL;
		allocMethodBody ~= newToken(";");
		
		// return obj;
		allocMethodBody ~= newIdentifier("return");
		allocMethodBody ~= newIdentifier("obj");
		allocMethodBody ~= newToken(";");
		
		// } /* alloc */
		allocMethodBody ~= newToken("}");
		
		// add the generated 'alloc' method to the class
		methods ~= new Method(true, [ newIdentifier("id") ], "alloc", [], assumeUnique(allocMethodBody));
	}
	
	output ~= newIdentifier("public");
	output ~= newToken(":");
	foreach (method; methods) {
		// implement class methods as member functions
		if (!method.classMethod)
			continue;
		
		// static return_type selector_asIdentifier__ (
		output ~= newIdentifier("static");
		output ~= method.returnType;
		output ~= newIdentifier(selectorToIdentifier(method.selector, OBJD_METHOD_PREFIX));
		output ~= newToken("(");
			
		// MetaClassName self, SEL cmd
		output ~= metaClass;
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
		
		// ) /* method header */
		output ~= newToken(")");
		
		output ~= method.implementationBody;
	}
	
	// } /* class MetaClassName */
	output ~= newToken("}");
	
	// class ClassNameInst :
	output ~= newIdentifier("class");
	output ~= classInstance;
	output ~= newToken(":");
	
	if (inheritsL is null) {
		// objd.runtime.Instance
		output ~= objdNamespace();
		output ~= newIdentifier("Instance");
	} else {
		// SuperclassInst
		if (inheritsL.length > 1)
			output ~= inheritsL[0 .. $ - 1];
		
		if (inheritsL[$ - 1].token != Token.Identifier)
			errorOut(inheritsL[$ - 1], "expected superclass identifier");
		
		output ~= newIdentifier(classInstanceName(inheritsL[$ - 1].content));
	}
	
	// {
	output ~= newToken("{");
	
	output ~= vars;
	
	output ~= newIdentifier("public");
	output ~= newToken(":");
	foreach (method; methods) {
		// implement instance methods as member functions
		if (method.classMethod)
			continue;
		
		// static return_type selector_asIdentifier__ (
		output ~= newIdentifier("static");
		output ~= method.returnType;
		output ~= newIdentifier(selectorToIdentifier(method.selector, OBJD_METHOD_PREFIX));
		output ~= newToken("(");
			
		// ClassNameInst self, SEL cmd
		output ~= classInstance;
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
		
		// ) /* method header */
		output ~= newToken(")");
		
		output ~= method.implementationBody;
	}
	
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
		output ~= registerSelector(method.selector);
		
		// , &
		output ~= newToken(",");
		output ~= newToken("&");
		
		if (method.classMethod)
			// MetaClassName
			output ~= metaClass;
		else
			// ClassNameInst
			output ~= classInstance;
		
		// .selector_asIdentifier__
		output ~= newToken(".");
		output ~= newIdentifier(selectorToIdentifier(method.selector, OBJD_METHOD_PREFIX));
		
		// ) /* addMethod */ ;
		output ~= newToken(")");
		output ~= newToken(";");
	}
	
	// objd_msgSend!(void)(ClassName, sel_registerName("initialize"));
	output ~= objdNamespace();
	output ~= newIdentifier("objd_msgSend");
	output ~= newToken("!");
	output ~= newIdentifier("void");
	output ~= newToken("(");
	output ~= classNameL;
	output ~= newToken(",");
	output ~= registerSelector("initialize");
	output ~= newToken(")");
	output ~= newToken(";");
	
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

immutable(Lexeme[]) parseObjectiveCClass (ref immutable(Lexeme)[] lexemes) {
	immutable(Lexeme)[] output;
	
	auto className = lexemes[0];
	if (className.token != Token.Identifier)
		errorOut(className, "expected Objective-C class name");
		
	if (lexemes[1].token != Token.Semicolon)
		errorOut(lexemes[1], "expected ;");
		
	lexemes = lexemes[2 .. $];
	
	// __gshared objd.objc.Class ClassName;
	output ~= newIdentifier("__gshared");
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

immutable(Lexeme[]) parseVariableDefinitions (dstring className, ref immutable(Lexeme)[] lexemes) {
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

immutable(Method)[] parseMethodDefinitions (ref immutable(Lexeme)[] lexemes) {
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
	
	return output;
}

immutable(Method) parseMethod (ref immutable(Lexeme)[] lexemes, bool classMethod) {
	auto returnType = parseObjDType(lexemes);
	
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
	
	auto impl = parseFunctionBody(lexemes);
	return new Method(classMethod, returnType, selector, parameters, impl);
}
	
immutable(Lexeme[]) parseSelector (ref immutable(Lexeme)[] lexemes) {
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
	
	return [ registerSelector(selector) ];
}

immutable(Lexeme[]) parseMessageSend (ref immutable(Lexeme)[] lexemes) {
	auto save = lexemes;
	
	// TODO: this will break with associative arrays and some slices
	auto lbracket = lexemes[0];
	assert(lbracket.token == Token.LBracket);
	
	immutable(Lexeme)[] output;
	lexemes = lexemes[1 .. $];
	
	if (lexemes[0].token == Token.RBracket) {
		// this is a full slice
		output = [ lbracket, lexemes[0] ];
		lexemes = lexemes[1 .. $];
		return assumeUnique(output);
	}
	
	// receiver of the message
	immutable(Lexeme)[] receiver = parseAssignExpression(lexemes, true);
	bool superSend;
	if (receiver.length == 1 && receiver[0].token == Token.Identifier && receiver[0].content == "super") {
		superSend = true;
		receiver = [ newIdentifier("self") ];
	} else
		superSend = false;
	
	if (lexemes[0].token != Token.Identifier) {
		// this seems to be an array literal of some kind
		lexemes = save;
		return parseArrayLiteral(lexemes);
	}
	
	auto firstWord = lexemes[0];
	lexemes = lexemes[1 .. $];
	
	auto selector = firstWord.content.idup;
	immutable(Lexeme)[][] arguments;
	
	for (;;) {
		auto next = lexemes[0];
		lexemes = lexemes[1 .. $];
		
		if (next.token == Token.RBracket)
			break;
		else if (next.token == Token.Colon) {
			selector ~= ":";
			auto expr = parseExpression(lexemes);
			arguments ~= expr;
		} else if (next.token == Token.Identifier) {
			selector ~= next.content;
		} else
			errorOut(next, "expected message name");
	}
	
	// objd_msgSend!(
	output ~= objdNamespace();
	output ~= newIdentifier("objd_msgSend");
	output ~= newToken("!");
	output ~= newToken("(");
	
	// _objDMethodReturnTypeAlias!("_objd_sel_methodNameWith__rettype")
	output ~= newIdentifier("_objDMethodReturnTypeAlias");
	output ~= newToken("!");
	output ~= newToken("(");
	output ~= newString(selectorToIdentifier(selector) ~ "_rettype");
	output ~= newToken(")");
	
	if (superSend) {
		// , true
		output ~= newToken(",");
		output ~= newIdentifier("true");
	}
	
	// )(receiver,
	output ~= newToken(")");
	output ~= newToken("(");
	output ~= receiver;
	output ~= newToken(",");
	
	// sel_registerName("name")
	output ~= registerSelector(selector);
	
	foreach (expr; arguments) {
		// , argument_data
		output ~= newToken(",");
		output ~= expr;
	}
	
	// ) /* msgSend */
	output ~= newToken(")");
	
	return assumeUnique(output);
}
