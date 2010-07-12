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
static import objd.objc;
import core.memory;
import objd.hash;
import std.c.stdlib;
import std.contracts;
import std.stdio;
import std.string;
import std.traits;

enum RUNTIME_MAJOR_VERSION = 0;
enum RUNTIME_MINOR_VERSION = 1;
enum RUNTIME_PATCH_VERSION = 0;
enum RUNTIME_VERSION = RUNTIME_MAJOR_VERSION.stringof ~ "." ~ RUNTIME_MINOR_VERSION.stringof ~ "." ~ RUNTIME_PATCH_VERSION.stringof;

/* Selectors */
private __gshared SelectorSet!(immutable string) mappedSelectors;

string sel_getName (SEL aSelector) {
	return mappedSelectors.get(aSelector);
}

void sel_preloadMapping (string[SEL] map) {
	foreach (key, value; map) {
		assert(key != 0, "selector 0 is reserved");
		assert(value !is null && value.length > 0, "string not provided for mapped selector");
		
		bool result = mappedSelectors.add(key, value);
		debug {
			assert(result || mappedSelectors.get(key) == value, "selector in preloaded map has already been mapped to a different string");
		}
		
		debug {
			//writefln("mapped %s to %s", value, key);
		}
	}
}

SEL sel_registerName (string str)
in {
	assert(str !is null && str.length > 0);
} body {
	debug {
		//writefln("registering selector %s", str);
	}

	auto hash = murmur_hash(str);
	
	// selector 0 is reserved
	if (hash == 0)
		hash = 1;
	
	debug {
		foreach (key, value; mappedSelectors) {
			if (value == str) {
				if (key != hash)
					writefln("warning: mapped selector for \"%s\" already exists as %s, but hash %s doesn't match", value, key, hash);
				
				return key;
			}
		}
	}
	
	mappedSelectors.add(hash, str);
	return hash;
}

/* Messaging */
class Method {
public:
	immutable SEL selector;
	immutable TypeInfo returnType;
	immutable TypeInfo[] argumentTypes;
	immutable IMP implementation;
	
	static Method define(T, A...)(SEL selector, T function (id, SEL, A) impl) {
		TypeInfo[] argTypes = new TypeInfo[A.length];
		foreach (i, type; A)
			argTypes[i] = typeid(Unqual!(OriginalType!type));
		
		return new Method(selector, cast(immutable IMP)(impl), cast(immutable)(typeid(Unqual!(OriginalType!T))), assumeUnique(argTypes));
	}
	
	this (immutable SEL selector, immutable IMP implementation, immutable TypeInfo returnType, immutable TypeInfo[] argumentTypes...) {
		this.selector = selector;
		this.implementation = implementation;
		this.returnType = returnType;
		this.argumentTypes = argumentTypes;
	}
	
	bool opEquals (ref const Method m) const {
		return this.selector == m.selector && this.returnType == m.returnType && this.argumentTypes == m.argumentTypes;
	}
	
	override string toString () const {
		return format("<Method: @selector(%s) = %s>", (selector != 0 ? sel_getName(selector) : ""), selector);
	}
}

/* Basic OO types */
package enum METHOD_CACHE_SIZE = 8;
package enum METHOD_CACHE_MASK = METHOD_CACHE_SIZE - 1;

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
		auto method = Method.define(name, impl);
		auto result = methods.add(name, method, false);
		debug {
			//writefln("%s method %s to %s", (result ? "added" : "failed to add"), method, this.name);
		}
		
		if (result)
			invalidateCache();
		
		return result;
	}
	
	void addProtocol (immutable Protocol p) {
		protocols ~= p;
	}
	
	bool conformsToProtocol (immutable Protocol aProtocol) const {
		foreach (const Class cls; this) {
			foreach (immutable Protocol p; cls.protocols) {
				if (p == aProtocol)
					return true;
			}
		}
		
		return false;
	}
	
	void replaceMethod(T, A...)(SEL name, T function (id, SEL, A) impl) {
		debug {
			//writefln("replacing selector %s in %s", name, this.name);
		}
		
		methods.add(name, Method.define(name, impl), true);
		invalidateCache();
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
	
	override string toString () const {
		return name;
	}

public:
	SelectorSet!(Method) methods;
	Method[METHOD_CACHE_SIZE] cachedMethods;
	
	immutable(Protocol)[] protocols;
	
	bool hasMethod (SEL name) const {
		return methods.get(name) !is null;
	}
	
	void invalidateCache () {
		foreach (i; 0 .. METHOD_CACHE_SIZE)
			// fill with dummy methods to speed up cache checks
			cachedMethods[i] = new Method(0, null, null, null);
	}
}

