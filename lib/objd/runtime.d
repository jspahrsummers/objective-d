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
import core.memory;
import objd.hashset;
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
private HashSet!(immutable string) mappedSelectors;

static this () {
	mappedSelectors = new typeof(mappedSelectors)();
}

string sel_getName (SEL aSelector) {
	return mappedSelectors.get(aSelector);
}

void sel_preloadMapping (string[SEL] map) {
	foreach (key, value; map) {
		assert(value !is null && value.length > 0);
		
		debug {
			auto existing = mappedSelectors.get(key);
			enforce(existing is null || existing == value, "selector in preloaded map has already been mapped to a different string");
		}
		
		mappedSelectors.put(value, key);
	}
}

SEL sel_registerName (string str)
in {
	assert(str !is null && str.length > 0);
} body {
	debug {
		writefln("registering selector %s", str);
	}

	auto hash = murmur_hash(str);
	
	debug {
		foreach (key, value; mappedSelectors) {
			if (value == str) {
				enforce(key == hash, "mapped selector already exists, but hash is incorrect");
				return key;
			}
		}
	}
	
	return mappedSelectors.put(str, hash);
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
			argTypes[i] = typeid(OriginalType!(type));
		
		return new Method(selector, cast(immutable IMP)(impl), cast(immutable)(typeid(Unqual!(OriginalType!T))), assumeUnique(argTypes));
	}
	
	this (immutable SEL selector, immutable IMP implementation, immutable TypeInfo returnType, immutable TypeInfo[] argumentTypes...) {
		this.selector = selector;
		this.implementation = implementation;
		this.returnType = returnType;
		this.argumentTypes = argumentTypes;
	}
	
	bool opEquals (const Method m) const {
		return this.selector == m.selector && this.returnType == m.returnType && this.argumentTypes == m.argumentTypes && this.implementation == m.implementation;
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
	}
	
	/* Reflection */
	bool addMethod(T, A...)(SEL name, T function (id, SEL, A) impl) {
		debug {
			writefln("adding selector %s to %s", name, this.name);
		}
		
		if (methods.get(name) !is null)
			return false;
		else {
			methods.put(Method.define(name, impl), name);
			invalidateCache();
			return true;
		}
	}
	
	void addProtocol (immutable Protocol p) {
		protocols ~= p;
	}
	
	Method replaceMethod(T, A...)(SEL name, T function (id, SEL, A) impl) {
		debug {
			writefln("replacing selector %s in %s", name, this.name);
		}
		
		methods.remove(name);
		
		auto method = Method.define(name, impl);
		methods.put(method, name);
		invalidateCache();
		return method;
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

package:
	HashSet!(Method) methods;
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

T objd_msgSend(T, U : objd.objc.id, A...)(U self, SEL cmd, A args)
in {
	assert(self !is null);
} body {
	return objd.objc.msgSend!(T, A)(self, cmd, args);
}

T objd_msgSend(T, U, A...)(U self, SEL cmd, A args)
in {
	assert(self !is null);
} body {
	// the more specialized template will catch statically-typed ObjC objects
	static if (!is(U : objd.objc.id)) {
		version (unsafe) {
		} else {
			auto objc = cast(objd.objc.id)self;
			if (objc !is null)
				return objd.objc.msgSend!(T, A)(objc, cmd, args);
		}
	}
	
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
			method = cast(Method)cls.methods.get(cmd);
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
	
	version (unsafe) {
	} else {
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
