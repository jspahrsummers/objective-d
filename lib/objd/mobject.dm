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
