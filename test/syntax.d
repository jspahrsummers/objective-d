// Objective-D test file
import std.stdio;
import objd.nsobject;

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

@objc NSString;
@objc NSAutoreleasePool;

void main () {
	assert([MyClass class] is MyClass);
	assert([[MyClass class] superclass] is NSObject);
	
	id obj = [MyClass new];
	assert(obj !is null);
	assert([obj class] is MyClass);
	
	[obj wordsCannot:"trail" inObjectiveC];
	
	auto cls = [MyClass print:"hello" also:"world"];
	assert(cls is MyClass);

	writeln("testing Objective-C compatibility...");
	
	auto pool = [NSAutoreleasePool new];
	writefln("[pool class] = %s", [pool class]);
	
	auto str = [[NSString alloc] init];
	auto str2 = [[[NSString alloc] init] autorelease];
	writefln("created two %s objects: %s, %s", NSString, str, str2);
	
	// this will invoke isEqual:
	assert(str == str2);
	
	[str release];
	[pool drain];
}
