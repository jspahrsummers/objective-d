/*
 * lexer.d
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
import std.ctype;
import std.stdio;
import std.string;
import std.traits;
import std.uni;
import exceptions;

enum Token {
	Unknown,
	
	/* Identifiers and D keywords */
	Identifier,
	
	/* Objective-D keywords (prefixed with an @) */
	ObjD_category,
	ObjD_class,
	ObjD_end,
	ObjD_objc,
	ObjD_optional,
	ObjD_protocol,
	ObjD_required,
	ObjD_selector,
	
	/* Literals */
	String,
	Character,
	Number,
	
	/* Symbols */
	// @
	At,
	
	// /
	Slash,
	
	// /=
	DivEq,
	
	// .
	Dot,
	
	// ..
	Range,
	
	// ...
	Ellipsis,
	
	// &
	BitwiseAnd,
	
	// &=
	AndEq,
	
	// &&
	LogicalAnd,
	
	// |
	BitwiseOr,
	
	// |=
	OrEq,
	
	// ||
	LogicalOr,
	
	// -
	Minus,
	
	// -=
	MinusEq,
	
	// --
	Decrement,
	
	// +
	Plus,
	
	// +=
	PlusEq,
	
	// ++
	Increment,
	
	// <
	Less,
	
	// <=
	LessEq,
	
	// <<
	ShiftLeft,
	
	// <<=
	ShiftLeftEq,
	
	// <>
	LessGreater,
	
	// <>=
	LessGreaterEq,
	
	// >
	Greater,
	
	// >=
	GreaterEq,
	
	// >>=
	ShiftRightEq,
	
	// >>>=
	UnsignedShiftRightEq,
	
	// >>
	ShiftRight,
	
	// >>>
	UnsignedShiftRight,
	
	// !
	Exclamation,
	
	// !=
	NotEq,
	
	// !<>
	NotLessGreater,
	
	// !<>=
	NotLessGreaterEq,
	
	// !<
	NotLess,
	
	// !<=
	NotLessEq,
	
	// !>
	NotGreater,
	
	// !>=
	NotGreaterEq,
	
	// (
	LParen,
	
	// )
	RParen,
	
	// [
	LBracket,
	
	// ]
	RBracket,
	
	// {
	LBrace,
	
	// }
	RBrace,
	
	// ?
	Question,
	
	// ,
	Comma,
	
	// ;
	Semicolon,
	
	// :
	Colon,
	
	// $
	Dollar,
	
	// =
	Assign,
	
	// ==
	Eq,
	
	// *
	Star,
	
	// *=
	MulEq,
	
	// %
	Mod,
	
	// %=
	ModEq,
	
	// ^
	Xor,
	
	// ^=
	XorEq,
	
	// ^^
	Pow,
	
	// ^^=
	PowEq,
	
	// ~
	Tilde,
	
	// ~=
	TildeEq,
}

private Token[dstring] tokenLookupTable;
private Token[dstring] objectiveDKeywordTable;

