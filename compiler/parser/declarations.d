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
import parser.expressions;
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

immutable(Lexeme[]) parseDeclDefs (ref immutable(Lexeme)[] lexemes) {
	immutable(Lexeme)[] output;

	if (lexemes[0].token != Token.LBrace)
		errorOut(lexemes[0], "expected {");
	
	output ~= lexemes[0];
	lexemes = lexemes[1 .. $];

	while (lexemes[0].token != Token.RBrace)
		output ~= parseDeclDef(lexemes);
	
	output ~= lexemes[0];
	lexemes = lexemes[1 .. $];
	
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
	
	case Token.ObjD_protocol:
		lexemes = lexemes[1 .. $];
		output ~= parseProtocol(lexemes);
		break;
	
	case Token.ObjD_category:
		lexemes = lexemes[1 .. $];
		output ~= parseCategory(lexemes);
		break;
	
	case Token.ObjD_objc:
		lexemes = lexemes[1 .. $];
		output ~= parseObjectiveCClass(lexemes);
		break;
	
	case Token.Tilde:
		if (lexemes[1].content == "this") {
			output ~= lexemes[0 .. 2];
			lexemes = lexemes[2 .. $];
			
			output ~= parseParameters(lexemes);
			output ~= parseFunctionBody(lexemes);
		}
		
		break;
	
	case Token.Identifier:
		switch (lexemes[0].content) {
		// TODO:
		// TemplateDeclaration
		// TemplateMixin
		
		case "this":
			output ~= lexemes[0];
			lexemes = lexemes[1 .. $];
			
			output ~= parseParameters(lexemes);
			output ~= parseFunctionBody(lexemes);
			break;
		
		case "invariant":
			if (lexemes[1].token != Token.LParen)
				errorOut(lexemes[1], "expected (");
			
			if (lexemes[2].token != Token.RParen)
				errorOut(lexemes[2], "expected )");
			
			output ~= parseBlockStatement(lexemes);
			break;
		
		case "enum":
			output ~= parseEnumDeclaration(lexemes);
			break;
		
		case "interface":
			output ~= parseInterfaceDeclaration(lexemes);
			break;
		
		case "struct":
		case "union":
			output ~= parseAggregateDeclaration(lexemes);
			break;
		
		case "pragma":
			if (lexemes[1].token != Token.LParen)
				errorOut(lexemes[1], "expected (");
			
			if (lexemes[2].token != Token.Identifier)
				errorOut(lexemes[2], "expected pragma name");
			
			output ~= lexemes[0 .. 3];
			lexemes = lexemes[3 .. $];
			
			if (lexemes[0].token == Token.Comma) {
				output ~= lexemes[0];
				lexemes = lexemes[1 .. $];
				
				output ~= parseArgumentList(lexemes);
			}
			
			if (lexemes[0].token != Token.RParen)
				errorOut(lexemes[0], "expected )");
			
			output ~= lexemes[0];
			lexemes = lexemes[1 .. $];
			
			if (lexemes[0].token == Token.Colon) {
				output ~= lexemes[0];
				lexemes = lexemes[1 .. $];
			} else
				output ~= parseDeclarationBlock(lexemes);
			
			break;
		
		case "extern":
			output ~= lexemes[0];
			lexemes = lexemes[1 .. $];
			
			if (lexemes[0].token == Token.LParen) {
				if (lexemes[1].token == Token.RParen)
					errorOut(lexemes[1], "expected linkage type");
			
				size_t pos = 2;
				while (lexemes[pos++].token != Token.RParen) {}
				
				output ~= lexemes[0 .. pos];
				lexemes = lexemes[pos .. $];
			}
			
			if (lexemes[0].token == Token.Colon) {
				output ~= lexemes[0];
				lexemes = lexemes[1 .. $];
			} else
				output ~= parseDeclarationBlock(lexemes);
			
			break;
		
		case "align":
			output ~= lexemes[0];
			
			if (lexemes[0].token == Token.LParen) {
				if (lexemes[1].token != Token.Number)
					errorOut(lexemes[1], "expected alignment integer");
				
				if (lexemes[2].token != Token.RParen)
					errorOut(lexemes[2], "expected )");
				
				output ~= lexemes[0 .. 3];
				lexemes = lexemes[3 .. $];
			}
			
			if (lexemes[0].token == Token.Colon) {
				output ~= lexemes[0];
				lexemes = lexemes[1 .. $];
			} else
				output ~= parseDeclarationBlock(lexemes);
			
			break;
		
		case "shared":
			if (lexemes[1].content == "static") {
				output ~= lexemes[0];
				lexemes = lexemes[1 .. $];
				goto case "static";
			}
			
		case "const":
		case "immutable":
			if (lexemes[1].token == Token.LParen)
				goto default;
		
		case "deprecated":
		case "private":
		case "package":
		case "protected":
		case "public":
		case "export":
		case "final":
		case "override":
		case "abstract":
		case "auto":
		case "scope":
		case "__gshared":
		case "inout":
		case "@disable":
			output ~= lexemes[0];
			lexemes = lexemes[1 .. $];
			
			if (lexemes[0].token == Token.Colon) {
				output ~= lexemes[0];
				lexemes = lexemes[1 .. $];
			} else
				output ~= parseDeclarationBlock(lexemes);
			
			break;
				
		case "else":
			output ~= lexemes[0];
			lexemes = lexemes[1 .. $];
			
			if (lexemes[0].content == "static") {
				output ~= lexemes[0];
				lexemes = lexemes[1 .. $];
				
				if (lexemes[0].content != "if")
					errorOut(lexemes[0], "expected \"if\"");
			}
			
			if (lexemes[0].content == "if") {
				if (lexemes[1].token != Token.LParen)
					errorOut(lexemes[1], "expected (");
					
				output ~= lexemes[0 .. 2];
				lexemes = lexemes[2 .. $];
				
				output ~= parseAssignExpression(lexemes);
				if (lexemes[0].token != Token.RParen)
					errorOut(lexemes[0], "expected )");
				
				output ~= lexemes[0];
				lexemes = lexemes[1 .. $];
			}
			
			output ~= parseDeclarationBlock(lexemes);
			break;
		
		case "version":
			output ~= lexemes[0];
			lexemes = lexemes[1 .. $];
			
			if (lexemes[0].token == Token.LParen) {
				if (lexemes[1].token != Token.Number && lexemes[1].token != Token.Identifier)
					errorOut(lexemes[1], "expected version number or identifier");
				
				if (lexemes[2].token != Token.RParen)
					errorOut(lexemes[2], "expected )");
				
				output ~= lexemes[0 .. 3];
				lexemes = lexemes[3 .. $];
				
				output ~= parseDeclarationBlock(lexemes);
			} else if (lexemes[0].token == Token.Assign) {
				if (lexemes[1].token != Token.Number && lexemes[1].token != Token.Identifier)
					errorOut(lexemes[1], "expected version number or identifier");
				
				if (lexemes[2].token != Token.Semicolon)
					errorOut(lexemes[2], "expected ;");
				
				output ~= lexemes[0 .. 3];
				lexemes = lexemes[3 .. $];
			} else
				errorOut(lexemes[0], "expected ( or =");
			
			break;
		
		case "debug":
			output ~= lexemes[0];
			lexemes = lexemes[1 .. $];
			
			output ~= parseDeclarationBlock(lexemes);
			break;
		
		case "static":
			output ~= lexemes[0];
			lexemes = lexemes[1 .. $];
			
			if (lexemes[0].content != "import") {
				switch (lexemes[0].content) {
				case "~":
					if (lexemes[1].content != "this")
						errorOut(lexemes[1], "expected \"this\" in destructor name");
					
					output ~= lexemes[0];
					lexemes = lexemes[1 .. $];
				
				case "this":
					output ~= lexemes[0];
					lexemes = lexemes[1 .. $];
					
					if (lexemes[0].token != Token.LParen)
						errorOut(lexemes[0], "expected (");
					
					if (lexemes[1].token != Token.RParen)
						errorOut(lexemes[1], "expected )");
					
					output ~= lexemes[0 .. 2];
					lexemes = lexemes[2 .. $];
					
					output ~= parseFunctionBody(lexemes);
					break;
				
				case "assert":
					if (lexemes[1].token != Token.LParen)
						errorOut(lexemes[1], "expected (");
						
					output ~= lexemes[0 .. 2];
					lexemes = lexemes[2 .. $];
					
					output ~= parseAssignExpression(lexemes);
					if (lexemes[0].token == Token.Comma) {
						output ~= lexemes[0];
						lexemes = lexemes[1 .. $];
						
						output ~= parseAssignExpression(lexemes);
					}
				
					if (lexemes[0].token != Token.RParen)
						errorOut(lexemes[0], "expected )");
					
					output ~= lexemes[0];
					lexemes = lexemes[1 .. $];
					break;
				
				case "if":
					if (lexemes[1].token != Token.LParen)
						errorOut(lexemes[1], "expected (");
						
					output ~= lexemes[0 .. 2];
					lexemes = lexemes[2 .. $];
					
					output ~= parseAssignExpression(lexemes);
					if (lexemes[0].token != Token.RParen)
						errorOut(lexemes[0], "expected )");
					
					output ~= lexemes[0];
					lexemes = lexemes[1 .. $];
					
					output ~= parseDeclarationBlock(lexemes);
					break;
				
				default:
					;
				}
				
				break;
			}
		
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
		
		case "class":
			output ~= parseClassDeclaration(lexemes);
			break;
		
		case "mixin":
			if (lexemes[1].token != Token.LParen)
				errorOut(lexemes[1], "expected (");
			
			output ~= lexemes[0 .. 2];
			lexemes = lexemes[2 .. $];
			
			// TODO: allow Objective-D string mixins?
			output ~= parseAssignExpression(lexemes);
			
			if (lexemes[0].token != Token.RParen)
				errorOut(lexemes[0], "expected )");
			
			if (lexemes[1].token != Token.Semicolon)
				errorOut(lexemes[1], "expected ;");
			
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

immutable(Lexeme[]) parseDeclarationBlock (ref immutable(Lexeme)[] lexemes) {
	immutable(Lexeme)[] output;
	
	if (lexemes[0].token == Token.LBrace) {
		output ~= lexemes[0];
		lexemes = lexemes[1 .. $];
		
		while (lexemes[0].token != Token.RBrace)
			output ~= parseDeclDef(lexemes);
		
		output ~= lexemes[0];
		lexemes = lexemes[1 .. $];
	} else
		output ~= parseDeclDef(lexemes);
	
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
		output ~= lexemes[0 .. 2];
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
	
		output ~= lexemes[0 .. 2];
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
	
	bool match = true;
	do {
		if (lexemes[0].token != Token.Identifier)
			errorOut(lexemes[0], "expected declaration");
		
		switch (lexemes[0].content) {
		case "const":
		case "immutable":
		case "shared":
			if (lexemes[1].token == Token.LParen) {
				match = false;
				break;
			}
		
		case "abstract":
		case "auto":
		case "deprecated":
		case "extern":
		case "final":
		case "inout":
		case "nothrow":
		case "override":
		case "pure":
		case "scope":
		case "static":
		case "synchronized":
			output ~= lexemes[0];
			lexemes = lexemes[1 .. $];
			break;
		
		default:
			match = false;
		}
	} while (match);
	
	// TODO:
	// AutoDeclaration
	
	output ~= parseBasicType(lexemes);
	output ~= parseDeclarators(lexemes);
	
	return assumeUnique(output);
}

immutable(Lexeme[]) parseClassDeclaration (ref immutable(Lexeme)[] lexemes) {
	immutable(Lexeme)[] output;
	
	if (lexemes[0].content != "class")
		errorOut(lexemes[0], "expected \"class\"");
	
	output ~= lexemes[0];
	lexemes = lexemes[1 .. $];
	
	if (lexemes[0].token != Token.Identifier)
		errorOut(lexemes[0], "expected class identifier");
	
	output ~= lexemes[0];
	lexemes = lexemes[1 .. $];
	
	// TODO:
	// ClassTemplateDeclaration
	
	output ~= parseBaseClassList(lexemes);
	output ~= parseDeclDefs(lexemes);
	
	return assumeUnique(output);
}

immutable(Lexeme[]) parseEnumDeclaration (ref immutable(Lexeme)[] lexemes) {
	immutable(Lexeme)[] output;
	
	if (lexemes[0].content != "enum")
		errorOut(lexemes[0], "expected \"enum\"");
	
	output ~= lexemes[0];
	lexemes = lexemes[1 .. $];
	
	if (lexemes[0].token == Token.Identifier) {
		output ~= lexemes[0];
		lexemes = lexemes[1 .. $];
	}
	
	if (lexemes[0].token == Token.Colon) {
		output ~= lexemes[0];
		lexemes = lexemes[1 .. $];
		
		output ~= parseDType(lexemes);
	}
	
	if (lexemes[0].token == Token.LBrace)
		output ~= parseEnumBody(lexemes);
	else if (lexemes[0].token != Token.Assign)
		errorOut(lexemes[0], "expected { or =");
	else {
		output ~= lexemes[0];
		lexemes = lexemes[1 .. $];
		
		output ~= parseAssignExpression(lexemes);
	
		if (lexemes[0].token != Token.Semicolon)
			errorOut(lexemes[0], "expected ;");
		
		output ~= lexemes[0];
		lexemes = lexemes[1 .. $];
	}
	
	return assumeUnique(output);
}

immutable(Lexeme[]) parseEnumBody (ref immutable(Lexeme)[] lexemes) {
	immutable(Lexeme)[] output;
	
	if (lexemes[0].token != Token.LBrace)
		errorOut(lexemes[0], "expected {");
	
	output ~= lexemes[0];
	lexemes = lexemes[1 .. $];
	
	for (;;) {
		output ~= parseEnumMember(lexemes);
		if (lexemes[0].token != Token.Comma)
			break;
		
		output ~= lexemes[0];
		lexemes = lexemes[1 .. $];
		if (lexemes[0].token == Token.RBrace)
			break;
	}
	
	if (lexemes[0].token != Token.RBrace)
		errorOut(lexemes[0], "expected }");
	
	output ~= lexemes[0];
	lexemes = lexemes[1 .. $];
	
	return assumeUnique(output);
}

immutable(Lexeme[]) parseEnumMember (ref immutable(Lexeme)[] lexemes) {
	immutable(Lexeme)[] output;
	
	auto save = lexemes;
	try {
		output ~= parseDType(lexemes);
	} catch (ParseException) {
		lexemes = save;
	}
	
	if (lexemes[0].token != Token.Identifier)
		errorOut(lexemes[0], "expected identifier");

	output ~= lexemes[0];
	lexemes = lexemes[1 .. $];
	
	if (lexemes[0].token == Token.Assign) {
		output ~= lexemes[0];
		lexemes = lexemes[1 .. $];
		
		output ~= parseAssignExpression(lexemes);
	}
	
	return assumeUnique(output);
}

immutable(Lexeme[]) parseInterfaceDeclaration (ref immutable(Lexeme)[] lexemes) {
	immutable(Lexeme)[] output;
	
	if (lexemes[0].content != "interface")
		errorOut(lexemes[0], "expected \"interface\"");
	
	output ~= lexemes[0];
	lexemes = lexemes[1 .. $];
	
	if (lexemes[0].token != Token.Identifier)
		errorOut(lexemes[0], "expected interface identifier");
	
	output ~= lexemes[0];
	lexemes = lexemes[1 .. $];
	
	// TODO:
	// InterfaceTemplateDeclaration
	
	output ~= parseBaseClassList(lexemes);
	output ~= parseDeclDefs(lexemes);
	
	return assumeUnique(output);
}

immutable(Lexeme[]) parseAggregateDeclaration (ref immutable(Lexeme)[] lexemes) {
	immutable(Lexeme)[] output;
	
	if (lexemes[0].content != "struct" && lexemes[0].content != "union")
		errorOut(lexemes[0], "expected \"struct\" or \"union\"");
	
	output ~= lexemes[0];
	lexemes = lexemes[1 .. $];
	
	if (lexemes[0].token != Token.Identifier)
		errorOut(lexemes[0], "expected identifier");
	
	output ~= lexemes[0];
	lexemes = lexemes[1 .. $];
	
	// TODO: StructTemplateDeclaration
	// TODO: UnionTemplateDeclaration
	
	if (lexemes[0].token == Token.Semicolon) {
		output ~= lexemes[0];
		lexemes = lexemes[1 .. $];
	} else {
		// TODO: StructBodyDeclaration
		output ~= parseDeclDefs(lexemes);
	}
	
	return assumeUnique(output);
}

immutable(Lexeme[]) parseBaseClassList (ref immutable(Lexeme)[] lexemes) {
	immutable(Lexeme)[] output;
	
	if (lexemes[0].token == Token.Colon) {
		output ~= lexemes[0];
		lexemes = lexemes[1 .. $];
		
		output ~= parseBaseClasses(lexemes);
	}
	
	return assumeUnique(output);
}

immutable(Lexeme[]) parseBaseClasses (ref immutable(Lexeme)[] lexemes) {
	immutable(Lexeme)[] output;
	
	if (lexemes[0].token == Token.Identifier) {
		switch (lexemes[0].content) {
		case "private":
		case "package":
		case "public":
		case "export":
			output ~= lexemes[0];
			lexemes = lexemes[1 .. $];
			break;
		
		default:
			;
		}
	}
	
	output ~= parsePrimaryExpression(lexemes);
	
	if (lexemes[0].token == Token.Comma) {
		output ~= lexemes[0];
		lexemes = lexemes[1 .. $];
		
		output ~= parseBaseClasses(lexemes);
	}
	
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
			output ~= lexemes[0];
			lexemes = lexemes[1 .. $];
			
			bool paren = false;
			if (lexemes[0].token == Token.LParen) {
				paren = true;
				output ~= lexemes[0];
				lexemes = lexemes[1 .. $];
			}
			
			output ~= parseDType(lexemes);
			
			if (paren) {
				if (lexemes[0].token != Token.RParen)
					errorOut(lexemes[0], "expected )");
					
				output ~= lexemes[0];
				lexemes = lexemes[1 .. $];
			}
			
			return assumeUnique(output);
			
		case "typeof":
			return parseTypeof(lexemes);
		
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
		output ~= lexemes[0];
		lexemes = lexemes[1 .. $];
		
		// TODO:
		// ArrayInitializer
		// StructInitializer
		output ~= parseAssignExpression(lexemes);
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
	
	output ~= parseBasicType2(lexemes);
	
	if (lexemes[0].token != Token.Identifier) {
		return assumeUnique(output);
	}
	
	output ~= lexemes[0];
	lexemes = lexemes[1 .. $];
	
	output ~= parseDeclaratorSuffixes(lexemes);
	return assumeUnique(output);
}

immutable(Lexeme[]) parseDeclaratorSuffixes (ref immutable(Lexeme)[] lexemes) {
	immutable(Lexeme)[] output;
	
	for (;;) {
		bool match = true;
		switch (lexemes[0].token) {
		// TODO:
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
		
		case Token.LBracket:
			output ~= lexemes[0];
			lexemes = lexemes[1 .. $];
			
			if (lexemes[0].token != Token.RBracket) {
				auto save = lexemes;
				try {
					output ~= parseAssignExpression(lexemes);
				} catch (ParseException) {
					output ~= parseDType(lexemes);
				}
			}
			
			if (lexemes[0].token != Token.RBracket)
				errorOut(lexemes[0], "expected ]");
				
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

immutable(Lexeme[]) parseParameters (ref immutable(Lexeme)[] lexemes) {
	immutable(Lexeme)[] output;
	
	if (lexemes[0].token != Token.LParen)
		errorOut(lexemes[0], "expected (");
	
	output ~= lexemes[0];
	lexemes = lexemes[1 .. $];
	
	if (lexemes[0].token != Token.RParen)
		output ~= parseParameterList(lexemes);
	
	if (lexemes[0].token != Token.RParen)
		errorOut(lexemes[0], "expected )");
	
	output ~= lexemes[0];
	lexemes = lexemes[1 .. $];
	
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
	
	if (lexemes[0].token == Token.Identifier) {
		switch (lexemes[0].content) {
		case "in":
		case "out":
		case "ref":
		case "lazy":
			output ~= lexemes[0];
			lexemes = lexemes[1 .. $];
			break;
		
		default:
			;
		}
	}
	
	output ~= parseBasicType(lexemes);
	if (lexemes[0].token != Token.Comma && lexemes[0].token != Token.RParen)
		output ~= parseDeclarator(lexemes);
	
	if (lexemes[0].token == Token.Assign) {
		output ~= lexemes[0];
		lexemes = lexemes[1 .. $];
		output ~= parseAssignExpression(lexemes);
	}
	
	return assumeUnique(output);
}

immutable(Lexeme[]) parseDType (ref immutable(Lexeme)[] lexemes) {
	immutable(Lexeme)[] output;
	
	output ~= parseBasicType(lexemes);
	output ~= parseDeclarator2(lexemes);
	
	return assumeUnique(output);
}

immutable(Lexeme[]) parseDeclarator2 (ref immutable(Lexeme)[] lexemes) {
	immutable(Lexeme)[] output;
	
	if (lexemes[0].token == Token.LParen) {
		output ~= lexemes[0];
		lexemes = lexemes[1 .. $];
		
		output ~= parseDeclarator2(lexemes);
		if (lexemes[0].token != Token.RParen)
			errorOut(lexemes[0], "expected )");
		
		output ~= lexemes[0];
		lexemes = lexemes[1 .. $];
		
		output ~= parseDeclaratorSuffixes(lexemes);
	} else if (lexemes[0].token == Token.Star || lexemes[0].token == Token.LBracket || lexemes[0].content == "delegate" || lexemes[0].content == "function") {
		output ~= parseBasicType2(lexemes);
		output ~= parseDeclarator2(lexemes);
	}
	
	return assumeUnique(output);
}

immutable(Lexeme[]) parseBasicType2 (ref immutable(Lexeme)[] lexemes) {
	immutable(Lexeme)[] output;
	
	switch (lexemes[0].token) {
	case Token.Star:
		output ~= lexemes[0];
		lexemes = lexemes[1 .. $];
		break;
		
	case Token.LBracket:
		output ~= lexemes[0];
		lexemes = lexemes[1 .. $];
		
		if (lexemes[0].token != Token.RBracket) {
			auto save = lexemes;
			try {
				output ~= parseAssignExpression(lexemes);
				if (lexemes[0].token == Token.Range) {
					output ~= lexemes[0];
					lexemes = lexemes[1 .. $];
					
					output ~= parseAssignExpression(lexemes);
				}
			} catch (ParseException) {
				output ~= parseDType(lexemes);
			}
		}
		
		if (lexemes[0].token != Token.RBracket)
			errorOut(lexemes[0], "expected ]");
		
		output ~= lexemes[0];
		lexemes = lexemes[1 .. $];
		break;
		
	case Token.Identifier:
		if (lexemes[0].content == "delegate" || lexemes[0].content == "function") {
			output ~= lexemes[0];
			lexemes = lexemes[1 .. $];
			
			output ~= parseParameters(lexemes);
			
			do {
				output ~= lexemes[0];
				lexemes = lexemes[1 .. $];
			} while (lexemes[0].content == "nothrow" || lexemes[0].content == "pure");
		}
		
		break;
	
	default:
		errorOut(lexemes[0], "expected declarator");
	}
	
	return assumeUnique(output);
}
