/*
 * lexemes.d
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

module parser.lexemes;
public import lexer;
import std.stdio;

package void LexemeDebug(string F = __FILE__, uint L = __LINE__) (immutable Lexeme lexeme) {
	debug {
		writefln("DEBUG: in %s:%s, lexeme %s", F, L, lexeme.description);
	}
}

package immutable(Lexeme) newToken (dstring content) {
	return new Lexeme(tokenForString(content), content);
}

package immutable(Lexeme) newIdentifier (dstring content) {
	return new Lexeme(Token.Identifier, content, null, 0);
}

package immutable(Lexeme) newString (dstring content) {
	return new Lexeme(Token.String, content, null, 0);
}

immutable struct Parameter {
public:
	immutable Lexeme[] type;
	dstring name;
	
	this (immutable Lexeme[] type, dstring name) {
		this.type = type;
		this.name = name;
	}
}

immutable class Method {
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