class Instance : id {
// TODO: implement "finalize"
}

version (unsafe) {
	enum SAFETY_DEFAULT = false;
} else {
	enum SAFETY_DEFAULT = true;
}

version (objc_compat) {
	objd.objc.ObjCType!T objd_msgSend(T, bool superSend = false, U : objd.objc.id, bool safe = false, A...)(U self, SEL cmd, A args)
	in {
		assert(self !is null);
	} body {
		static assert(superSend == false, "Objective-C messages should never get sent to super");
	
		return objd.objc.msgSend!(T, false, A)(self, cmd, args);
	}
}

T objd_msgSend(T, bool superSend = false, U, bool safe = SAFETY_DEFAULT, A...)(U self, SEL cmd, A args) {
	if (self is null) {
		static if (is(T == void))
			return;
		else
			return T.init;
	}

	version (objc_compat) {
		// the more specialized template should catch statically-typed ObjC objects
		debug {
			enforce(cast(objd.objc.id)self is null, "objd_msgSend() invoked with wrapped Objective-C object");
		}
	}
	
	assert(cmd != 0);
	
	static if (superSend)
		Class cls = self.isa.superclass;
	else
		Class cls = self.isa;
	
	assert(cls !is null);
	
	debug {
		//writefln("invoking method %s with return type %s", cmd, typeid(T));
	}
	
	enum slot = cmd & METHOD_CACHE_MASK;
	auto method = cls.cachedMethods[slot];
	debug {
		//writefln("cached methods: %s", cls.cachedMethods);
	}
	
	if (method.selector != cmd) {
		do {
			method = cls.methods.get(cmd);
			if (method !is null) {
				cls.cachedMethods[slot] = method;
				goto invoke;
			}
			
			cls = cls.superclass;
		} while (cls !is null);
		
		debug {
			writefln("couldn't find method %s", cmd);
		}
		
		auto doesNotRecognize = sel_registerName("doesNotRecognizeSelector:");
		if (cmd != doesNotRecognize) {
			objd_msgSend!(void)(self, doesNotRecognize, cmd);
		
			static if (is(T == void))
				return;
			else
				return T.init;
		}
		
		abort();
		assert(0);
	}
	
invoke:
	// the safety checks below should always remain in release builds
	// dynamic programming languages become dangerous without typechecking
	
	static if (safe) {
		enforce(TypeInfoConvertibleToType!T(method.returnType), format("requested return type %s does not match defined return type %s for method %s", typeid(T), method.returnType, cmd));
		enforce(A.length == method.argumentTypes.length, format("number of arguments to method %s (%s) does not match %s defined parameters", cmd, A.length, method.argumentTypes.length));
		
		foreach (i, type; A) {
			debug {
				//writefln("checking type %s against argument %s", type.stringof, i);
			}
			
			enforce(TypeConvertibleToTypeInfo!type(method.argumentTypes[i]), format("argument %s of type %s does not match defined parameter type %s for method %s", i + 1, typeid(type), method.argumentTypes[i], sel_getName(cmd)));
		}
	}
	
	auto impl = cast(T function (id, SEL, A))(method.implementation);
	static if (is(T == void))
		impl(self, cmd, args);
	else
		return impl(self, cmd, args);
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
		if (this is other)
			return true;
	
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
		return this is other || (this.requiredMethods == other.requiredMethods && this.optionalMethods == other.optionalMethods);
	}
}
