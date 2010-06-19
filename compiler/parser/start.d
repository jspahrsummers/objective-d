/*
 * start.d
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

module parser.start;
import exceptions;
import parser.expressions;
import parser.lexemes;
import parser.objd;
import std.contracts;

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
	
	output ~= parseAssignExpression(lexemes);
	if (lexemes[0].token == Token.Comma) {
		output ~= lexemes[0];
		lexemes = lexemes[1 .. $];
		output ~= parseExpression(lexemes);
	}
	
	return output;
	
	/+
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
	+/
}

private immutable(Lexeme[]) parseAssignExpression (ref immutable(Lexeme)[] lexemes) {
	immutable(Lexeme)[] output;
	
	output ~= parseConditionalExpression(lexemes);
	switch (lexemes[0].token) {
	case Token.Assign:
	case Token.PlusEq:
	case Token.MinusEq:
	case Token.MulEq:
	case Token.DivEq:
	case Token.ModEq:
	case Token.AndEq:
	case Token.OrEq:
	case Token.XorEq:
	case Token.TildeEq:
	case Token.ShiftLeftEq:
	case Token.ShiftRightEq:
	case Token.UnsignedShiftRightEq:
	case Token.PowEq:
		output ~= lexemes[0];
		lexemes = lexemes[1 .. $];
		
		output ~= parseAssignExpression(lexemes);
		break;
	default:
		;
	}
	
	return output;
}

private immutable(Lexeme[]) parseConditionalExpression (ref immutable(Lexeme)[] lexemes) {
	immutable(Lexeme)[] output;
	
	output ~= parseOrOrExpression(lexemes);
	if (lexemes[0].token == Token.Question) {
		output ~= lexemes[0];
		lexemes = lexemes[1 .. $];
		
		output ~= parseExpression(lexemes);
		if (lexemes[0].token != Token.Colon)
			errorOut(lexemes[0], "expected :");
		
		output ~= lexemes[0];
		lexemes = lexemes[1 .. $];
		
		output ~= parseConditionalExpression(lexemes);
	}
	
	return output;
}

private immutable(Lexeme[]) parseOrOrExpression (ref immutable(Lexeme)[] lexemes) {
	immutable(Lexeme)[] output;
	
	output ~= parseAndAndExpression(lexemes);
	if (lexemes[0].token == Token.LogicalOr) {
		output ~= lexemes[0];
		lexemes = lexemes[1 .. $];
		
		// the D language spec actually has this the other way around
		// OrOrExpression || AndAndExpression
		// but it's okay because we don't care about precedence here
		output ~= parseOrOrExpression(lexemes);
	}
	
	return output;
}

private immutable(Lexeme[]) parseAndAndExpression (ref immutable(Lexeme)[] lexemes) {
	immutable(Lexeme)[] output;
	
	output ~= parseOrExpression(lexemes);
	if (lexemes[0].token == Token.LogicalAnd) {
		output ~= lexemes[0];
		lexemes = lexemes[1 .. $];
		
		// the D language spec actually has this the other way around
		// AndAndExpression && OrExpression
		// but it's okay because we don't care about precedence here
		output ~= parseAndAndExpression(lexemes);
	}
	
	return output;
}

private immutable(Lexeme[]) parseOrExpression (ref immutable(Lexeme)[] lexemes) {
	immutable(Lexeme)[] output;
	
	output ~= parseXorExpression(lexemes);
	if (lexemes[0].token == Token.BitwiseOr) {
		output ~= lexemes[0];
		lexemes = lexemes[1 .. $];
		
		// the D language spec actually has this the other way around
		// OrExpression | XorExpression
		// but it's okay because we don't care about precedence here
		output ~= parseOrExpression(lexemes);
	}
	
	return output;
}

private immutable(Lexeme[]) parseXorExpression (ref immutable(Lexeme)[] lexemes) {
	immutable(Lexeme)[] output;
	
	output ~= parseAndExpression(lexemes);
	if (lexemes[0].token == Token.Xor) {
		output ~= lexemes[0];
		lexemes = lexemes[1 .. $];
		
		// the D language spec actually has this the other way around
		// XorExpression ^ AndExpression
		// but it's okay because we don't care about precedence here
		output ~= parseXorExpression(lexemes);
	}
	
	return output;
}

private immutable(Lexeme[]) parseAndExpression (ref immutable(Lexeme)[] lexemes) {
	immutable(Lexeme)[] output;
	
	output ~= parseCmpExpression(lexemes);
	if (lexemes[0].token == Token.BitwiseAnd) {
		output ~= lexemes[0];
		lexemes = lexemes[1 .. $];
		
		// the D language spec actually has this the other way around
		// AndExpression & CmpExpression
		// but it's okay because we don't care about precedence here
		output ~= parseAndExpression(lexemes);
	}
	
	return output;
}

private immutable(Lexeme[]) parseCmpExpression (ref immutable(Lexeme)[] lexemes) {
	immutable(Lexeme)[] output;
	
	output ~= parseShiftExpression(lexemes);
	switch (lexemes[0].token) {
	/* EqualExpression */
	case Token.Eq:
	case Token.NotEq:
	
	/* RelExpression */
	case Token.Less:
	case Token.LessEq:
	case Token.Greater:
	case Token.GreaterEq:
	case Token.NotLessGreaterEq:
	case Token.NotLessGreater:
	case Token.LessGreater:
	case Token.LessGreaterEq:
	case Token.NotGreater:
	case Token.NotGreaterEq:
	case Token.NotLess:
	case Token.NotLessEq:
	
		// include the operator and parse the rvalue
		output ~= lexemes[0];
		lexemes = lexemes[1 .. $];
		output ~= parseShiftExpression(lexemes);
		break;
	
	case Token.Identifier:
		switch (lexemes[0].content) {
		case "is": // IdentityExpression
		case "in": // InExpression
			output ~= lexemes[0];
			lexemes = lexemes[1 .. $];
			output ~= parseShiftExpression(lexemes);
			break;
		
		default:
			;
		}
		
		break;
	
	case Token.Exclamation:
		if (lexemes[1].token == Token.Identifier) {
			switch (lexemes[1].content) {
			case "is": // IdentityExpression
			case "in": // InExpression
				output ~= lexemes[0 .. 1];
				lexemes = lexemes[2 .. $];
				output ~= parseShiftExpression(lexemes);
				break;
			default:
				;
			}
		}
		
		break;
	
	default:
		;
	}
	
	return output;
}

