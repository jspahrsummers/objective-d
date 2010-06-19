/*
 * main.d
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

import std.c.stdlib;
import std.file;
import std.getopt;
import std.stdio;
import processor;

enum COMPILER_MAJOR_VERSION = 0;
enum COMPILER_MINOR_VERSION = 1;
enum COMPILER_PATCH_VERSION = 0;
enum COMPILER_VERSION = COMPILER_MAJOR_VERSION.stringof ~ "." ~ COMPILER_MINOR_VERSION.stringof ~ "." ~ COMPILER_PATCH_VERSION.stringof;

immutable string defaultOutputFilename = "main.d";

int main (string[] args) {
	bool printVersion;
	string outputFile = null;
	string[] includePaths;
	string[] inputFiles;
	
	getopt(args,
		std.getopt.config.bundling,
		"of|o", &outputFile,
		"I", &includePaths,
		"version|v", &printVersion
	);
	
	if (printVersion) {
		writefln("Objective-D compiler version %s", COMPILER_VERSION);
		writeln("Copyright (c) 2010 Justin Spahr-Summers");
	}
	
	assert(args.length > 0, "no invocation argument passed");
	inputFiles = args[1 .. $];
	
	if (outputFile is null) {
		outputFile = defaultOutputFilename;
		if (exists(outputFile)) {
			stderr.writefln("Default output file \"%s\" already exists. You must pass the -o flag to overwrite its contents.", defaultOutputFilename);
			return EXIT_FAILURE;
		}
	} else if (outputFile == "") {
		stderr.writefln("Invalid output filename. Leave blank to use the default.");
		return EXIT_FAILURE;
	}
	
	if (inputFiles is null || inputFiles.length == 0) {
		if (printVersion)
			return EXIT_SUCCESS;
		else {
			// only print an error if the version number wasn't requested
			stderr.writefln("No input files provided.");
			return EXIT_FAILURE;
		}
	} else if (printVersion)
		writeln();
	
	if (process(inputFiles, outputFile, includePaths))
		return EXIT_SUCCESS;
	else
		return EXIT_FAILURE;
}
