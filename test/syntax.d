// Objective-D test file
import std.stdio;
static import objd.objc;

@class MyClass : NSObject {
	int test;
}

- (void)wordsCannot:(string)what inObjectiveC {
	++self.test;
}

+ (id)print:(string)a also:(string)b {
	writefln("self: %s", self);
	writefln("self.class: %s", [self class]);
	writefln("a: %s", a);
	writefln("b: %s", b);
	return self;
}

@end

objd.objc.ObjCClass NSString;
objd.objc.ObjCClass NSAutoreleasePool;
static this () {
	NSAutoreleasePool = new objd.objc.ObjCClass("NSAutoreleasePool");
	NSString = new objd.objc.ObjCClass("NSString");
}

void main () {
	assert([MyClass class] is MyClass);
	assert([[MyClass class] superclass] is NSObject);
	
	id obj = [MyClass new];
	assert(obj !is null);
	assert([obj class] is MyClass);
	
	[obj wordsCannot:"trail" inObjectiveC];
	[obj wordsCannot:"trail" inObjectiveC];
	[obj wordsCannot:"trail" inObjectiveC];
	
	auto inst = cast(MyClassInst)(obj);
	assert(inst.test == 3);
	
	auto cls = [MyClass print:"hello" also:"world"];
	assert(cls is MyClass);
	
	auto pool = [NSAutoreleasePool new];
	[NSString string];
	//[pool drain];
}
