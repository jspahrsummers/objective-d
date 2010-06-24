/*
 * syntax.dm
 * Objective-D syntax test
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
import objd.mobject;

@class MyClass : MObject {
	int test;
}

- (void)wordsCannot:(string)what inObjectiveC {
	++self.test;
}

+ (id)print:(string)a also:(string)b {
	return self;
}

- (int)nonIDReturnType {
	return 5;
}

@end

void main () {
	writeln("Testing Objective-D syntax...");
	
	writeln("--- Invoking [MyClass class] and checking for identity with the declared MyClass");
	assert([MyClass class] is MyClass);
	
	writeln("--- Invoking [[MyClass class] superclass] and checking for identity with MObject");
	assert([[MyClass class] superclass] is MObject);
	
	writeln("--- Invoking [MyClass superclass] and checking for identity with [[MyClass class] superclass]");
	assert([MyClass superclass] is [[MyClass class] superclass]);
	
	writeln("--- Invoking [MyClass new]");
	id obj = [MyClass new];
	assert(obj !is null);
	
	writeln("--- Invoking [nil new] and validating that response is nil");
	assert([nil new] is nil);
	
	writeln("--- Invoking [obj class] and checking for identity with MyClass");
	assert([obj class] is MyClass);
	
	writeln("--- Invoking [obj performSelector:@selector(class)] and checking for identity with MyClass");
	assert([obj performSelector:@selector(class)] is MyClass);
	
	writeln("--- Sending message with a trailing word");
	[obj wordsCannot:"trail" inObjectiveC];
	
	writeln("--- Sending message with multiple arguments");
	auto cls = [MyClass print:"hello" also:"world"];
	assert(cls is MyClass);
	
	writeln("--- Validating returned value of method that does not return id");
	assert([obj nonIDReturnType] == 5);
	
	writefln("%s passed!", __FILE__);
}