private immutable(Lexeme[]) parseShiftExpression (ref immutable(Lexeme)[] lexemes) {
	immutable(Lexeme)[] output;
	
	output ~= parseAddExpression(lexemes);
	switch (lexemes[0].token) {
	case Token.ShiftLeft:
	case Token.ShiftRight:
	case Token.UnsignedShiftRight:
		output ~= lexemes[0];
		lexemes = lexemes[1 .. $];
		
		// the D language spec actually has this the other way around
		// ShiftExpression << AddExpression
		// but it's okay because we don't care about precedence here
		output ~= parseShiftExpression(lexemes);
		break;
		
	default:
		;
	}
	
	return output;
}

private immutable(Lexeme[]) parseAddExpression (ref immutable(Lexeme)[] lexemes) {
	immutable(Lexeme)[] output;
	
	output ~= parseMulExpression(lexemes);
	switch (lexemes[0].token) {
	case Token.Plus:
	case Token.Minus:
	case Token.Tilde:
		output ~= lexemes[0];
		lexemes = lexemes[1 .. $];
		
		// the D language spec actually has this the other way around
		// AddExpression + MulExpression
		// but it's okay because we don't care about precedence here
		output ~= parseAddExpression(lexemes);
		break;
		
	default:
		;
	}
	
	return output;
}

private immutable(Lexeme[]) parseMulExpression (ref immutable(Lexeme)[] lexemes) {
	immutable(Lexeme)[] output;
	
	output ~= parsePowExpression(lexemes);
	switch (lexemes[0].token) {
	case Token.Star:
	case Token.Slash:
	case Token.Mod:
		output ~= lexemes[0];
		lexemes = lexemes[1 .. $];
		
		// the D language spec actually has this the other way around
		// MulExpression * PowExpression
		// but it's okay because we don't care about precedence here
		output ~= parseMulExpression(lexemes);
		break;
		
	default:
		;
	}
	
	return output;
}

private immutable(Lexeme[]) parsePowExpression (ref immutable(Lexeme)[] lexemes) {
	immutable(Lexeme)[] output;
	
	output ~= parseUnaryExpression(lexemes);
	if (lexemes[0].token == Token.Pow) {
		output ~= lexemes[0];
		lexemes = lexemes[1 .. $];
		output ~= parsePowExpression(lexemes);
	}
	
	return output;
}

