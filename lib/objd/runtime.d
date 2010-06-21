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
import objd.hashset;
import objd.hashtable;
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
private __gshared HashSet!SEL mappedSelectors;

static this () {
	mappedSelectors = new typeof(mappedSelectors);
}

string sel_getName (SEL aSelector) {
	return aSelector.name;
}

void sel_preloadMapping (string[hash_value] map) {
	// preallocate enough space
	mappedSelectors.capacity = mappedSelectors.length + map.length;

	foreach (key, value; map) {
		assert(value !is null && value.length > 0);
		
		auto selector = SEL(value, key);
		debug {
			auto existing = mappedSelectors.get(selector);
			enforce(existing is null || (*existing).name == value, "selector in preloaded map has already been mapped to a different string");
		}
		
		mappedSelectors.add(selector);
	}
}

SEL sel_registerName (string str)
in {
	assert(str !is null && str.length > 0);
} body {
	debug {
		writefln("registering selector %s", str);
	}

	return mappedSelectors.add(SEL(str));
}

/* Messaging */
class Method {
public:
	immutable SEL selector;
	
	version (unsafe) {}
	else {
		immutable TypeInfo[] types;
	}
	
	immutable IMP implementation;
	
	static Method define(T, A...)(SEL selector, T function (id, SEL, A) impl) {
		version (unsafe) {
			return new Method(selector, cast(immutable IMP)(impl));
		} else {
			TypeInfo[] types = new TypeInfo[A.length + 1];
			
			types[0] = typeid(Unqual!(OriginalType!T));
			foreach (i, type; A)
				types[i + 1] = typeid(Unqual!(OriginalType!type));
			
			return new Method(selector, cast(immutable IMP)(impl), assumeUnique(types));
		}
	}
	
	this (immutable SEL selector, immutable IMP implementation, immutable TypeInfo[] types...) {
		this.selector = selector;
		this.implementation = implementation;
		
		version (unsafe) {}
		else {
			this.types = types;
		}
	}
	
	override bool opEquals (Object obj) {
		auto m = cast(typeof(this))obj;
		if (m is null)
			return false;
	
		bool eq = this.selector == m.selector && this.implementation == m.implementation;
		version (unsafe) {}
		else {
			eq &= (this.types == m.types);
		}
		
		return eq;
	}
	
	version (unsafe) {}
	else {
		@property immutable(TypeInfo) returnType () const {
			return types[0];
		}
		
		@property immutable(TypeInfo)[] argumentTypes () const {
			if (types.length > 1)
				return types[1 .. $];
			else
				return [];
		}
	}
	
	override string toString () const {
		return format("<Method: @selector(%s) = %s>", sel_getName(selector), selector);
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
		this.methods = new typeof(methods);
		//this.cachedMethods = new typeof(cachedMethods)(METHOD_STARTING_CACHE_SIZE);
	}
	
	/* Reflection */
	bool addMethod(T, A...)(SEL name, T function (id, SEL, A) impl) {
		debug {
			writefln("adding selector %s to %s", name, this.name);
		}
		
		if (methods.contains(name))
			return false;
		
		methods.set(name, Method.define(name, impl));
		invalidateCache();
		return true;
	}
	
	void addProtocol (immutable Protocol p) {
		protocols ~= p;
	}
	
	void replaceMethod(T, A...)(SEL name, T function (id, SEL, A) impl) {
		debug {
			writefln("replacing selector %s in %s", name, this.name);
		}
		
		methods.set(name, Method.define(name, impl));
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
	HashTable!(SEL, Method) methods;
	//HashTable!(SEL, Method, true) cachedMethods;
	Method[METHOD_CACHE_SIZE] cachedMethods;
	
	immutable(Protocol)[] protocols;
	
	bool hasMethod (SEL name) const {
		return methods.contains(name);
	}
	
	void invalidateCache () {
		//cachedMethods.clear();
		foreach (i; 0 .. METHOD_CACHE_SIZE)
			cachedMethods[i] = null;
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

objd.objc.ObjCType!T objd_msgSend(T, U : objd.objc.id, A...)(U self, SEL cmd, A args)
in {
	assert(self !is null);
} body {
	return objd.objc.msgSend!(T, A)(self, cmd, args);
}

T objd_msgSend(T, U, A...)(U self, SEL cmd, A args)
in {
	assert(self !is null);
} body {
	// the more specialized template should catch statically-typed ObjC objects
	debug {
		enforce(cast(objd.objc.id)self is null, "objd_msgSend() invoked with wrapped Objective-C object");
	}
	
	Class cls = self.isa;
	assert(cls !is null);
	
	debug {
		//writefln("invoking method %s with return type %s", cmd, typeid(T));
	}
	
	//auto method = cls.cachedMethods.get(cmd);
	enum slot = cmd.hash & METHOD_CACHE_MASK;
	auto method = cls.cachedMethods[slot];
	debug {
		//writefln("cached methods: %s", cls.cachedMethods);
	}
	
	if (method is null || method.selector != cmd) {
		do {
			method = cls.methods.get(cmd);
			if (method !is null) {
				//cls.cachedMethods.set(cmd, method);
				cls.cachedMethods[slot] = method;
				goto invoke;
			}
			
			cls = cls.superclass;
		} while (cls !is null);
		
		debug {
			writefln("couldn't find method %s", cmd);
		}
		
		auto doesNotRecognize = sel_registerName("doesNotRecognizeSelector:");
		if (cmd == doesNotRecognize) {
			abort();
		} else {
			objd_msgSend!(void)(self, doesNotRecognize, cmd);
		}
		
		static if (is(T == void))
			return;
		else
			return T.init;
	}
	
invoke:
	// the safety checks below should always remain in release builds
	// dynamic programming languages become dangerous without typechecking
	
	version (unsafe) {}
	else {
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
