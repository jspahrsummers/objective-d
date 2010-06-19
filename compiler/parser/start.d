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
immutable(Lexeme[]) parseTopLevel (ref immutable(Lexeme)[] lexemes) {
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
			break;
		
		default:
			output ~= lexeme;
			lexemes = lexemes[1 .. $];
		}
	}
	
	return assumeUnique(output);
}