static this () {
	tokenLookupTable = [
		"@"d    : Token.At,
		"/"d    : Token.Slash,
		"/="d   : Token.DivEq,
		"."d    : Token.Dot,
		".."d   : Token.Range,
		"..."d  : Token.Ellipsis,
		"&"d    : Token.BitwiseAnd,
		"&="d   : Token.AndEq,
		"&&"d   : Token.LogicalAnd,
		"|"d    : Token.BitwiseOr,
		"|="d   : Token.OrEq,
		"||"d   : Token.LogicalOr,
		"-"d    : Token.Minus,
		"-="d   : Token.MinusEq,
		"--"d   : Token.Decrement,
		"+"d    : Token.Plus,
		"+="d   : Token.PlusEq,
		"++"d   : Token.Increment,
		"<"d    : Token.Less,
		"<="d   : Token.LessEq,
		"<<"d   : Token.ShiftLeft,
		"<<="d  : Token.ShiftLeftEq,
		"<>"d   : Token.LessGreater,
		"<>="d  : Token.LessGreaterEq,
		">"d    : Token.Greater,
		">="d   : Token.GreaterEq,
		">>="d  : Token.ShiftRightEq,
		">>>="d : Token.UnsignedShiftRightEq,
		">>"d   : Token.ShiftRight,
		">>>"d  : Token.UnsignedShiftRight,
		"!"d    : Token.Exclamation,
		"!="d   : Token.NotEq,
		"!<>"d  : Token.NotLessGreater,
		"!<>="d : Token.NotLessGreaterEq,
		"!<"d   : Token.NotLess,
		"!<="d  : Token.NotLessEq,
		"!>"d   : Token.NotGreater,
		"!>="d  : Token.NotGreaterEq,
		"("d    : Token.LParen,
		")"d    : Token.RParen,
		"["d    : Token.LBracket,
		"]"d    : Token.RBracket,
		"{"d    : Token.LBrace,
		"}"d    : Token.RBrace,
		"?"d    : Token.Question,
		","d    : Token.Comma,
		";"d    : Token.Semicolon,
		":"d    : Token.Colon,
		"$"d    : Token.Dollar,
		"="d    : Token.Assign,
		"=="d   : Token.Eq,
		"*"d    : Token.Star,
		"*="d   : Token.MulEq,
		"%"d    : Token.Mod,
		"%="d   : Token.ModEq,
		"^"d    : Token.Xor,
		"^="d   : Token.XorEq,
		"^^"d   : Token.Pow,
		"^^="d  : Token.PowEq,
		"~"d    : Token.Tilde,
		"~="d   : Token.TildeEq
	];
	
	tokenLookupTable.rehash;
	
	// all of these should be considered prefixed with @
	objectiveDKeywordTable = [
		"category" : Token.ObjD_category,
		"class"    : Token.ObjD_class,
		"end"      : Token.ObjD_end,
		"objc"     : Token.ObjD_objc,
		"optional" : Token.ObjD_optional,
		"protocol" : Token.ObjD_protocol,
		"required" : Token.ObjD_required,
		"selector" : Token.ObjD_selector
	];
	
	objectiveDKeywordTable.rehash;
}

public Token tokenForString (dstring str) {
	// associative array lookup seems to be broken
	//auto tok = str in tokenLookupTable;
	//if (tok == null)
	//	return Token.Unknown;
	//else
	//	return *tok;
	
	auto tok = Token.Unknown;
	foreach (strk, tokv; tokenLookupTable) {
		if (strk == str) {
			tok = tokv;
			break;
		}
	}
	
	return tok;
}

immutable class Lexeme {
public:
	Token token;
	dstring content;
	string file;
	ulong line;
	
	this (Token token, dstring content, string file = null, ulong line = 0)
	in {
		assert(content !is null);
	} body {
		this.token = token;
		this.content = content;
		this.file = file;
		this.line = line;
	}
	
	void writeToFile (ref File outFD) const {
		assert(content !is null);
		
		switch (token) {
		case Token.At:
			// don't put a space after @s
			outFD.write('@');
			break;
		
		case Token.String:
			// strings have their own implementation of writeToFile()
			// should never get here
			assert(0);
		
		case Token.Character:
			outFD.writef("'%s'", content);
			break;
			
		default:
			outFD.write(content, ' ');
		}
	}
	
	bool opEquals (in Object other) const {
		auto lexeme = cast(typeof(this))other;
		if (lexeme is null)
			return false;
		
		return this.token == lexeme.token && this.content == lexeme.content;
	}
	
	// for debugging purposes only
	@property string description () const {
		return format("%s:%s: %s = %s", file, line, token, content);
	}
}

abstract class StringLexeme : Lexeme {
public:
	dchar postfix;
	
	this (dstring content, dchar postfix = 'c', string file = null, ulong line = 0)
	in {
		assert(postfix == 'c' || postfix == 'w' || postfix == 'd');
	} body {
		super(Token.String, content, file, line);
		this.postfix = postfix;
	}
}

immutable class BacktickStringLexeme : StringLexeme {
public:
	this (ParameterTypeTuple!(super.__ctor) args) {
		super(args);
	}
	
	override void writeToFile (ref File outFD) const {
		assert(content !is null);
		outFD.writef("`%s`", content);
	}
}

immutable class WysiwygStringLexeme : StringLexeme {
public:
	this (ParameterTypeTuple!(super.__ctor) args) {
		super(args);
	}
	
	override void writeToFile (ref File outFD) const {
		assert(content !is null);
		outFD.writef("r\"%s\"", content);
	}
}

immutable class DoubleQuotedStringLexeme : StringLexeme {
public:
	this (ParameterTypeTuple!(super.__ctor) args) {
		super(args);
	}
	
	override void writeToFile (ref File outFD) const {
		assert(content !is null);
		outFD.writef("\"%s\"", content);
	}
}

