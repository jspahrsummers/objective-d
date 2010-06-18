import objd.runtime;
import std.stdio;

@class ODObject {
	
}

+ (Class)class {
	return cast(Class)self;
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

@class MyClass : ODObject {}
@end

void main () {
	assert(MyClass.msgSend!Class(sel_registerName("class")) is MyClass);
	assert(MyClass.msgSend!bool(sel_registerName("isSubclassOfClass:"), ODObject));
	
	id obj = MyClass.msgSend!id(sel_registerName("new"));
	assert(obj !is null);
	assert(obj.msgSend!bool(sel_registerName("isKindOfClass:"), ODObject));
	assert(obj.msgSend!bool(sel_registerName("isKindOfClass:"), MyClass));
	assert(!obj.msgSend!bool(sel_registerName("isMemberOfClass:"), ODObject));
	assert(obj.msgSend!bool(sel_registerName("isMemberOfClass:"), MyClass));
}
