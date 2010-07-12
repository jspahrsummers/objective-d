/*
 * expressions.d
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

module parser.expressions;
import exceptions;
import parser.declarations;
import parser.lexemes;
import parser.objd;
import std.contracts;

immutable(Lexeme[]) parseArgumentList (ref immutable(Lexeme)[] lexemes) {
	immutable(Lexeme)[] output;
	
	output ~= parseAssignExpression(lexemes);
	if (lexemes[0].token == Token.Comma) {
		output ~= lexemes[0];
		lexemes = lexemes[1 .. $];
		output ~= parseArgumentList(lexemes);
	}
	
	return assumeUnique(output);
}

immutable(Lexeme[]) parseExpression (ref immutable(Lexeme)[] lexemes, bool objdMethod = false) {
	immutable(Lexeme)[] output;
	
	output ~= parseAssignExpression(lexemes, objdMethod);
	if (lexemes[0].token == Token.Comma) {
		output ~= lexemes[0];
		lexemes = lexemes[1 .. $];
		output ~= parseExpression(lexemes, objdMethod);
	}
	
	return assumeUnique(output);
}

immutable(Lexeme[]) parseAssignExpression (ref immutable(Lexeme)[] lexemes, bool objdMethod = false) {
	immutable(Lexeme)[] output;
	
	output ~= parseConditionalExpression(lexemes, objdMethod);
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
		
		output ~= parseAssignExpression(lexemes, objdMethod);
		break;
	default:
		;
	}
	
	return assumeUnique(output);
}

immutable(Lexeme[]) parseConditionalExpression (ref immutable(Lexeme)[] lexemes, bool objdMethod = false) {
	immutable(Lexeme)[] output;
	
	output ~= parseOrOrExpression(lexemes, objdMethod);
	if (lexemes[0].token == Token.Question) {
		output ~= lexemes[0];
		lexemes = lexemes[1 .. $];
		
		output ~= parseExpression(lexemes, objdMethod);
		if (lexemes[0].token != Token.Colon)
			errorOut(lexemes[0], "expected :");
		
		output ~= lexemes[0];
		lexemes = lexemes[1 .. $];
		
		output ~= parseConditionalExpression(lexemes, objdMethod);
	}
	
	return assumeUnique(output);
}

immutable(Lexeme[]) parseOrOrExpression (ref immutable(Lexeme)[] lexemes, bool objdMethod = false) {
	immutable(Lexeme)[] output;
	
	output ~= parseAndAndExpression(lexemes, objdMethod);
	if (lexemes[0].token == Token.LogicalOr) {
		output ~= lexemes[0];
		lexemes = lexemes[1 .. $];
		
		// the D language spec actually has this the other way around
		// OrOrExpression || AndAndExpression
		// but it's okay because we don't care about precedence here
		output ~= parseOrOrExpression(lexemes, objdMethod);
	}
	
	return assumeUnique(output);
}

immutable(Lexeme[]) parseAndAndExpression (ref immutable(Lexeme)[] lexemes, bool objdMethod = false) {
	immutable(Lexeme)[] output;
	
	output ~= parseOrExpression(lexemes, objdMethod);
	if (lexemes[0].token == Token.LogicalAnd) {
		output ~= lexemes[0];
		lexemes = lexemes[1 .. $];
		
		// the D language spec actually has this the other way around
		// AndAndExpression && OrExpression
		// but it's okay because we don't care about precedence here
		output ~= parseAndAndExpression(lexemes, objdMethod);
	}
	
	return assumeUnique(output);
}

immutable(Lexeme[]) parseOrExpression (ref immutable(Lexeme)[] lexemes, bool objdMethod = false) {
	immutable(Lexeme)[] output;
	
	output ~= parseXorExpression(lexemes, objdMethod);
	if (lexemes[0].token == Token.BitwiseOr) {
		output ~= lexemes[0];
		lexemes = lexemes[1 .. $];
		
		// the D language spec actually has this the other way around
		// OrExpression | XorExpression
		// but it's okay because we don't care about precedence here
		output ~= parseOrExpression(lexemes, objdMethod);
	}
	
	return assumeUnique(output);
}

immutable(Lexeme[]) parseXorExpression (ref immutable(Lexeme)[] lexemes, bool objdMethod = false) {
	immutable(Lexeme)[] output;
	
	output ~= parseAndExpression(lexemes, objdMethod);
	if (lexemes[0].token == Token.Xor) {
		output ~= lexemes[0];
		lexemes = lexemes[1 .. $];
		
		// the D language spec actually has this the other way around
		// XorExpression ^ AndExpression
		// but it's okay because we don't care about precedence here
		output ~= parseXorExpression(lexemes, objdMethod);
	}
	
	return assumeUnique(output);
}

immutable(Lexeme[]) parseAndExpression (ref immutable(Lexeme)[] lexemes, bool objdMethod = false) {
	immutable(Lexeme)[] output;
	
	output ~= parseCmpExpression(lexemes, objdMethod);
	if (lexemes[0].token == Token.BitwiseAnd) {
		output ~= lexemes[0];
		lexemes = lexemes[1 .. $];
		
		// the D language spec actually has this the other way around
		// AndExpression & CmpExpression
		// but it's okay because we don't care about precedence here
		output ~= parseAndExpression(lexemes, objdMethod);
	}
	
	return assumeUnique(output);
}

immutable(Lexeme[]) parseCmpExpression (ref immutable(Lexeme)[] lexemes, bool objdMethod = false) {
	immutable(Lexeme)[] output;
	
	output ~= parseShiftExpression(lexemes, objdMethod);
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
		output ~= parseShiftExpression(lexemes, objdMethod);
		break;
	
	case Token.Identifier:
		switch (lexemes[0].content) {
		case "is": // IdentityExpression
		case "in": // InExpression
			output ~= lexemes[0];
			lexemes = lexemes[1 .. $];
			output ~= parseShiftExpression(lexemes, objdMethod);
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
				output ~= parseShiftExpression(lexemes, objdMethod);
				break;
			default:
				;
			}
		}
		
		break;
	
	default:
		;
	}
	
	return assumeUnique(output);
}

immutable(Lexeme[]) parseShiftExpression (ref immutable(Lexeme)[] lexemes, bool objdMethod = false) {
	immutable(Lexeme)[] output;
	
	output ~= parseAddExpression(lexemes, objdMethod);
	switch (lexemes[0].token) {
	case Token.ShiftLeft:
	case Token.ShiftRight:
	case Token.UnsignedShiftRight:
		output ~= lexemes[0];
		lexemes = lexemes[1 .. $];
		
		// the D language spec actually has this the other way around
		// ShiftExpression << AddExpression
		// but it's okay because we don't care about precedence here
		output ~= parseShiftExpression(lexemes, objdMethod);
		break;
		
	default:
		;
	}
	
	return assumeUnique(output);
}

immutable(Lexeme[]) parseAddExpression (ref immutable(Lexeme)[] lexemes, bool objdMethod = false) {
	immutable(Lexeme)[] output;
	
	output ~= parseMulExpression(lexemes, objdMethod);
	switch (lexemes[0].token) {
	case Token.Plus:
	case Token.Minus:
	case Token.Tilde:
		output ~= lexemes[0];
		lexemes = lexemes[1 .. $];
		
		// the D language spec actually has this the other way around
		// AddExpression + MulExpression
		// but it's okay because we don't care about precedence here
		output ~= parseAddExpression(lexemes, objdMethod);
		break;
		
	default:
		;
	}
	
	return assumeUnique(output);
}

immutable(Lexeme[]) parseMulExpression (ref immutable(Lexeme)[] lexemes, bool objdMethod = false) {
	immutable(Lexeme)[] output;
	
	output ~= parsePowExpression(lexemes, objdMethod);
	switch (lexemes[0].token) {
	case Token.Star:
	case Token.Slash:
	case Token.Mod:
		output ~= lexemes[0];
		lexemes = lexemes[1 .. $];
		
		// the D language spec actually has this the other way around
		// MulExpression * PowExpression
		// but it's okay because we don't care about precedence here
		output ~= parseMulExpression(lexemes, objdMethod);
		break;
		
	default:
		;
	}
	
	return assumeUnique(output);
}

immutable(Lexeme[]) parsePowExpression (ref immutable(Lexeme)[] lexemes, bool objdMethod = false) {
	immutable(Lexeme)[] output;
	
	output ~= parseUnaryExpression(lexemes, objdMethod);
	if (lexemes[0].token == Token.Pow) {
		output ~= lexemes[0];
		lexemes = lexemes[1 .. $];
		output ~= parsePowExpression(lexemes, objdMethod);
	}
	
	return assumeUnique(output);
}

immutable(Lexeme[]) parseUnaryExpression (ref immutable(Lexeme)[] lexemes, bool objdMethod = false) {
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
		output ~= parseUnaryExpression(lexemes, objdMethod);
		break;
	
	case Token.LBracket:
		output ~= parseMessageSend(lexemes);
		break;
	
	case Token.Identifier:
		bool found = true;
		switch (lexemes[0].content) {
		case "new":
			output ~= lexemes[0];
			lexemes = lexemes[1 .. $];
			output ~= parseNewExpression(lexemes, objdMethod);
			break;
			
		case "delete":
			output ~= lexemes[0];
			lexemes = lexemes[1 .. $];
			output ~= parseUnaryExpression(lexemes, objdMethod);
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
			
			output ~= parseUnaryExpression(lexemes, objdMethod);
			break;
		
		default:
			found = false;
		}
		
		if (found)
			break;
	
	default:
		output ~= parsePostfixExpression(lexemes, objdMethod);
	}
	
	return assumeUnique(output);
}

immutable(Lexeme[]) parseNewExpression (ref immutable(Lexeme)[] lexemes, bool objdMethod = false) {
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
		
		output ~= parseBaseClassList(lexemes);
		output ~= parseDeclDefs(lexemes);
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
		
		output ~= parseAssignExpression(lexemes, objdMethod);
		
		if (lexemes[0].token != Token.RBracket)
			errorOut(lexemes[0], "expected ]");
		
		output ~= lexemes[0];
		lexemes = lexemes[1 .. $];
	}
	
	return assumeUnique(output);
}

immutable(Lexeme[]) parsePostfixExpression (ref immutable(Lexeme)[] lexemes, bool objdMethod = false) {
	immutable(Lexeme)[] output;
	
	output ~= parsePrimaryExpression(lexemes, objdMethod);
	switch (lexemes[0].token) {
	case Token.Dot:
		auto lexeme = lexemes[1];
		output ~= lexemes[0 .. 1];
		lexemes = lexemes[2 .. $];
		
		if (lexeme.token != Token.Identifier)
			errorOut(lexeme, "expected identifier");
		
		if (lexeme.content == "new") {
			output ~= parseNewExpression(lexemes, objdMethod);
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
				output ~= parseAssignExpression(lexemes, objdMethod);
				
				if (lexemes[0].token != Token.Range)
					errorOut(lexemes[0], "expected ..");
				
				output ~= lexemes[0];
				lexemes = lexemes[1 .. $];
				
				output ~= parseAssignExpression(lexemes, objdMethod);
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
	
	return assumeUnique(output);
}

immutable(Lexeme[]) parsePrimaryExpression (ref immutable(Lexeme)[] lexemes, bool objdMethod = false) {
	immutable(Lexeme)[] output;
	
	switch (lexemes[0].token) {
	case Token.Dot:
		output ~= lexemes[0];
		lexemes = lexemes[1 .. $];
		
		if (lexemes[0].token != Token.Identifier)
			errorOut(lexemes[0], "expected identifier");
	
	case Token.Identifier:
		bool found = true;
		switch (lexemes[0].content) {
		case "assert":
			if (lexemes[1].token != Token.LParen)
				errorOut(lexemes[1], "expected (");
			
			output ~= lexemes[0 .. 2];
			lexemes = lexemes[2 .. $];
			
			output ~= parseAssignExpression(lexemes, objdMethod);
			if (lexemes[0].token == Token.Comma) {
				output ~= lexemes[0];
				lexemes = lexemes[1 .. $];
				
				output ~= parseAssignExpression(lexemes, objdMethod);
			}
			
			if (lexemes[0].token != Token.RParen)
				errorOut(lexemes[0], "expected )");
				
			output ~= lexemes[0];
			lexemes = lexemes[1 .. $];
			break;
		
		case "import":
			if (lexemes[1].token != Token.LParen)
				errorOut(lexemes[1], "expected (");
			
			output ~= lexemes[0 .. 2];
			lexemes = lexemes[2 .. $];
			
			output ~= parseAssignExpression(lexemes, objdMethod);
			
			if (lexemes[0].token != Token.RParen)
				errorOut(lexemes[0], "expected )");
				
			output ~= lexemes[0];
			lexemes = lexemes[1 .. $];
			break;
		
		case "mixin":
			if (lexemes[1].token != Token.LParen)
				errorOut(lexemes[1], "expected (");
			
			output ~= lexemes[0 .. 2];
			lexemes = lexemes[2 .. $];
			
			// TODO: allow Objective-D string mixins?
			output ~= parseAssignExpression(lexemes, objdMethod);
			
			if (lexemes[0].token != Token.RParen)
				errorOut(lexemes[0], "expected )");
				
			output ~= lexemes[0];
			lexemes = lexemes[1 .. $];
			break;
		
		case "typeof":
			output ~= parseTypeof(lexemes);
			break;
		
		case "typeid":
			if (lexemes[1].token != Token.LParen)
				errorOut(lexemes[1], "expected (");
			
			output ~= lexemes[0 .. 2];
			lexemes = lexemes[2 .. $];
			
			auto save = lexemes;
			try {
				output ~= parseDType(lexemes);
			} catch (ParseException) {
				output ~= parseExpression(lexemes, objdMethod);
			}
			
			if (lexemes[0].token != Token.RParen)
				errorOut(lexemes[0], "expected )");
				
			output ~= lexemes[0];
			lexemes = lexemes[1 .. $];
			break;
		
		// TODO:
		// IsExpression
		// TraitsExpression
		
		default:
			found = false;
		}
		
		if (found)
			break;
	
	case Token.Dollar:
	case Token.Number:
	case Token.Character:
	case Token.String:
		output ~= lexemes[0];
		lexemes = lexemes[1 .. $];
		break;
	
	case Token.ObjD_selector:
		lexemes = lexemes[1 .. $];
		output ~= parseSelector(lexemes);
		break;
	
	case Token.LParen:
		output ~= lexemes[0];
		lexemes = lexemes[1 .. $];
		
		output ~= parseExpression(lexemes, objdMethod);
		
		if (lexemes[0].token != Token.RParen)
			errorOut(lexemes[0], "expected )");
			
		output ~= lexemes[0];
		lexemes = lexemes[1 .. $];
		break;
	
	case Token.LBracket:
		output ~= parseArrayLiteral(lexemes);
		break;
	
	// TODO:
	// AssocArrayLiteral
	// FunctionLiteral
	default:
		errorOut(lexemes[0], "expected expression or identifier");
	}
	
	return assumeUnique(output);
}

immutable(Lexeme[]) parseArrayLiteral (ref immutable(Lexeme)[] lexemes) {
	immutable(Lexeme)[] output;
	
	if (lexemes[0].token != Token.LBracket)
		errorOut(lexemes[0], "expected [");
	
	output ~= lexemes[0];
	lexemes = lexemes[1 .. $];
	
	output ~= parseArgumentList(lexemes);
	
	if (lexemes[0].token != Token.RBracket)
		errorOut(lexemes[0], "expected ]");
	
	output ~= lexemes[0];
	lexemes = lexemes[1 .. $];
	
	return assumeUnique(output);
}

immutable(Lexeme[]) parseTypeof (ref immutable(Lexeme)[] lexemes) {
	immutable(Lexeme)[] output;
	
	if (lexemes[0].content != "typeof")
		errorOut(lexemes[0], "expected \"typeof\"");
	
	if (lexemes[1].token != Token.LParen)
		errorOut(lexemes[1], "expected (");
		
	output ~= lexemes[0 .. 2];
	lexemes = lexemes[2 .. $];
	
	if (lexemes[0].token == Token.Identifier && lexemes[0].content == "return") {
		output ~= lexemes[0];
		lexemes = lexemes[1 .. $];
	} else
		output ~= parseExpression(lexemes);
	
	if (lexemes[0].token != Token.RParen)
		errorOut(lexemes[0], "expected )");
		
	output ~= lexemes[0];
	lexemes = lexemes[1 .. $];
	return assumeUnique(output);
}
