module objd.runtime;
import std.algorithm;
import std.c.stdlib;
import std.contracts;
import std.stdio;
import std.string;
import std.traits;

/* Basic types */
alias int NSInteger;
alias uint NSUInteger;
alias bool BOOL;

invariant YES = true;
invariant NO = false;

/* Selectors */
alias string SEL;

string sel_getName (SEL aSelector) {
	return aSelector;
}

SEL sel_registerName (string str) {
	return str;
}

/* Messaging */
alias int function(id, SEL, ...) IMP;

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
class id {
public:
	Class isa;
	
	T msgSend(T, A...)(SEL cmd, A args) {
		Class cls = isa;
		
		Method method = null;
		writefln("invoking method %s", cmd);
		do {
			auto item = cmd in cls.methods;
			if (item) {
				method = *item;
				break;
			}
			
			cls = cls.superclass;
		} while (cls !is null);
		
		if (!method) {
			writefln("couldn't find method %s", cmd);
			auto doesNotRecognize = sel_registerName("doesNotRecognizeSelector:");
			if (cmd == doesNotRecognize) {
				abort();
			} else {
				this.msgSend!(void)(doesNotRecognize, cmd);
			}
			
			static if (is(T == void))
				return;
			else
				return T.init;
		}
		
		//enforce(typeid(T) == method.returnType, format("requested return type %s does not match defined return type %s for method %s", typeid(T), method.returnType, method.selector));
		enforce(A.length == method.argumentTypes.length, format("number of arguments to method %s (%s) does not match %s defined parameters", method.selector, A.length, method.argumentTypes.length));
		
		foreach (i, type; A) {
			enforce(typeid(type) == method.argumentTypes[i] || typeid(const type) == method.argumentTypes[i], format("argument %s of type %s does not match defined parameter type %s for method %s", i + 1, typeid(type), method.argumentTypes[i], method.selector));
		}
		
		auto impl = cast(T function (id, SEL, A))(method.implementation);
		static if (is(T == void))
			impl(this, cmd, args);
		else
			return impl(this, cmd, args);
	}
	
	override string toString () const {
		return isa.name;
	}
}

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
		writefln("adding method %s to %s", name, this.name);
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

private:
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

/* Root object */
Class NSObject;

static this () {
	NSObject = new Class("NSObject");
	
	/* NSObject class methods */
	NSObject.isa.addMethod(sel_registerName("alloc"), function id (id self, SEL cmd) {
		id obj = new Instance;
		obj.isa = cast(Class)self;
		return obj;
	});
	
	NSObject.isa.addMethod(sel_registerName("class"), function Class (id self, SEL cmd) {
		return cast(Class)self;
	});
	
	NSObject.isa.addMethod(sel_registerName("conformsToProtocol:"), function bool (id self, SEL cmd, immutable Protocol aProtocol) {
		foreach (p; (cast(Class)self).protocols) {
			if (p == aProtocol)
				return true;
		}
		
		return false;
	});
	
	NSObject.isa.addMethod(sel_registerName("description"), function string (id self, SEL cmd) {
		return self.isa.name;
	});
	
	NSObject.isa.addMethod(sel_registerName("doesNotRecognizeSelector:"), function void (id self, SEL cmd, SEL aSelector) {
		writefln("%s does not recognize selector \"%s\"", self.isa, sel_getName(aSelector));
		abort();
	});
	
	NSObject.isa.addMethod(sel_registerName("instancesRespondToSelector:"), function bool (id self, SEL cmd, SEL aSelector) {
		foreach (Class cls; cast(Class)self) {
			if (cls.hasMethod(aSelector))
				return true;
		}
		
		return false;
	});
	
	NSObject.isa.addMethod(sel_registerName("isSubclassOfClass:"), function bool (id self, SEL cmd, const Class otherClass) {
		foreach (const Class cls; cast(Class)self) {
			if (cls == otherClass)
				return true;
		}
		
		return false;
	});
	
	NSObject.isa.addMethod(sel_registerName("new"), function id (id self, SEL cmd) {
		return self.msgSend!(id)("alloc").msgSend!(id)("init");
	});
	
	NSObject.isa.addMethod(sel_registerName("superclass"), function Class (id self, SEL cmd) {
		return (cast(Class)self).superclass;
	});
	
	/* NSObject instance methods */
	NSObject.addMethod(sel_registerName("description"), function string (id self, SEL cmd) {
		return self.isa.name;
	});
	
	NSObject.addMethod(sel_registerName("class"), function Class (id self, SEL cmd) {
		return self.isa;
	});
	
	NSObject.addMethod(sel_registerName("conformsToProtocol:"), function bool (id self, SEL cmd, immutable Protocol aProtocol) {
		return self.isa.msgSend!(typeof(return))(cmd, aProtocol);
	});
	
	NSObject.addMethod(sel_registerName("doesNotRecognizeSelector:"), function void (id self, SEL cmd, SEL aSelector) {
		writefln("%s does not recognize selector \"%s\"", self.isa, sel_getName(aSelector));
		abort();
	});
	
	NSObject.addMethod(sel_registerName("finalize"), function void (id self, SEL cmd) {});
	
	NSObject.addMethod(sel_registerName("hash"), function NSUInteger (id self, SEL cmd) {
		return self.toHash();
	});
	
	NSObject.addMethod(sel_registerName("init"), function id (id self, SEL cmd) {
		return self;
	});
	
	NSObject.addMethod(sel_registerName("isEqual:"), function bool (id self, SEL cmd, const id otherObj) {
		return self == otherObj;
	});
	
	NSObject.addMethod(sel_registerName("isKindOfClass:"), function bool (id self, SEL cmd, const Class otherClass) {
		foreach (const Class cls; self.isa) {
			if (cls == otherClass)
				return true;
		}
		
		return false;
	});
	
	NSObject.addMethod(sel_registerName("isMemberOfClass:"), function bool (id self, SEL cmd, const Class otherClass) {
		return self.isa == otherClass;
	});
	
	NSObject.addMethod(sel_registerName("isProxy"), function bool (id self, SEL cmd) {
		return false;
	});
	
	NSObject.addMethod(sel_registerName("respondsToSelector:"), function bool (id self, SEL cmd, SEL aSelector) {
		foreach (const Class cls; self.isa) {
			if (cls.hasMethod(aSelector))
				return true;
		}
		
		return false;
	});
	
	NSObject.addMethod(sel_registerName("self"), function id (id self, SEL cmd) {
		return self;
	});
	
	NSObject.addMethod(sel_registerName("superclass"), function Class (id self, SEL cmd) {
		return self.isa.superclass;
	});
}

unittest {
	Class MyClass = new Class("MyClass", NSObject);
	assert(MyClass.msgSend!Class(sel_registerName("class")) is MyClass);
	assert(MyClass.msgSend!bool(sel_registerName("isSubclassOfClass:"), NSObject));
	
	id obj = MyClass.msgSend!id(sel_registerName("new"));
	assert(obj !is null);
	assert(obj.msgSend!bool(sel_registerName("isKindOfClass:"), NSObject));
	assert(obj.msgSend!bool(sel_registerName("isKindOfClass:"), MyClass));
	assert(!obj.msgSend!bool(sel_registerName("isMemberOfClass:"), NSObject));
	assert(obj.msgSend!bool(sel_registerName("isMemberOfClass:"), MyClass));
}
