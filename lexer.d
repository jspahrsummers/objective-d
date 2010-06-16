import std.array;
import std.contracts;
import std.ctype;
import std.stdio;
import std.uni;
import exceptions;

enum Token {
	Unknown,
	
	/* Symbols (the ones we care about, anyways) */
	At,
	Colon,
	Semicolon,
	LBrace,
	RBrace,
	LBracket,
	RBracket,
	LParen,
	RParen,
	Minus,
	Plus,
	
	/* Literals */
	String,
	Character,
	
	/* Identifiers and Objective-D keywords */
	Identifier
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

immutable(Lexeme) newToken (dstring content) {
	switch (content) {
	case "@": return new Lexeme(Token.At      , content);
	case ":": return new Lexeme(Token.Colon   , content);
	case "{": return new Lexeme(Token.LBrace  , content);
	case "}": return new Lexeme(Token.RBrace  , content);
	case "[": return new Lexeme(Token.LBracket, content);
	case "]": return new Lexeme(Token.RBracket, content);
	case "(": return new Lexeme(Token.LParen  , content);
	case ")": return new Lexeme(Token.RParen  , content);
	case "-": return new Lexeme(Token.Minus   , content);
	case "+": return new Lexeme(Token.Plus    , content);
	default:  return new Lexeme(Token.Unknown , content);
	}
}

immutable(Lexeme) newIdentifier (dstring content) {
	return new Lexeme(Token.Identifier, content, null, 0);
}

immutable(Lexeme) newString (dstring content) {
	return new Lexeme(Token.String, content, null, 0);
}
	
immutable class Lexeme {
public:
	Token token;
	dstring content;
	string file;
	ulong line;
	
	this (Token token, dstring content, string file = null, ulong line = 0) {
		this.token = token;
		this.content = content;
		this.file = file;
		this.line = line;
	}
	
	void writeToFile (ref File outFD) immutable {
		switch (token) {
		case Token.At:
			outFD.write('@');
			
			// don't put a space after @s
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
	
	auto current = Appender!dstring(null);
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
	
	void createLexeme (Token token, dstring content = current.data) {
		lexemes ~= new Lexeme(token, content.idup, file, line);
		current.clear();
		skip = SkipType.None;
		
		//writefln("creating lexeme with content: %s", content);
	}
	
	void createUnknownLexeme () {
		if (current.data is null || current.data.length == 0)
			return;
		
		// check tokens for which we need to munch maximally
		switch (current.data) {
		case "-":
			createLexeme(Token.Minus);
			break;
		
		case "+":
			createLexeme(Token.Plus);
			break;
		
		default:
			bool isIdentifier = false;
			if (current.data[0] == '_' || isUniAlpha(current.data[0])) {
				isIdentifier = true;
				foreach (identCh; current.data[1 .. $]) {
					if (identCh != '_' && !isdigit(identCh) && !isUniAlpha(identCh)) {
						isIdentifier = false;
						break;
					}
				}
			}
			
			//writefln("creating unknown lexeme (identifier = %s)", isIdentifier);
			createLexeme(isIdentifier ? Token.Identifier : Token.Unknown);
		}
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
					createLexeme(Token.String);
					continue;
				} else if (ch == '\\' && lastChar == '\\') {
					// hide escaped backslashes to avoid parsing problems
					ch = '\0';
				}
				
				current.put(ch);
				continue;
			
			case SkipType.WYSIWYGString:
				if (ch == closingDelimiter) {
					createLexeme(Token.String);
					continue;
				}
				
				current.put(ch);
				continue;
			
			case SkipType.HexString:
				if (ch == '"') {
					createLexeme(Token.String);
					continue;
				}
				
				current.put(ch);
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
					
						createLexeme(Token.String);
						continue;
					}
				}
				
				current.put(ch);
				continue;
			
			case SkipType.TokenString:
				if (ch == '{')
					++nesting;
				else if (ch == '}') {
					if (--nesting == 0) {
						createLexeme(Token.String);
						continue;
					}
				}
				
				current.put(ch);
				continue;
			
			case SkipType.CharLiteral:
				if (lastChar != '\\' && ch == '\'') {
					createLexeme(Token.Character);
					continue;
				} else if (ch == '\\' && lastChar == '\\') {
					// hide escaped backslashes to avoid parsing problems
					ch = '\0';
				}
				
				current.put(ch);
				continue;
			}
			
			//writefln("%s:%s: %s", line, i, ch);
			
			switch (ch) {
			case '"':
				// todo: allow tokens immediately before strings
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
				current.clear();
				continue;
			
			case '\'':
				// todo: allow tokens immediately before characters
				skip = SkipType.CharLiteral;
				current.clear();
				continue;
			
			case '/':
				// todo: allow tokens immediately before comments
				if (lastChar == '/') {
					skip = SkipType.LineComment;
					current.clear();
					continue;
				}
				
				break;
			
			case '*':
				// todo: allow tokens immediately before comments
				if (lastChar == '/') {
					skip = SkipType.BlockComment;
					current.clear();
					continue;
				}
				
				break;
			
			case '+':
				// todo: allow tokens immediately before comments
				if (lastChar == '/') {
					skip = SkipType.NestedComment;
					nesting = 1;
					current.clear();
					continue;
				}
				
				break;
			
			case '@':
				createUnknownLexeme();
				createLexeme(Token.At, "@");
				continue;
			
			case '(':
				createUnknownLexeme();
				createLexeme(Token.LParen, "(");
				continue;
			
			case ')':
				createUnknownLexeme();
				createLexeme(Token.RParen, ")");
				continue;
			
			case '{':
				if (lastChar == 'q') {
					skip = SkipType.TokenString;
					nesting = 1;
					current.clear();
					continue;
				}
				
				createUnknownLexeme();
				createLexeme(Token.LBrace, "{");
				continue;
			
			case '}':
				createUnknownLexeme();
				createLexeme(Token.RBrace, "}");
				continue;
			
			case '[':
				createUnknownLexeme();
				createLexeme(Token.LBracket, "[");
				continue;
			
			case ']':
				createUnknownLexeme();
				createLexeme(Token.RBracket, "]");
				continue;
			
			case ':':
				createUnknownLexeme();
				createLexeme(Token.Colon, ":");
				continue;
			
			case ';':
				createUnknownLexeme();
				createLexeme(Token.Semicolon, ";");
				continue;
			
			default:
				if (isspace(ch)) {
					createUnknownLexeme();
					continue;
				}
			}
			
			current.put(ch);
		}
	}
	
	return assumeUnique(lexemes);
}
