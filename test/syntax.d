// Objective-D test file
import std.stdio;

@class MyClass : NSObject {
	int test;
}

- (void)methodTest {
	writefln("test");
}

- (bool)wordsCannot:(string)what inObjectiveC {
	return true;
}

+ (id)copyAndPrint:(string)a also:(string)b {
	writefln("self: %s", self);
	writefln("self.class: %s", [self class]);
	writefln("a: %s", a);
	writefln("b: %s", b);
	return self;
}

@end

void main () {
	assert([MyClass class] is MyClass);
	assert([[MyClass class] superclass] is NSObject);
	
	id obj = [MyClass new];
	assert(obj !is null);
	assert([obj class] is MyClass);
	
	[obj methodTest];
	[obj wordsCannot:"trail" inObjectiveC];
	[MyClass copyAndPrint:"hello" also:"world"];
	writeln("All tests passed!");
}
