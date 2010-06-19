/*
 * declarations.d
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

module parser.declarations;
import exceptions;
import parser.lexemes;
import parser.objd;
import parser.statements;
import std.contracts;

immutable(Lexeme[]) parseModule (ref immutable(Lexeme)[] lexemes) {
	immutable(Lexeme)[] output;

	while (lexemes.length) {
		if (lexemes[0].token == Token.Identifier && lexemes[0].content == "module") {
			output ~= lexemes[0];
			lexemes = lexemes[1 .. $];
			
			output ~= parseModuleName(lexemes);
			
			if (lexemes[0].token != Token.Semicolon)
				errorOut(lexemes[0], "expected ;");
			
			output ~= lexemes[0];
			lexemes = lexemes[1 .. $];
		} else
			output ~= parseDeclDef(lexemes);
	}
	
	return assumeUnique(output);
}

immutable(Lexeme[]) parseModuleName (ref immutable(Lexeme)[] lexemes) {
	immutable(Lexeme)[] output;
	
	if (lexemes[0].token != Token.Identifier)
		errorOut(lexemes[0], "expected identifier");
	
	output ~= lexemes[0];
	lexemes = lexemes[1 .. $];
	
	if (lexemes[0].token == Token.Dot) {
		output ~= lexemes[0];
		lexemes = lexemes[1 .. $];
		
		output ~= parseModuleName(lexemes);
	}
	
	return assumeUnique(output);
}

immutable(Lexeme[]) parseDeclDef (ref immutable(Lexeme)[] lexemes) {
	immutable(Lexeme)[] output;
	
	switch (lexemes[0].token) {
	case Token.Semicolon:
		output ~= lexemes[0];
		lexemes = lexemes[1 .. $];
		break;
	
	case Token.ObjD_class:
		lexemes = lexemes[1 .. $];
		output ~= parseClass(lexemes);
		break;
	
	case Token.ObjD_objc:
		lexemes = lexemes[1 .. $];
		output ~= parseObjectiveCClass(lexemes);
		break;
	
	case Token.Identifier:
		switch (lexemes[0].content) {
		// TODO:
		// AttributeSpecifier
		// EnumDeclaration
		// ClassDeclaration
		// InterfaceDeclaration
		// AggregateDeclaration
		// Declaration
		// Constructor
		// Destructor
		// Invariant
		// SharedStaticConstructor
		// SharedStaticDestructor
		// ConditionalDeclaration
		// TemplateDeclaration
		// TemplateMixin
		// MixinDeclaration
		
		case "static":
			// TODO:
			// ImportDeclaration
			// StaticConstructor
			// StaticAssert
			assert(false);
			break;
		
		case "import":
			output ~= parseImportList(lexemes);
			if (lexemes[0].token != Token.Semicolon)
				errorOut(lexemes[0], "expected ;");
			
			output ~= lexemes[0];
			lexemes = lexemes[1 .. $];
			break;
		
		case "unittest":
			output ~= lexemes[0];
			lexemes = lexemes[1 .. $];
			
			output ~= parseBlockStatement(lexemes);
			break;
		
		default:
			output ~= parseDeclaration(lexemes);
		}
		
		break;
	
	default:
		errorOut(lexemes[0], "expected declaration");
	}
	
	return assumeUnique(output);
}

immutable(Lexeme[]) parseImportList (ref immutable(Lexeme)[] lexemes) {
	immutable(Lexeme)[] output;
	
	if (lexemes[0].content != "import")
		errorOut(lexemes[0], "expected \"import\"");
	
	output ~= lexemes[0];
	lexemes = lexemes[1 .. $];
	
	if (lexemes[0].token != Token.Identifier)
		errorOut(lexemes[0], "expected module identifier");
	
	if (lexemes[1].token == Token.Eq) {
		output ~= lexemes[0 .. 1];
		lexemes = lexemes[2 .. $];
	}
	
	output ~= parseModuleName(lexemes);
	
	if (lexemes[0].token == Token.Comma) {
		output ~= lexemes[0];
		lexemes = lexemes[1 .. $];
		
		output ~= parseImportList(lexemes);
	} else if (lexemes[0].token == Token.Colon) {
		output ~= lexemes[0];
		lexemes = lexemes[1 .. $];
		
		output ~= parseImportBindList(lexemes);
	}
	
	return assumeUnique(output);
}

immutable(Lexeme[]) parseImportBindList (ref immutable(Lexeme)[] lexemes) {
	immutable(Lexeme)[] output;
	
	if (lexemes[0].token != Token.Identifier)
		errorOut(lexemes[0], "expected identifier");
	
	output ~= lexemes[0];
	lexemes = lexemes[1 .. $];
	
	if (lexemes[0].token == Token.Assign) {
		if (lexemes[1].token != Token.Identifier)
			errorOut(lexemes[1], "expected identifier");
	
		output ~= lexemes[0 .. 1];
		lexemes = lexemes[2 .. $];
	}
	
	if (lexemes[0].token == Token.Comma) {
		output ~= lexemes[0];
		lexemes = lexemes[1 .. $];
		
		output ~= parseImportBindList(lexemes);
	}
	
	return assumeUnique(output);
}

immutable(Lexeme[]) parseDeclaration (ref immutable(Lexeme)[] lexemes) {
	immutable(Lexeme)[] output;
	
	if (lexemes[0].content == "alias") {
		output ~= lexemes[0];
		lexemes = lexemes[1 .. $];
	}
	
	if (lexemes[0].token != Token.Identifier)
		errorOut(lexemes[0], "expected declaration");
	
	// TODO:
	// StorageClasses
	// AutoDeclaration
	
	output ~= parseBasicType(lexemes);
	output ~= parseDeclarators(lexemes);
	
	return assumeUnique(output);
}

immutable(Lexeme[]) parseBasicType (ref immutable(Lexeme)[] lexemes) {
	immutable(Lexeme)[] output;
	
	if (lexemes[0].token == Token.Dot) {
		output ~= lexemes[0];
		lexemes = lexemes[1 .. $];
	} else {
		if (lexemes[0].token != Token.Identifier)
			errorOut(lexemes[0], "expected type");
		
		switch (lexemes[0].content) {
		case "const":
		case "immutable":
		case "shared":
		case "inout":
		case "typeof":
			// TODO
			assert(false);
			return assumeUnique(output);
		
		default:
			;
		}
	}
	
	output ~= parseIdentifierList(lexemes);
	
	return assumeUnique(output);
}

immutable(Lexeme[]) parseIdentifierList (ref immutable(Lexeme)[] lexemes) {
	immutable(Lexeme)[] output;
	
	if (lexemes[0].token != Token.Identifier)
		errorOut(lexemes[0], "expected type");
		
	output ~= lexemes[0];
	lexemes = lexemes[1 .. $];
	
	if (lexemes[0].token == Token.Dot) {
		output ~= lexemes[0];
		lexemes = lexemes[1 .. $];
		output ~= parseIdentifierList(lexemes);
	}
	
	return assumeUnique(output);
}

immutable(Lexeme[]) parseDeclarators (ref immutable(Lexeme)[] lexemes) {
	immutable(Lexeme)[] output;
	
	output ~= parseDeclarator(lexemes);
	
	if (lexemes[0].token == Token.Assign) {
		assert(false);
	} else if (lexemes[0].token == Token.Comma) {
		output ~= lexemes[0];
		lexemes = lexemes[1 .. $];
		
		output ~= parseDeclarators(lexemes);
	} else if (lexemes[0].token == Token.Semicolon) {
		output ~= lexemes[0];
		lexemes = lexemes[1 .. $];
	} else {
		output ~= parseFunctionBody(lexemes);
	}
	
	return assumeUnique(output);
}

immutable(Lexeme[]) parseDeclarator (ref immutable(Lexeme)[] lexemes) {
	immutable(Lexeme)[] output;
	
	switch (lexemes[0].token) {
	case Token.Star:
		output ~= lexemes[0];
		lexemes = lexemes[1 .. $];
		break;
		
	case Token.LBracket:
		// TODO: parse array type
		assert(false);
		break;
		
	case Token.Identifier:
		if (lexemes[0].content == "delegate" || lexemes[0].content == "function") {
			// parse delegate/function pointer type
			assert(false);
		}
		
		break;
	
	default:
		errorOut(lexemes[0], "expected declarator");
	}
	
	if (lexemes[0].token != Token.Identifier) {
		output ~= parseDeclarator(lexemes);
		return assumeUnique(output);
	}
	
	output ~= lexemes[0];
	lexemes = lexemes[1 .. $];
	
	for (;;) {
		bool match = true;
		switch (lexemes[0].token) {
		// TODO:
		// postfix []
		// TemplateParameterList
		case Token.LParen:
			output ~= lexemes[0];
			lexemes = lexemes[1 .. $];
			
			if (lexemes[0].token != Token.RParen)
				output ~= parseParameterList(lexemes);
			
			if (lexemes[0].token != Token.RParen)
				errorOut(lexemes[0], "expected )");
				
			output ~= lexemes[0];
			lexemes = lexemes[1 .. $];
			break;
		
		default:
			match = false;
		}
		
		if (!match)
			break;
	}
	
	return assumeUnique(output);
}

immutable(Lexeme[]) parseParameterList (ref immutable(Lexeme)[] lexemes) {
	immutable(Lexeme)[] output;
	
	if (lexemes[0].token == Token.Ellipsis) {
		output ~= lexemes[0];
		lexemes = lexemes[1 .. $];
	} else {
		output ~= parseParameter(lexemes);
		if (lexemes[0].token == Token.Comma) {
			output ~= lexemes[0];
			lexemes = lexemes[1 .. $];
			output ~= parseParameterList(lexemes);
		} else if (lexemes[0].token == Token.Ellipsis) {
			output ~= lexemes[0];
			lexemes = lexemes[1 .. $];
		}
	}
	
	return assumeUnique(output);
}

immutable(Lexeme[]) parseParameter (ref immutable(Lexeme)[] lexemes) {
	immutable(Lexeme)[] output;
	
	// TODO:
	// InOut
	
	output ~= parseDeclarator(lexemes);
	
	// TODO:
	// = DefaultInitializerExpression
	
	return assumeUnique(output);
}
