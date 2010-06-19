/*
 * Objective-C compatibility layer test
 */

import std.stdio;

@objc NSAutoreleasePool;
@objc NSString;

void main () {
	writeln("Testing Objective-C compatibility...");
	
	writeln("--- Invoking [NSAutoreleasePool new]");
	auto pool = [NSAutoreleasePool new];
	assert(pool !is null);
	
	// this won't work just comparing the result (TODO: it could)
	// Objective-C objects are always wrapped in new D objects
	assert([pool class].toString() == "NSAutoreleasePool");
	
	writeln("--- Invoking [[NSString alloc] init]");
	auto str = [[NSString alloc] init];
	assert(str !is null);
	
	writeln("--- Invoking [[NSString new] autorelease]");
	auto str2 = [[NSString new] autorelease];
	assert(str2 !is null);
	
	assert(str !is str2);
	
	// this will invoke isEqual:
	writeln("--- Testing NSString equality with isEqual:");
	assert(str == str2);
	
	writeln("--- Releasing NSString object");
	[str release];
	
	writeln("--- Draining NSAutoreleasePool");
	[pool drain];
	
	writefln("%s passed!", __FILE__);
}
