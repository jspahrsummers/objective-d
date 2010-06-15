import std.stdio;
import exceptions;
import lexer;
import parser;

bool process (string[] inputFiles, string outputFile, string[] includePaths) {
	File outFD;
	try {
		outFD = File(outputFile, "wt");
	} catch {
		stderr.writefln("Could not open file \"%s\" for writing.", outputFile);
		return false;
	}
	
	scope(exit) outFD.detach();
	
	outFD.writeln("// Automatically generated by the Objective-D preprocessor");
	outFD.writeln("import objd.runtime;");
	
	auto success = true;
	foreach (inputFile; inputFiles) {
		try {
			auto lexemes = parse(lex(inputFile));
			
			ulong outputLine = 3;
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
			success = false;
		}
	}
	
	return success;
}