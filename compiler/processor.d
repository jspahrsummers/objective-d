/*
 * processor.d
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

import std.stdio;
import exceptions;
import lexer;
import parser.start;

bool process (string[] inputFiles, string outputFile) {
	File outFD;
	try {
		outFD = File(outputFile, "wt");
	} catch {
		stderr.writefln("Could not open file \"%s\" for writing.", outputFile);
		return false;
	}
	
	scope(exit) outFD.detach();
	
	ulong outputLine = 1;
	
	void writeLine(T...) (T args) {
		outFD.writeln(args);
		++outputLine;
	}
	
	writeLine("/* This file was automatically generated by the Objective-D preprocessor */");
	
	auto success = true;
	foreach (inputFile; inputFiles) {
		try {
			auto lexemes = parse(lex(inputFile));
			
			string currentFile;
			ulong currentLine;
			uint indentation = 0;
			
			void newLine () {
				outFD.writeln();
				++outputLine;
				++currentLine;
				foreach (i; 0 .. indentation) {
					outFD.write('\t');
				}
			}
			
			foreach (lexeme; lexemes) {
				if (lexeme.file is null) {
					if (currentFile !is null) {
						currentLine = 0;
						currentFile = null;
						++outputLine;
						outFD.writef("\n#line %s \"%s\"", outputLine + 1, outputFile);
						newLine();
					}
				} else {
					if (currentFile is null || currentFile != lexeme.file) {
						currentFile = lexeme.file;
						++outputLine;
						outFD.writef("\n#line %s \"%s\"", lexeme.line, currentFile);
						newLine();
						
						currentLine = lexeme.line;
					} else if (currentLine != lexeme.line) {
						if (lexeme.line == currentLine + 1)
							newLine();
						else {
							++outputLine;
							outFD.writef("\n#line %s", currentLine);
							newLine();
							
							currentLine = lexeme.line;
						}
					}
				}
				
				if (lexeme.token == Token.RBrace) {
					if (indentation)
						--indentation;
					
					newLine();
				}
				
				lexeme.writeToFile(outFD);
				
				if (lexeme.token == Token.LBrace) {
					++indentation;
					newLine();
				} else if (lexeme.token == Token.RBrace)
					newLine();
			}
		} catch (ParseException ex) {
			writeln(ex.msg);
			success = false;
		}
	}
	
	// write out necessary definitions at the end to allow module declaration at the top
	// it also helps avoid clutter
	writeLine("// Objective-D support modules");
	writeLine("static import objd.runtime;");
	writeLine("import objd.types;");
	writeLine();
	writeLine("// Local reflection facilities");
	writeLine(`
		private template _objDMethodReturnTypeAlias (string typename) {
			mixin("
				static if (is(" ~ typename ~ "))
					alias " ~ typename ~ " _objDMethodReturnTypeAlias;
				else
					alias id _objDMethodReturnTypeAlias;
			");
		}
	`);
	
	writeLine(`
		private mixin template _objDAliasTypeToSelectorReturnType (T, string selector, string returnTypeName) {
			mixin("
				static if (!is(" ~ returnTypeName ~ "))
					alias " ~ T.stringof ~ " " ~ returnTypeName ~ ";
				else
					static assert(is(" ~ returnTypeName ~ " == " ~ T.stringof ~ "), \"conflicting return types for selector " ~ selector ~ "\");
			");
		}
	`);
	writeLine();
	
	return success;
}