private immutable(Lexeme[]) parseUnaryExpression (ref immutable(Lexeme)[] lexemes) {
	immutable(Lexeme)[] output;
	
	switch (lexemes[0].token) {
	case Token.BitwiseAnd:
	case Token.Increment:
	case Token.Decrement:
	case Token.Star:
	case Token.Minus:
	case Token.Plus:
	case Token.Exclamation:
	case Token.Tilde:
		output ~= lexemes[0];
		lexemes = lexemes[1 .. $];
		output ~= parseUnaryExpression(lexemes);
		break;
	
	case Token.Identifier:
		bool found = true;
		switch (lexemes[0].content) {
		case "new":
			output ~= lexemes[0];
			lexemes = lexemes[1 .. $];
			output ~= parseNewExpression(lexemes);
			break;
			
		case "delete":
			output ~= lexemes[0];
			lexemes = lexemes[1 .. $];
			output ~= parseUnaryExpression(lexemes);
			break;
		
		case "cast":
			if (lexemes[1].token != Token.LParen)
				errorOut(lexemes[1], "expected (");
		
			output ~= lexemes[0 .. 1]; // include opening paren
			lexemes = lexemes[2 .. $];
			output ~= parseDType(lexemes);
			
			if (lexemes[0].token != Token.RParen)
				errorOut(lexemes[0], "expected )");
				
			output ~= lexemes[0];
			lexemes = lexemes[1 .. $];
			
			output ~= parseUnaryExpression(lexemes);
			break;
		
		default:
			found = false;
		}
		
		if (found)
			break;
	
	default:
		output ~= parsePostfixExpression(lexemes);
	}
	
	return output;
}

private immutable(Lexeme[]) parseNewExpression (ref immutable(Lexeme)[] lexemes) {
	immutable(Lexeme)[] output;
	
	if (lexemes[0].token == Token.LParen) {
		output ~= lexemes[0];
		lexemes = lexemes[1 .. $];
		
		if (lexemes[0].token != Token.RParen)
			output ~= parseArgumentList(lexemes);
		
		if (lexemes[0].token != Token.RParen)
			errorOut(lexemes[0], "expected )");
			
		output ~= lexemes[0];
		lexemes = lexemes[1 .. $];
	}
	
	if (lexemes[0].token == Token.Identifier && lexemes[0].content == "class") {
		if (lexemes[1].token == Token.LParen) {
			output ~= lexemes[0 .. 1];
			lexemes = lexemes[2 .. $];
			
			if (lexemes[0].token != Token.RParen)
				output ~= parseArgumentList(lexemes);
			
			if (lexemes[0].token != Token.RParen)
				errorOut(lexemes[0], "expected )");
			
			output ~= lexemes[0];
			lexemes = lexemes[1 .. $];
		} else {
			output ~= lexemes[0];
			lexemes = lexemes[1 .. $];
		}
		
		assert(false);
		//output ~= parseBaseClassList(lexemes);
		// { DeclDefs }
	} else
		output ~= parseDType(lexemes);
	
	if (lexemes[0].token == Token.LParen) {
		output ~= lexemes[0];
		lexemes = lexemes[1 .. $];
		
		if (lexemes[0].token != Token.RParen)
			output ~= parseArgumentList(lexemes);
		
		if (lexemes[0].token != Token.RParen)
			errorOut(lexemes[0], "expected )");
		
		output ~= lexemes[0];
		lexemes = lexemes[1 .. $];
	} else if (lexemes[0].token == Token.LBracket) {
		output ~= lexemes[0];
		lexemes = lexemes[1 .. $];
		
		output ~= parseAssignExpression(lexemes);
		
		if (lexemes[0].token != Token.RBracket)
			errorOut(lexemes[0], "expected ]");
		
		output ~= lexemes[0];
		lexemes = lexemes[1 .. $];
	}
	
	return output;
}

