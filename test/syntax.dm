// Objective-D test file
import std.stdio;
static import objd.object;

@class MyClass : objd.object.Object {
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

- (int)nonIDReturnType {
	return 5;
}

@end

void main () {
	assert([MyClass class] is MyClass);
	assert([[MyClass class] superclass] is objd.object.Object);
	
	id obj = [MyClass new];
	assert(obj !is null);
	assert([obj class] is MyClass);
	
	[obj wordsCannot:"trail" inObjectiveC];
	
	auto cls = [MyClass print:"hello" also:"world"];
	assert(cls is MyClass);
	
	assert([obj nonIDReturnType] == 5);
}
