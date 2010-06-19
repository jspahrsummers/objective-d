module objd.nsobject;
import objd.runtime;
import std.c.stdlib;
import std.stdio;

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
	
	NSObject.addMethod(sel_registerName("hash"), function hash_t (id self, SEL cmd) {
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