immutable class HexStringLexeme : StringLexeme {
public:
	this (ParameterTypeTuple!(super.__ctor) args) {
		super(args);
	}
	
	override void writeToFile (ref File outFD) const {
		assert(content !is null);
		outFD.writef("x\"%s\"", content);
	}
}

immutable class DelimitedStringLexeme : StringLexeme {
public:
	dstring openingDelimiter;
	dstring closingDelimiter;
	
	this (dstring content, dstring openingDelimiter, dstring closingDelimiter, dchar postfix = 'c', string file = null, ulong line = 0)
	in {
		assert(openingDelimiter !is null && openingDelimiter.length > 0);
		assert(closingDelimiter !is null && closingDelimiter.length > 0);
	} body {
		super(content, postfix, file, line);
		this.openingDelimiter = openingDelimiter;
		this.closingDelimiter = closingDelimiter;
	}
	
	override void writeToFile (ref File outFD) const {
		assert(content !is null);
		outFD.writef("q\"%s%s%s\"", openingDelimiter, content, closingDelimiter);
	}
}

immutable class TokenStringLexeme : StringLexeme {
public:
	this (dstring content, string file = null, ulong line = 0) {
		// token strings shouldn't have postfixes
		super(content, ' ', file, line);
	}
	
	override void writeToFile (ref File outFD) const {
		assert(content !is null);
		outFD.writef("q{%s}", content);
	}
}

immutable(Lexeme[]) lex (string file) {
	/* Initialize state variables */
	File* inFD;
	try {
		inFD = new File(file, "rt");
	} catch {
		stderr.writefln("Could not open file \"%s\" for reading.", file);
		return null;
	}
	
	scope(exit) inFD.detach();
	immutable(Lexeme)[] lexemes;
	
	dchar[] buffer;
	ulong line = 1;
	
	auto current = Appender!(dstring)();
	Token currentToken;
	dchar lastChar = '\0';
	
	/* Helper nested functions */
	void createLexeme () {
		if (lastChar != '\0') {
			current.put(lastChar);
			lastChar = '\0';
		}
		
		if (current.data.length > 0) {
			assert(currentToken != Token.Unknown);
			
			lexemes ~= new Lexeme(currentToken, current.data.idup, file, line);
			currentToken = Token.Unknown;
		
			//writefln("created lexeme: %s", lexemes[$ - 1].description);
		}
		
		current.clear();
	}
	
	dstring getMore (out string f, out ulong l) {
		f = file;
		if (inFD.readln(buffer)) {
			l = ++line;
			return assumeUnique(buffer);
		} else
			return null;
	}
	
	/* Parse loop */
	string dummyFile;
	ulong dummyLine;
	dstring str;
	while ((str = getMore(dummyFile, dummyLine)) !is null) {
		assert(dummyFile == file);
		assert(dummyLine == line);
		
		dstring getMoreUsingStr (out string f, out ulong l) {
			if (str !is null) {
				f = file;
				l = line;
				
				auto ret = str;
				str = null;
				return ret;
			} else
				return getMore(f, l);
		}
	
	lexLooper:
		while (str.length > 0) {
			auto ch = str[0];
		
			switch (ch) {
			case '"':
				str = str[1 .. $];
				switch (lastChar) {
				case 'r':
					lastChar = '\0';
					createLexeme();
					
					dstring move;
					lexemes ~= lexWysiwygString(&getMoreUsingStr, move);
					str = move;
					break;
					
				case 'x':
					lastChar = '\0';
					createLexeme();
					
					dstring move;
					lexemes ~= lexHexString(&getMoreUsingStr, move);
					str = move;
					break;
					
				case 'q':
					lastChar = '\0';
					createLexeme();
					
					dstring move;
					lexemes ~= lexDelimitedString(&getMoreUsingStr, move);
					str = move;
					break;
					
				default:
					createLexeme();
					
					dstring move;
					lexemes ~= lexDoubleQuotedString(&getMoreUsingStr, move);
					str = move;
				}
				
				goto lexLooper;
			
			case '\'':
				createLexeme();
				str = str[1 .. $];
					
				dstring move;
				lexemes ~= lexCharLiteral(&getMoreUsingStr, move);
				str = move;
				
				goto lexLooper;
			
			case '/':
				if (lastChar == '/') {
					lastChar = '\0';
					createLexeme();
					str = str[1 .. $];
					
					dstring move;
					lexLineComment(&getMoreUsingStr, move);
					str = move;
					
					assert(str.length == 0);
					goto lexLooper;
				}
				
				break;
			
			case '*':
				if (lastChar == '/') {
					lastChar = '\0';
					createLexeme();
					str = str[1 .. $];
					
					dstring move;
					lexBlockComment(&getMoreUsingStr, move);
					str = move;
					
					goto lexLooper;
				}
				
				break;
			
			case '+':
				if (lastChar == '/') {
					lastChar = '\0';
					createLexeme();
					str = str[1 .. $];
					
					dstring move;
					lexNestedComment(&getMoreUsingStr, str);
					str = move;
					
					goto lexLooper;
				}
				
				break;
			
			default:
				;
			}
			
			if (lastChar != '\0') {
				current.put(lastChar);
				lastChar = '\0';
			}
			
			if (isspace(ch)) {
				// space always forcibly delimits lexemes
				createLexeme();
				str = str[1 .. $];
				continue lexLooper;
			}
			
			auto newContent = current.data ~ ch;
			currentToken = tokenForString(current.data);
			auto token = tokenForString(newContent);
			
			if (token == Token.Unknown && currentToken != Token.Unknown) {
				// adding this latest character would make an invalid token
				// we have now maximally munched
				createLexeme();
				currentToken = tokenForString([ ch ]);
			}
			
			if (current.data.length == 0) {
				if (ch == '_' || isUniAlpha(ch)) {
					lexemes ~= lexIdentifier(str, file, line);
					goto lexLooper;
				} else if (isdigit(ch)) {
					lexemes ~= lexNumberLiteral(str, file, line);
					goto lexLooper;
				} else
					currentToken = tokenForString([ ch ]);
			}
			
			lastChar = ch;
			str = str[1 .. $];
		}
	}
	
	return keywordify(assumeUnique(lexemes));
}

