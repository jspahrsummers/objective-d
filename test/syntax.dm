// Objective-D test file
import std.stdio;
import objd.mobject;

@class MyClass : MObject {
	int test;
}

- (void)wordsCannot:(string)what inObjectiveC {
	++self.test;
}

+ (id)print:(string)a also:(string)b {
	return self;
}

- (int)nonIDReturnType {
	return 5;
}

@end

void main () {
	writeln("Testing Objective-D syntax...");
	
	writeln("--- Invoking [MyClass class] and checking for identity with the declared MyClass");
	assert([MyClass class] is MyClass);
	
	writeln("--- Invoking [[MyClass class] superclass] and checking for identity with MObject");
	assert([[MyClass class] superclass] is MObject);
	
	writeln("--- Invoking [MyClass superclass] and checking for identity with [[MyClass class] superclass]");
	assert([MyClass superclass] is [[MyClass class] superclass]);
	
	writeln("--- Invoking [MyClass new]");
	id obj = [MyClass new];
	assert(obj !is null);
	
	writeln("--- Invoking [obj class] and checking for identity with MyClass");
	assert([obj class] is MyClass);
	
	writeln("--- Sending message with a trailing word");
	[obj wordsCannot:"trail" inObjectiveC];
	
	writeln("--- Sending message with multiple arguments");
	auto cls = [MyClass print:"hello" also:"world"];
	assert(cls is MyClass);
	
	writeln("--- Validating returned value of method that does not return id");
	assert([obj nonIDReturnType] == 5);
	
	writefln("%s passed!", __FILE__);
}
