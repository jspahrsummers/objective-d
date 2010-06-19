/*
 * runtime.d
 * Objective-D runtime
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

module objd.runtime;
public import objd.types;

import std.stdio;
import std.traits;

enum RUNTIME_MAJOR_VERSION = 0;
enum RUNTIME_MINOR_VERSION = 1;
enum RUNTIME_PATCH_VERSION = 0;
enum RUNTIME_VERSION = RUNTIME_MAJOR_VERSION.stringof ~ "." ~ RUNTIME_MINOR_VERSION.stringof ~ "." ~ RUNTIME_PATCH_VERSION.stringof;

/* Selectors */
string sel_getName (SEL aSelector) {
	return aSelector;
}

SEL sel_registerName (string str) {
	return str;
}

/* Messaging */
class Method {
public:
	immutable SEL selector;
	TypeInfo returnType;
	const(TypeInfo)[] argumentTypes;
	IMP implementation;
	
	static Method define(T, A...)(SEL selector, T function (id, SEL, A) impl) {
		TypeInfo[] argTypes = new TypeInfo[A.length];
		foreach (i, type; A)
			argTypes[i] = typeid(type);
		
		return new Method(selector, cast(IMP)(impl), typeid(Unqual!(T)), argTypes);
	}
	
	this (SEL selector, IMP implementation, TypeInfo returnType, const TypeInfo[] argumentTypes...) {
		this.selector = selector;
		this.implementation = implementation;
		this.returnType = returnType;
		this.argumentTypes = argumentTypes;
	}
	
	bool opEquals (const Method m) const {
		return this.selector == m.selector && this.returnType == m.returnType && this.argumentTypes == m.argumentTypes && this.implementation == m.implementation;
	}
}

/* Basic OO types */
class Class : id {
public:
	Class superclass;
	immutable string name;
	
	this (string name, Class superclass = null, bool allocIsa = true) {
		if (allocIsa) {
			isa = new Class("Class", null, false);
			isa.isa = isa;
			if (superclass)
				isa.superclass = superclass.isa;
		}
		
		this.superclass = superclass;
		this.name = name;
	}
	
	/* Reflection */
	bool addMethod(T, A...)(SEL name, T function (id, SEL, A) impl) {
		debug {
			//writefln("adding method %s to %s", name, this.name);
		}
		
		if (name in methods)
			return false;
		else {
			methods[name] = Method.define(name, impl);
			return true;
		}
	}
	
	void addProtocol (immutable Protocol p) {
		protocols ~= p;
	}
	
	Method replaceMethod(T, A...)(SEL name, T function (id, SEL, A) impl) {
		Method* ret = name in methods;
		methods[name] = Method.define(name, impl);
		if (ret)
			return *ret;
		else
			return null;
	}
	
	/* Iteration over a class hierarchy */
	int opApply (int delegate (ref Class) dg) {
		Class cls = this;
		int result = 0;
		do {
			result = dg(cls);
			if (result)
				break;
			
			cls = cls.superclass;
		} while (cls !is null);
		
		return result;
	}
	
	int opApply (int delegate (ref const(Class)) dg) const {
		const(Class)* cls = &this;
		int result = 0;
		do {
			result = dg(*cls);
			if (result)
				break;
			
			cls = &cls.superclass;
		} while (*cls !is null);
		
		return result;
	}
	
	// helps with debugging
	override string toString () const {
		return name;
	}

package:
	Method[SEL] methods;
	immutable(Protocol)[] protocols;
	
    bool hasMethod (SEL name) const {
        return !!(name in methods);
    }
}

class Instance : id {
	~this () {
		this.msgSend!(void)("finalize");
	}
}

immutable class Protocol {
public:
	immutable Method[] requiredMethods;
	immutable Method[] optionalMethods;
	
	this (immutable Method[] requiredMethods, immutable Method[] optionalMethods) {
		this.requiredMethods = requiredMethods;
		this.optionalMethods = optionalMethods;
	}
	
	bool conformsToProtocol (immutable Protocol other) immutable {
		// to conform to 'other', we must require at least all the methods it does
		foreach (immutable Method otherMethod; other.requiredMethods) {
			bool found = false;
			foreach (immutable Method myMethod; this.requiredMethods) {
				if (myMethod == otherMethod) {
					found = true;
					break;
				}
			}
			
			if (!found)
				return false;
		}
		
		return true;
	}
	
	bool opEquals (immutable Protocol other) immutable {
		return this.requiredMethods == other.requiredMethods && this.optionalMethods == other.optionalMethods;
	}
}
