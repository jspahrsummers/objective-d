/*
 * objc.dm
 * Objective-C compatibility layer test
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

version (objc_compat) {
	@objc NSAutoreleasePool;
	@objc NSString;
	
	void main () {
		writeln("Testing Objective-C compatibility...");
		
		writeln("--- Invoking [NSAutoreleasePool new]");
		auto pool = [NSAutoreleasePool new];
		assert(pool !is null);
		
		writeln("--- Testing NSAutoreleasePool class equality with isEqual:");
		assert([pool class] == NSAutoreleasePool);
		
		writeln("--- Invoking [[pool class] description] and validating result");
		assert([pool class].toString() == "NSAutoreleasePool");
		
		writeln("--- Invoking [[NSString alloc] init]");
		auto str = [[NSString alloc] init];
		assert(str !is null);
		
		writeln("--- Invoking [[NSString new] autorelease]");
		auto str2 = [[NSString new] autorelease];
		assert(str2 !is null);
		
		assert(str !is str2);
		
		// this will invoke isEqual:
		writeln("--- Testing NSString equality with isEqual:");
		assert(str == str2);
		
		writeln("--- Releasing NSString object");
		[str release];
		
		writeln("--- Draining NSAutoreleasePool");
		[pool drain];
		
		writefln("%s passed!", __FILE__);
	}
} else {
	void main () {
		writefln("Compiled without -version=objc_compat, not running %s", __FILE__);
	}
}
