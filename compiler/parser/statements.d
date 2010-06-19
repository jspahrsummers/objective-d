/*
 * statements.d
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

module parser.statements;
import exceptions;
import parser.expressions;
import parser.lexemes;
import parser.objd;
import std.contracts;

immutable(Lexeme[]) parseFunctionBody (ref immutable(Lexeme)[] lexemes) {
	immutable(Lexeme)[] output;
	
	if (lexemes[0].token == Token.Identifier) {
		switch (lexemes[0].content) {
		case "in":
			output ~= parseOutStatement(lexemes);
			if (lexemes[0].token == Token.Identifier && lexemes[0].content == "out")
				output ~= parseInStatement(lexemes);
			
			output ~= parseBodyStatement(lexemes);
			break;
			
		case "out":
			output ~= parseOutStatement(lexemes);
			if (lexemes[0].token == Token.Identifier && lexemes[0].content == "in")
				output ~= parseInStatement(lexemes);
			
			output ~= parseBodyStatement(lexemes);
			break;
			
		case "body":
			output ~= parseBodyStatement(lexemes);
			break;
			
		default:
			errorOut(lexemes[0], "expected block statement");
		}
	} else {
		output ~= parseBlockStatement(lexemes);
	}
	
	return assumeUnique(output);
}

immutable(Lexeme[]) parseBodyStatement (ref immutable(Lexeme)[] lexemes) {
	immutable(Lexeme)[] output;
	
	if (lexemes[0].content != "body")
		errorOut(lexemes[0], "expected \"body\"");

	output ~= lexemes[0];
	lexemes = lexemes[1 .. $];
	output ~= parseBlockStatement(lexemes);
	
	return assumeUnique(output);
}

immutable(Lexeme[]) parseInStatement (ref immutable(Lexeme)[] lexemes) {
	immutable(Lexeme)[] output;
	
	if (lexemes[0].content != "in")
		errorOut(lexemes[0], "expected \"in\"");

	output ~= lexemes[0];
	lexemes = lexemes[1 .. $];
	output ~= parseBlockStatement(lexemes);
	
	return assumeUnique(output);
}

immutable(Lexeme[]) parseOutStatement (ref immutable(Lexeme)[] lexemes) {
	immutable(Lexeme)[] output;
	
	if (lexemes[0].content != "out")
		errorOut(lexemes[0], "expected \"out\"");

	output ~= lexemes[0];
	lexemes = lexemes[1 .. $];
	
	if (lexemes[0].token == Token.LParen) {
		if (lexemes[1].token != Token.Identifier)
			errorOut(lexemes[1], "expected identifier");
		
		if (lexemes[2].token != Token.RParen)
			errorOut(lexemes[2], "expected )");

		output ~= lexemes[0 .. 2];
		lexemes = lexemes[3 .. $];
	}
	
	output ~= parseBlockStatement(lexemes);
	
	return assumeUnique(output);
}

immutable(Lexeme[]) parseBlockStatement (ref immutable(Lexeme)[] lexemes) {
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