void lexLineComment (dstring delegate (out string, out ulong) getMore, out dstring left) {
	dstring str;
	string file;
	ulong line;
	
	while ((str = getMore(file, line)) !is null) {
		foreach (i, ch; str) {
			if (ch == '\n') {
				left = str[i + 1 .. $];
				return;
			}
		}
	}
	
	left = null;
}

void lexBlockComment (dstring delegate (out string, out ulong) getMore, out dstring left) {
	dstring str;
	string file;
	ulong line;
	
	dchar lastChar;
	while ((str = getMore(file, line)) !is null) {
		foreach (i, ch; str) {
			if (ch == '/' && lastChar == '*') {
				left = str[i + 1 .. $];
				return;
			}
			
			lastChar = ch;
		}
	}
	
	errorOut(file, line, "expected */ before end of file");
}

void lexNestedComment (dstring delegate (out string, out ulong) getMore, out dstring left) {
	dstring str;
	string file;
	ulong line;
	
	dchar lastChar;
	while ((str = getMore(file, line)) !is null) {
		foreach (i, ch; str) {
			if (ch == '/' && lastChar == '+') {
				left = str[i + 1 .. $];
				return;
			} else if (ch == '+' && lastChar == '/') {
				str = str[i + 1 .. $];
				lexBlockComment((out string f, out ulong l){
					if (str !is null) {
						auto ret = str;
						str = null;
						
						f = file;
						l = line;
						return ret;
					} else
						return getMore(f, l);
				}, left);
				
				return;
			}
			
			lastChar = ch;
		}
	}
	
	errorOut(file, line, "expected +/ before end of file");
}

immutable(StringLexeme) lexWysiwygString (dstring delegate (out string, out ulong) getMore, out dstring left) {
	dstring str;
	string file;
	ulong line;
	
	dchar lastChar;
	auto content = Appender!(dstring)();
	while ((str = getMore(file, line)) !is null) {
		foreach (i, ch; str) {
			if (ch == '"' && lastChar != '\\') {
				str = str[i + 1 .. $];
				
				dchar postfix = 'c';
				if (str.length > 0 && (str[0] == 'c' || str[0] == 'w' || str[0] == 'd')) {
					postfix = str[0];
					left = str[1 .. $];
				} else
					left = str;
				
				return new WysiwygStringLexeme(content.data.idup, postfix, file, line);
			}
			
			lastChar = ch;
			content.put(ch);
		}
	}
	
	errorOut(file, line, "expected closing \" for WYSIWYG string before end of file");
	assert(0);
}

