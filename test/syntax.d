// Objective-D test file
import std.stdio;

@class MyClass : NSObject {

}

//+ (id)copyAndPrint:(string)a also:(string)b {
//	writefln("self: %s", self);
//	writefln("self.class: %s", [self class]);
//	writefln("a: %s", a);
//	writefln("b: %s", b);
//	return self;
//}

@end

void main () {
	assert([MyClass class] is MyClass);
	assert([[MyClass class] superclass] is NSObject);
	
	id obj = [MyClass new];
	assert(obj !is null);
	assert([obj class] is MyClass);
	
	//[MyClass copyAndPrint:"hello" also:"world"];
	//MyClass.copyAndPrint_also_(MyClass, @selector(copyAndPrint:also:), "hello", "world");
	writeln("All tests passed!");
}
