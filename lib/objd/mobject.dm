/*
 * mobject.dm
 * Objective-D standard library
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

import objd.runtime;
import std.stdio;

@class MObject {
	
}

+ (Class)class {
	return self;
}

+ (Class)superclass {
	return self.superclass;
}

+ (bool)isSubclassOfClass:(Class)otherClass {
	foreach (const Class cls; self) {
		if (cls == otherClass)
			return true;
	}
	
	return false;
}

+ (id)new {
	return [[self alloc] init];
}

- (Class)class {
	return self.isa;
}

- (id)init {
	return self;
}

- (bool)isKindOfClass:(Class)otherClass {
	foreach (const Class cls; self.isa) {
		if (cls == otherClass)
			return true;
	}
	
	return false;
}

- (bool)isMemberOfClass:(Class)otherClass {
	return self.isa == otherClass;
}

- (void)finalize {}

@end

@class MyClass : MObject {}
@end

unittest {
	assert([MyClass class] is MyClass);
	assert(MyClass.msgSend!bool(sel_registerName("isSubclassOfClass:"), MObject));
	
	id obj = [MyClass new];
	assert(obj !is null);
	
	// parsing needs improvement... message sends with identifiers don't work so hot
	assert(obj.msgSend!bool(sel_registerName("isKindOfClass:"), MObject));
	assert(obj.msgSend!bool(sel_registerName("isKindOfClass:"), MyClass));
	assert(!obj.msgSend!bool(sel_registerName("isMemberOfClass:"), MObject));
	assert(obj.msgSend!bool(sel_registerName("isMemberOfClass:"), MyClass));
	
	id obj2 = [MyClass new];
	assert(obj2 !is null);
}