immutable(StringLexeme) lexBacktickString (dstring delegate (out string, out ulong) getMore, out dstring left) {
	dstring str;
	string file;
	ulong line;
	
	auto content = Appender!(dstring)();
	while ((str = getMore(file, line)) !is null) {
		foreach (i, ch; str) {
			if (ch == '`') {
				str = str[i + 1 .. $];
				
				dchar postfix = 'c';
				if (str.length > 0 && (str[0] == 'c' || str[0] == 'w' || str[0] == 'd')) {
					postfix = str[0];
					left = str[1 .. $];
				} else
					left = str;
				
				return new BacktickStringLexeme(content.data.idup, postfix, file, line);
			}
			
			content.put(ch);
		}
	}
	
	errorOut(file, line, "expected closing ` for WYSIWYG string before end of file");
	assert(0);
}

immutable(StringLexeme) lexDoubleQuotedString (dstring delegate (out string, out ulong) getMore, out dstring left) {
	dstring str;
	string file;
	ulong line;
	
	dchar lastChar;
	auto content = Appender!(dstring)();
	while ((str = getMore(file, line)) !is null) {
		foreach (i, ch; str) {
			if (ch == '"' && lastChar != '\\') {
				str = str[i + 1 .. $];
				
				dchar postfix = 'c';
				if (str.length > 0 && (str[0] == 'c' || str[0] == 'w' || str[0] == 'd')) {
					postfix = str[0];
					left = str[1 .. $];
				} else
					left = str;
				
				return new DoubleQuotedStringLexeme(content.data.idup, postfix, file, line);
			}
			
			lastChar = ch;
			content.put(ch);
		}
	}
	
	errorOut(file, line, "expected closing \" for WYSIWYG string before end of file");
	assert(0);
}

immutable(StringLexeme) lexHexString (dstring delegate (out string, out ulong) getMore, out dstring left) {
	dstring str;
	string file;
	ulong line;
	
	dchar lastChar;
	auto content = Appender!(dstring)();
	while ((str = getMore(file, line)) !is null) {
		foreach (i, ch; str) {
			if (ch == '"' && lastChar != '\\') {
				str = str[i + 1 .. $];
				
				dchar postfix = 'c';
				if (str.length > 0 && (str[0] == 'c' || str[0] == 'w' || str[0] == 'd')) {
					postfix = str[0];
					left = str[1 .. $];
				} else
					left = str;
				
				return new HexStringLexeme(content.data.idup, postfix, file, line);
			}
			
			lastChar = ch;
			content.put(ch);
		}
	}
	
	errorOut(file, line, "expected closing \" for WYSIWYG string before end of file");
	assert(0);
}

immutable(StringLexeme) lexDelimitedString (dstring delegate (out string, out ulong) getMore, out dstring left) {
	dstring str;
	string file;
	ulong line;
	
	auto openingDelimiter = Appender!(dstring)();
	dstring closingDelimiter;
	uint nesting = 0;
	
	auto content = Appender!(dstring)();
	
delimiterLoop:
	while ((str = getMore(file, line)) !is null) {
		foreach (i, ch; str) {
			if (openingDelimiter.data.length > 0) {
				if (ch == '\n') {
					content.put(ch);
					
					closingDelimiter = openingDelimiter.data.idup;
					break delimiterLoop;
				} else if (ch != '_' && !isdigit(ch) && !isUniAlpha(ch))
					errorOut(file, line, "invalid character %s in string delimiter", ch);
				
				openingDelimiter.put(ch);
			} else if (ch == '_' || isUniAlpha(ch)) {
				openingDelimiter.put(ch);
			} else {
				openingDelimiter.put(ch);
				
				switch (ch) {
				case '(':
					nesting = 1;
					closingDelimiter = ")";
					break;
					
				case '[':
					nesting = 1;
					closingDelimiter = "]";
					break;
					
				case '<':
					nesting = 1;
					closingDelimiter = ">";
					break;
					
				case '{':
					nesting = 1;
					closingDelimiter = "}";
					break;
					
				default:
					closingDelimiter = openingDelimiter.data.idup;
				}
				
				break delimiterLoop;
			}
		}
	}
	
	// for simplicity in checking
	closingDelimiter ~= "\"";
	
	if (str.length == 0)
		str = getMore(file, line);
	
stringLoop:
	while (str !is null) {
		foreach (i, ch; str) {
			if (str.length - i < closingDelimiter.length)
				break stringLoop;
			
			if (nesting <= 1 && str[i .. closingDelimiter.length] == closingDelimiter) {
				str = str[i + closingDelimiter.length .. $];
				
				dchar postfix = 'c';
				if (str.length > 0 && (str[0] == 'c' || str[0] == 'w' || str[0] == 'd')) {
					postfix = str[0];
					left = str[1 .. $];
				} else
					left = str;
				
				return new DelimitedStringLexeme(content.data.idup, openingDelimiter.data.idup, closingDelimiter[0 .. $ - 1], postfix, file, line);
			} else if (nesting >= 1 && ch == openingDelimiter.data[0])
				++nesting;
			
			content.put(ch);
		}
		
		str = getMore(file, line);
	}
	
	errorOut(file, line, "expected closing %s\" for delimited string before end of file", closingDelimiter);
	assert(0);
}

