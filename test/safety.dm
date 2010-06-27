/*
 * safety.dm
 * Objective-D type safety test
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

import objd.mobject;
import objd.runtime;
static import objd.objc;
import std.contracts;
import std.stdio;

@class MyClass : MObject {
}

+ (int)something:(string)str {
	return 42;
}

+ (void)somethingElse:(const char[])str {}

@end

void main () {
	writeln("Testing Objective-D type safety...");
	
	writeln("--- Checking implicit conversion of object return types");
	assert(objd_msgSend!(Class)(MObject, @selector(class)) is MObject);
	assert(objd_msgSend!(id   )(MObject, @selector(class)) is MObject);
	
	writeln("--- Checking that incorrect return types throw exceptions");
	
	try {
		objd_msgSend!(int)(MObject, @selector(class));
		throw new Error("exception not thrown");
	} catch (Exception ex) {
		writefln("  - %s", ex.msg);
	}
	
	try {
		objd_msgSend!(double)(MObject, @selector(class));
		throw new Error("exception not thrown");
	} catch (Exception ex) {
		writefln("  - %s", ex.msg);
	}
	
	try {
		objd_msgSend!(string)(MObject, @selector(class));
		throw new Error("exception not thrown");
	} catch (Exception ex) {
		writefln("  - %s", ex.msg);
	}
	
	try {
		objd_msgSend!(Exception)(MObject, @selector(class));
		throw new Error("exception not thrown");
	} catch (Exception ex) {
		writefln("  - %s", ex.msg);
	}
	
	writeln("--- Checking that extra parameters throw exceptions");
	
	try {
		objd_msgSend!(Class)(MObject, @selector(class), "extra parameter");
		throw new Error("exception not thrown");
	} catch (Exception ex) {
		writefln("  - %s", ex.msg);
	}
	
	try {
		objd_msgSend!(id)(MObject, @selector(class), "extra parameter", 5, 10.3);
		throw new Error("exception not thrown");
	} catch (Exception ex) {
		writefln("  - %s", ex.msg);
	}
	
	writeln("--- Checking that incorrect parameter types throw exceptions");
	
	try {
		objd_msgSend!(bool)(MObject, @selector(respondsToSelector:), 10.5);
		throw new Error("exception not thrown");
	} catch (Exception ex) {
		writefln("  - %s", ex.msg);
	}
	
	try {
		objd_msgSend!(bool)(MObject, @selector(respondsToSelector:), "foobar");
		throw new Error("exception not thrown");
	} catch (Exception ex) {
		writefln("  - %s", ex.msg);
	}
	
	writeln("--- Checking that immutable works properly");
	
	assert(objd_msgSend!(int)(MyClass, @selector(something:), "foobar") == 42);
	
	auto str = [ 'f', 'o', 'o' ];
	assert(objd_msgSend!(int)(MyClass, @selector(something:), assumeUnique(str)) == 42);
	
	try {
		objd_msgSend!(int)(MyClass, @selector(something:), str);
		throw new Error("exception not thrown");
	} catch (Exception ex) {
		writefln("  - %s", ex.msg);
	}
	
	writeln("--- Checking that const works properly");
	
	// TODO: none of these tests pass!
	//objd_msgSend!(void)(MyClass, @selector(somethingElse:), "foobar");
	//objd_msgSend!(void)(MyClass, @selector(somethingElse:), assumeUnique(str));
	//objd_msgSend!(void)(MyClass, @selector(somethingElse:), str);
	
	writefln("%s passed!", __FILE__);
}
