import std.contracts;
import std.ctype;
import std.stdio;
import std.string;
import std.uni;
import exceptions;

enum Token {
	Unknown,
	
	/* Identifiers and D keywords */
	Identifier,
	
	/+
	/* D keywords */
	D_abstract		 ,
	D_alias			 ,
	D_align			 ,
	D_asm			 ,
	D_assert		 ,
	D_auto			 ,
	D_body			 ,
	D_bool			 ,
	D_break			 ,
	D_byte			 ,
	D_case			 ,
	D_cast			 ,
	D_catch			 ,
	D_cdouble		 ,
	D_cent			 ,
	D_cfloat		 ,
	D_char			 ,
	D_class			 ,
	D_const			 ,
	D_continue		 ,
	D_creal			 ,
	D_dchar			 ,
	D_debug			 ,
	D_default		 ,
	D_delegate		 ,
	D_delete		 ,
	D_deprecated	 ,
	D_do			 ,
	D_double		 ,
	D_else			 ,
	D_enum			 ,
	D_export		 ,
	D_extern		 ,
	D_false			 ,
	D_final			 ,
	D_finally		 ,
	D_float			 ,
	D_for			 ,
	D_foreach		 ,
	D_foreach_reverse,
	D_function		 ,
	D_goto			 ,
	D_idouble		 ,
	D_if			 ,
	D_ifloat		 ,
	D_immutable		 ,
	D_import		 ,
	D_in			 ,
	D_inout			 ,
	D_int			 ,
	D_interface		 ,
	D_invariant		 ,
	D_ireal			 ,
	D_is			 ,
	D_lazy			 ,
	D_long			 ,
	D_macro			 ,
	D_mixin			 ,
	D_module		 ,
	D_new			 ,
	D_nothrow		 ,
	D_null			 ,
	D_out			 ,
	D_override		 ,
	D_package		 ,
	D_pragma		 ,
	D_private		 ,
	D_protected		 ,
	D_public		 ,
	D_pure			 ,
	D_real			 ,
	D_ref			 ,
	D_return		 ,
	D_scope			 ,
	D_shared		 ,
	D_short			 ,
	D_static		 ,
	D_struct		 ,
	D_super			 ,
	D_switch		 ,
	D_synchronized	 ,
	D_template		 ,
	D_this			 ,
	D_throw			 ,
	D_true			 ,
	D_try			 ,
	D_typedef		 ,
	D_typeid		 ,
	D_typeof		 ,
	D_ubyte			 ,
	D_ucent			 ,
	D_uint			 ,
	D_ulong			 ,
	D_union			 ,
	D_unittest		 ,
	D_ushort		 ,
	D_version		 ,
	D_void			 ,
	D_volatile		 ,
	D_wchar			 ,
	D_while			 ,
	D_with			 ,
	D___FILE__		 ,
	D___LINE__		 ,
	D___gshared		 ,
	D___thread		 ,
	D___traits		 ,
	+/
	
