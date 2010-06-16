// Objective-D test file
import std.stdio;
import objd.nsobject;
import objc = objd.objc;

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

objc.Class NSString;
objc.Class NSAutoreleasePool;
static this () {
	NSAutoreleasePool = new objc.Class("NSAutoreleasePool");
	NSString = new objc.Class("NSString");
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

	writeln("testing Objective-C compatibility...");
	
	auto pool = cast(objc.id)[NSAutoreleasePool new];
	writefln("called [%s new] and got object %s", NSAutoreleasePool, pool);
	
	[pool drain];
}