private immutable(Lexeme[]) parsePostfixExpression (ref immutable(Lexeme)[] lexemes) {
	immutable(Lexeme)[] output;
	
	output ~= parsePrimaryExpression(lexemes);
	switch (lexemes[0].token) {
	case Token.Dot:
		auto lexeme = lexemes[1];
		output ~= lexemes[0 .. 1];
		lexemes = lexemes[2 .. $];
		
		if (lexeme.token != Token.Identifier)
			errorOut(lexeme, "expected identifier");
		
		if (lexeme.content == "new") {
			output ~= parseNewExpression(lexemes);
		}
		
		break;
	
	case Token.Increment:
	case Token.Decrement:
		output ~= lexemes[0];
		lexemes = lexemes[1 .. $];
		break;
	
	case Token.LParen:
		output ~= lexemes[0];
		lexemes = lexemes[1 .. $];
		
		if (lexemes[0].token != Token.RParen)
			output ~= parseArgumentList(lexemes);
		
		if (lexemes[0].token != Token.RParen)
			errorOut(lexemes[0], "expected )");
		
		output ~= lexemes[0];
		lexemes = lexemes[1 .. $];
		break;
	
	case Token.LBracket:
		output ~= lexemes[0];
		lexemes = lexemes[1 .. $];
		
		if (lexemes[0].token != Token.RBracket) {
			auto save = lexemes;
			try {
				// try IndexExpression first
				output ~= parseArgumentList(lexemes);
			} catch (ParseException ex) {
				// try SliceExpression
				lexemes = save;
				output ~= parseAssignExpression(lexemes);
				
				if (lexemes[0].token != Token.Range)
					errorOut(lexemes[0], "expected ..");
				
				output ~= lexemes[0];
				lexemes = lexemes[1 .. $];
				
				output ~= parseAssignExpression(lexemes);
			}
		}
		
		if (lexemes[0].token != Token.RBracket)
			errorOut(lexemes[0], "expected ]");
		
		output ~= lexemes[0];
		lexemes = lexemes[1 .. $];
		break;
	
	default:
		;
	}
	
	return output;
}

private immutable(Lexeme[]) parsePrimaryExpression (ref immutable(Lexeme)[] lexemes) {
	immutable(Lexeme)[] output;
	
	switch (lexemes[0].token) {
	case Token.Dot:
		output ~= lexemes[0];
		lexemes = lexemes[1 .. $];
		
		if (lexemes[0].token != Token.Identifier)
			errorOut(lexemes[0], "expected identifier");
	
	case Token.Identifier:
	case Token.Dollar:
	case Token.Number:
	case Token.Character:
	case Token.String:
		output ~= lexemes[0];
		lexemes = lexemes[1 .. $];
		break;
	
	case Token.LParen:
		output ~= lexemes[0];
		lexemes = lexemes[1 .. $];
		
		output ~= parseExpression(lexemes);
		
		if (lexemes[0].token != Token.RParen)
			errorOut(lexemes[0], "expected )");
			
		output ~= lexemes[0];
		lexemes = lexemes[1 .. $];
		break;
	
	// TODO:
	// ArrayLiteral
	// AssocArrayLiteral
	// FunctionLiteral
	// AssertExpression
	// MixinExpression
	// ImportExpression
	// Typeof
	// TypeidExpression
	// IsExpression
	// TraitsExpression
	default:
		errorOut(lexemes[0], "expected expression or identifier");
	}
	
	return output;
}

private immutable(Lexeme[]) parseArgumentList (ref immutable(Lexeme)[] lexemes) {
	immutable(Lexeme)[] output;
	
	output ~= parseAssignExpression(lexemes);
	if (lexemes[0].token == Token.Comma) {
		output ~= lexemes[0];
		lexemes = lexemes[1 .. $];
		output ~= parseArgumentList(lexemes);
	}
	
	return output;
}

private immutable(Parameter) parseParameter (ref immutable(Lexeme)[] lexemes) {
	auto type = parseObjDType(lexemes);
	
	auto identifier = lexemes[0];
	if (identifier.token != Token.Identifier)
		errorOut(identifier, "expected argument name");
	
	lexemes = lexemes[1 .. $];
	return Parameter(assumeUnique(type), identifier.content);
}

private immutable(Lexeme[]) parseObjDType (ref immutable(Lexeme)[] lexemes) {
	immutable(Lexeme)[] type;
	
	if (lexemes[0].token != Token.LParen)
		errorOut(lexemes[0], "expected (");
	
	lexemes = lexemes[1 .. $];
	uint nesting = 1;
	for (;;) {
		auto next = lexemes[0];
		lexemes = lexemes[1 .. $];
		
		if (next.token == Token.RParen) {
			if (--nesting == 0)
				break;
		} else if (next.token == Token.LParen)
			++nesting;
		
		type ~= next;
	}
	
	return assumeUnique(type);
}

private immutable(Lexeme[]) parseDType (ref immutable(Lexeme)[] lexemes) {
	immutable(Lexeme)[] output;
	
	assert(false);
	
	return assumeUnique(output);
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