	/* Objective-D keywords (prefixed with an @) */
	ObjD_class,
	ObjD_selector,
	ObjD_objc,
	ObjD_end,
	ObjD_protocol,
	ObjD_optional,
	ObjD_required,
	
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
//private Token[dstring] dKeywordTable;
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
		"~"d    : Token.BitwiseNot,
		"~="d   : Token.BitwiseNotEq
	];
	
	tokenLookupTable.rehash;
	
	/+
	dKeywordTable = [
		"abstract" : Token.D_abstract,
		"alias" : Token.D_alias,
		"align" : Token.D_align,
		"asm" : Token.D_asm,
		"assert" : Token.D_assert,
		"auto" : Token.D_auto,
		"body" : Token.D_body,
		"bool" : Token.D_bool,
		"break" : Token.D_break,
		"byte" : Token.D_byte,
		"case" : Token.D_case,
		"cast" : Token.D_cast,
		"catch" : Token.D_catch,
		"cdouble" : Token.D_cdouble,
		"cent" : Token.D_cent,
		"cfloat" : Token.D_cfloat,
		"char" : Token.D_char,
		"class" : Token.D_class,
		"const" : Token.D_const,
		"continue" : Token.D_continue,
		"creal" : Token.D_creal,
		"dchar" : Token.D_dchar,
		"debug" : Token.D_debug,
		"default" : Token.D_default,
		"delegate" : Token.D_delegate,
		"delete" : Token.D_delete,
		"deprecated" : Token.D_deprecated,
		"do" : Token.D_do,
		"double" : Token.D_double,
		"else" : Token.D_else,
		"enum" : Token.D_enum,
		"export" : Token.D_export,
		"extern" : Token.D_extern,
		"false" : Token.D_false,
		"final" : Token.D_final,
		"finally" : Token.D_finally,
		"float" : Token.D_float,
		"for" : Token.D_for,
		"foreach" : Token.D_foreach,
		"foreach_reverse" : Token.D_foreach_reverse,
		"function" : Token.D_function,
		"goto" : Token.D_goto,
		"idouble" : Token.D_idouble,
		"if" : Token.D_if,
		"ifloat" : Token.D_ifloat,
		"immutable" : Token.D_immutable,
		"import" : Token.D_import,
		"in" : Token.D_in,
		"inout" : Token.D_inout,
		"int" : Token.D_int,
		"interface" : Token.D_interface,
		"invariant" : Token.D_invariant,
		"ireal" : Token.D_ireal,
		"is" : Token.D_is,
		"lazy" : Token.D_lazy,
		"long" : Token.D_long,
		"macro" : Token.D_macro,
		"mixin" : Token.D_mixin,
		"module" : Token.D_module,
		"new" : Token.D_new,
		"nothrow" : Token.D_nothrow,
		"null" : Token.D_null,
		"out" : Token.D_out,
		"override" : Token.D_override,
		"package" : Token.D_package,
		"pragma" : Token.D_pragma,
		"private" : Token.D_private,
		"protected" : Token.D_protected,
		"public" : Token.D_public,
		"pure" : Token.D_pure,
		"real" : Token.D_real,
		"ref" : Token.D_ref,
		"return" : Token.D_return,
		"scope" : Token.D_scope,
		"shared" : Token.D_shared,
		"short" : Token.D_short,
		"static" : Token.D_static,
		"struct" : Token.D_struct,
		"super" : Token.D_super,
		"switch" : Token.D_switch,
		"synchronized" : Token.D_synchronized,
		"template" : Token.D_template,
		"this" : Token.D_this,
		"throw" : Token.D_throw,
		"true" : Token.D_true,
		"try" : Token.D_try,
		"typedef" : Token.D_typedef,
		"typeid" : Token.D_typeid,
		"typeof" : Token.D_typeof,
		"ubyte" : Token.D_ubyte,
		"ucent" : Token.D_ucent,
		"uint" : Token.D_uint,
		"ulong" : Token.D_ulong,
		"union" : Token.D_union,
		"unittest" : Token.D_unittest,
		"ushort" : Token.D_ushort,
		"version" : Token.D_version,
		"void" : Token.D_void,
		"volatile" : Token.D_volatile,
		"wchar" : Token.D_wchar,
		"while" : Token.D_while,
		"with" : Token.D_with,
		"__FILE__" : Token.D___FILE__,
		"__LINE__" : Token.D___LINE__,
		"__gshared" : Token.D___gshared,
		"__thread" : Token.D___thread,
		"__traits" : Token.D___traits
	];
	
	dKeywordTable.rehash;
	+/
	
	// all of these should be considered prefixed with @
	objectiveDKeywordTable = [
		"class"    : Token.ObjD_class,
		"selector" : Token.ObjD_selector,
		"objc"     : Token.ObjD_objc,
		"end"      : Token.ObjD_end,
		"protocol" : Token.ObjD_protocol,
		"optional" : Token.ObjD_optional,
		"required" : Token.ObjD_required
	];
	
	objectiveDKeywordTable.rehash;
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
	
	return keywordify(assumeUnique(lexemes));
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
			
			// fall through
			
		default:
			output ~= lexeme;
		}
	}
	
	return assumeUnique(output);
}