immutable(StringLexeme) lexTokenString (dstring delegate (out string, out ulong) getMore, out dstring left) {
	dstring str;
	string file;
	ulong line;
	
	auto content = Appender!(dstring)();
	uint nesting = 1;
	while ((str = getMore(file, line)) !is null) {
		foreach (i, ch; str) {
			if (ch == '}') {
				if (--nesting == 0) {
					left = str[i + 1 .. $];
					return new TokenStringLexeme(content.data.idup, file, line);
				}
			} else if (ch == '{')
				++nesting;
			
			content.put(ch);
		}
	}
	
	errorOut(file, line, "expected closing } for token string before end of file");
	assert(0);
}

immutable(Lexeme) lexCharLiteral (dstring delegate (out string, out ulong) getMore, out dstring left) {
	dstring str;
	string file;
	ulong line;
	
	dchar lastChar;
	auto content = Appender!(dstring)();
	while ((str = getMore(file, line)) !is null) {
		foreach (i, ch; str) {
			if (ch == '\'' && lastChar != '\\') {
				left = str[i + 1 .. $];
				return new Lexeme(Token.Character, content.data.idup, file, line);
			}
			
			lastChar = ch;
			content.put(ch);
		}
	}
	
	errorOut(file, line, "expected closing ' for character literal before end of file");
	assert(0);
}

immutable(Lexeme) lexIdentifier (ref dstring str, string file, ulong line) {
	assert(str[0] == '_' || isUniAlpha(str[0]));
	
	auto content = Appender!(dstring)();
	while (str.length > 0) {
		auto ch = str[0];
		if (ch != '_' && !isdigit(ch) && !isUniAlpha(ch))
			break;
		
		content.put(ch);
		str = str[1 .. $];
	}
	
	return new Lexeme(Token.Identifier, content.data.idup, file, line);
}

immutable(Lexeme) lexNumberLiteral (ref dstring str, string file, ulong line) {
	assert(isdigit(str[0]));
	
	dchar lastChar;
	auto content = Appender!(dstring)();

stringLoop:
	while (str.length > 0) {
		auto ch = str[0];
		switch (ch) {
		case 'x':
		case 'X':
			break;
		
		case 'l':
		case 'L':
		case 'i':
		case 'p':
		case 'P':
		case 'u':
		case 'U':
		case '.':
		case '_':
			break;
		
		case '+':
		case '-':
			if (lastChar != 'e' && lastChar != 'E' && lastChar != 'p' && lastChar != 'P')
				break stringLoop;
			
			break;
		
		default:
			if (!isxdigit(ch))
				break stringLoop;
		}
		
		content.put(ch);
		lastChar = ch;
		str = str[1 .. $];
	}
	
	return new Lexeme(Token.Number, content.data.idup, file, line);
}

immutable(Lexeme[]) keywordify (immutable Lexeme[] lexemes) {
	immutable(Lexeme)[] output;

	for (size_t i = 0;i < lexemes.length;++i) {
		auto lexeme = lexemes[i];
		switch (lexeme.token) {
		case Token.At:
			// check for Objective-D keywords
			if (i + 1 < lexemes.length && lexemes[i + 1].token == Token.Identifier) {
				auto ident = lexemes[i + 1].content;
				bool found = false;
				foreach (str, tok; objectiveDKeywordTable) {
					if (str == ident) {
						output ~= new Lexeme(tok, "@" ~ str, lexeme.file, lexeme.line);
						found = true;
						break;
					}
				}
				
				if (found) {
					// skip over the keyword just processed
					++i;
					
					// already added a lexeme to the stream
					break;
				}
			}
			
			goto default;
			
		default:
			output ~= lexeme;
		}
	}
	
	return assumeUnique(output);
}
