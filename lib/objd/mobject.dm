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

module objd.mobject;
import core.thread;
import objd.runtime;
import std.c.stdlib;
import std.stdio;
import std.string;

class DoesNotRecognizeSelectorException : Exception {
public:
	this (string msg) {
		super(msg);
	}
}

@class MObject {
	
}

/* Class methods */
// + (id) alloc is automatically added by the compiler

+ (Class)class {
	return self;
}

+ (bool)conformsToProtocol:(immutable Protocol)aProtocol {
	foreach (p; self.protocols) {
		if (p == aProtocol)
			return true;
	}
	
	return false;
}

+ (string)description {
	return "Class(" ~ self.name ~ ")";
}

+ (void)doesNotRecognizeSelector:(SEL)aSelector {
	throw new DoesNotRecognizeSelectorException(format("%s does not recognize selector %s", [self description], sel_getName(aSelector)));
}

+ (void)initialize {}

+ (bool)instancesRespondToSelector:(SEL)aSelector {
	foreach (const Class cls; self) {
		if (cls.hasMethod(aSelector))
			return true;
	}
	
	return false;
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

+ (id)performSelector:(SEL)aSelector {
	return self.msgSend!(id)(aSelector);
}

+ (id)performSelector:(SEL)aSelector withObject:(id)obj {
	return self.msgSend!(id)(aSelector, obj);
}

+ (id)performSelector:(SEL)aSelector withObject:(id)obj withObject:(id)obj2 {
	return self.msgSend!(id)(aSelector, obj, obj2);
}

+ (Class)superclass {
	return self.superclass;
}

/* Instance methods */
- (Class)class {
	return self.isa;
}

- (bool)conformsToProtocol:(immutable Protocol)aProtocol {
	return [[self class] conformsToProtocol:aProtocol];
}

- (string)description {
	return self.isa.name;
}

- (void)finalize {}

- (hash_t)hash {
	return self.toHash();
}

- (id)init {
	return self;
}

- (bool)isEqual:(id)obj {
	return self is obj;
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

- (bool)isProxy {
	return false;
}

- (id)performSelector:(SEL)aSelector {
	return self.msgSend!(id)(aSelector);
}

- (id)performSelector:(SEL)aSelector withObject:(id)obj {
	return self.msgSend!(id)(aSelector, obj);
}

- (id)performSelector:(SEL)aSelector withObject:(id)obj withObject:(id)obj2 {
	return self.msgSend!(id)(aSelector, obj, obj2);
}

- (bool)respondsToSelector:(SEL)aSelector {
	foreach (const Class cls; self.isa) {
		if (cls.hasMethod(aSelector))
			return true;
	}
	
	return false;
}

- (id)self {
	return self;
}

- (Class)superclass {
	return self.isa.superclass;
}

@end

@class MyClass : MObject {}
@end

unittest {
	assert([MyClass class] is MyClass);
	assert([MyClass respondsToSelector:@selector(class)]);
	assert([MyClass isSubclassOfClass:MObject]);
	
	id obj = [MyClass new];
	assert(obj !is null);
	
	assert([obj    isKindOfClass:MObject]);
	assert([obj    isKindOfClass:MyClass]);
	assert(![obj isMemberOfClass:MObject]);
	assert([obj  isMemberOfClass:MyClass]);
	
	id obj2 = [MyClass new];
	assert(obj2 !is null);
}
