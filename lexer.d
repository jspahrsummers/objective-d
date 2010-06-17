import std.contracts;
import std.ctype;
import std.stdio;
import std.string;
import std.uni;
import exceptions;

enum Token {
	Unknown,
	
	/* Identifiers */
	Identifier,
	
	/* D keywords */
	DKeyword,
	
	/* Objective-D keywords (typically prefaced with an @) */
	ObjectiveDKeyword,
	
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
	BitwiseNot,
	
	// ~=
	BitwiseNotEq,
}

private enum SkipType {
	None,
	LineComment,
	NestedComment,
	BlockComment,
	String,
	WYSIWYGString,
	HexString,
	DelimitedString,
	TokenString,
	CharLiteral
}

private Token[dstring] tokenLookupTable;

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
		"~"d    : Token.BitwiseNot,
		"~="d   : Token.BitwiseNotEq
	];
	
	tokenLookupTable.rehash;
}

public Token tokenForString (dstring str) {
	// associative array lookup seems to be broken?
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
			// todo: make sure strings are escaped properly
			outFD.writef("`%s`", content);
			break;
		
		case Token.Character:
			// todo: make sure characters are escaped properly
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

immutable(Lexeme[]) lex (string file) {
	/* Initialize state variables */
	File inFD;
	try {
		inFD = File(file, "rt");
	} catch {
		stderr.writefln("Could not open file \"%s\" for reading.", file);
		return null;
	}
	
	scope(exit) inFD.detach();
	immutable(Lexeme)[] lexemes;
	
	dchar[] buffer;
	ulong line = 1;
	
	dstring current = "";
	Token currentToken;
	dchar lastChar;
	dchar closingDelimiter;
	dchar openingDelimiter;
	
	uint nesting = 0;
	SkipType skip;
	
	/* Helper nested functions */
	void errorOut(T...)(T args) {
		stderr.writef("%s:%s: ", file, line);
		stderr.writefln(args);
		throw new ParseException;
	}
	
	void createLexeme () {
		if (current != "") {
			assert(currentToken != Token.Unknown);
			
			lexemes ~= new Lexeme(currentToken, current.idup, file, line);
			currentToken = Token.Unknown;
		
			//writefln("created lexeme: %s", lexemes[$ - 1].description);
		}
		
		current.length = 0;
		skip = SkipType.None;
	}
	
	/* Parse loop */
	while (inFD.readln(buffer)) {
		dchar ch;
		for (size_t i = 0;i < buffer.length;++i, lastChar = ch) {
			ch = buffer[i];
			if (lastChar == '\n') {
				++line;
			}
			
			final switch (skip) {
			case SkipType.None:
				break;
			
			case SkipType.LineComment:
				if (ch == '\n')
					skip = SkipType.None;
				
				continue;
				
			case SkipType.NestedComment:
				if (lastChar == '+' && ch == '/') {
					if (--nesting == 0)
						skip = SkipType.None;
				}
				
				continue;
			
			case SkipType.BlockComment:
				if (lastChar == '*' && ch == '/') {
					skip = SkipType.None;
				}
				
				continue;
			
			case SkipType.String:
				if (lastChar != '\\' && ch == '"') {
					createLexeme();
					continue;
				} else if (ch == '\\' && lastChar == '\\') {
					// hide escaped backslashes to avoid parsing problems
					ch = '\0';
				}
				
				current ~= ch;
				continue;
			
			case SkipType.WYSIWYGString:
				if (ch == closingDelimiter) {
					createLexeme();
					continue;
				}
				
				current ~= ch;
				continue;
			
			case SkipType.HexString:
				if (ch == '"') {
					createLexeme();
					continue;
				}
				
				current ~= ch;
				continue;
			
			case SkipType.DelimitedString:
				if (openingDelimiter == '\0') {
					// set up delimiters
					openingDelimiter = ch;
					switch (openingDelimiter) {
					case '[':
						closingDelimiter = ']';
						break;
					case '(':
						closingDelimiter = ')';
						break;
					case '<':
						closingDelimiter = '>';
						break;
					case '{':
						closingDelimiter = '}';
						break;
					default:
						closingDelimiter = openingDelimiter;
					}
				}
				
				if (ch == openingDelimiter && openingDelimiter != closingDelimiter) {
					++nesting;
				} else if (lastChar == closingDelimiter) {
					if (closingDelimiter != openingDelimiter) {
						if (nesting == 0)
							errorOut("mismatched string delimiters %s and %s", openingDelimiter, closingDelimiter);
					
						--nesting;
					}
					
					if (ch == '"') {
						if (nesting != 0)
							errorOut("mismatched quotes and string delimiters %s and %s", openingDelimiter, closingDelimiter);
					
						createLexeme();
						continue;
					}
				}
				
				current ~= ch;
				continue;
			
			case SkipType.TokenString:
				if (ch == '{')
					++nesting;
				else if (ch == '}') {
					if (--nesting == 0) {
						createLexeme();
						continue;
					}
				}
				
				current ~= ch;
				continue;
			
			case SkipType.CharLiteral:
				if (lastChar != '\\' && ch == '\'') {
					createLexeme();
					continue;
				} else if (ch == '\\' && lastChar == '\\') {
					// hide escaped backslashes to avoid parsing problems
					ch = '\0';
				}
				
				current ~= ch;
				continue;
			}
			
			//writefln("%s:%s: %s", line, i, ch);
			
			switch (ch) {
			case '"':
				createLexeme();
				
				switch (lastChar) {
				case 'r':
					skip = SkipType.WYSIWYGString;
					break;
				case 'x':
					skip = SkipType.HexString;
					break;
				case 'q':
					skip = SkipType.DelimitedString;
					
					// don't know this yet
					openingDelimiter = '\0';
					
					break;
				default:
					skip = SkipType.String;
				}
				
				nesting = 1;
				currentToken = Token.String;
				continue;
			
			case '\'':
				createLexeme();
				skip = SkipType.CharLiteral;
				currentToken = Token.Character;
				continue;
			
			case '/':
				if (lastChar == '/') {
					// remove the previous forward slash from the token
					current = current[0 .. $ - 1];
					createLexeme();
					
					skip = SkipType.LineComment;
					continue;
				}
				
				break;
			
			case '*':
				if (lastChar == '/') {
					// remove the previous forward slash from the token
					current = current[0 .. $ - 1];
					createLexeme();
					
					skip = SkipType.BlockComment;
					continue;
				}
				
				break;
			
			case '+':
				if (lastChar == '/') {
					// remove the previous forward slash from the token
					current = current[0 .. $ - 1];
					createLexeme();
					
					skip = SkipType.NestedComment;
					nesting = 1;
					continue;
				}
				
				break;
			
			default:
				;
			}
			
			auto newContent = current ~ ch;
			auto symbolToken = tokenForString(current);
			auto token = tokenForString(newContent);
			
			if (token == Token.Unknown && symbolToken != Token.Unknown) {
				assert(symbolToken == currentToken);
			
				// adding this latest character would make an invalid token
				// we have now maximally munched
				createLexeme();
			}
			
			if (isspace(ch)) {
				// space always forcibly delimits lexemes
				createLexeme();
				continue;
			} else if (current.length == 0) {
				if (ch == '_' || isUniAlpha(ch))
					currentToken = Token.Identifier;
				else if (isdigit(ch))
					currentToken = Token.Number;
			} else if (currentToken == Token.Identifier) {
				if (ch != '_' && !isdigit(ch) && !isUniAlpha(ch))
					// looks like we're on to the next part of an expression
					createLexeme();
			}
			
			current ~= ch;
				
			// TODO: currently numbers will misbehave if followed by operators (with no whitespace)
			if (currentToken != Token.Identifier && currentToken != Token.Number) {
				currentToken = tokenForString(current);
			}
		}
	}
	
	return assumeUnique(lexemes);
}
