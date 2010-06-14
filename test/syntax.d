// Objective-D test file
import std.stdio;

@class MyClass : NSObject {

}

@end

void main () {
    assert([MyClass class] is MyClass);
    assert([[MyClass class] superclass] is NSObject);
    
    id obj = [MyClass new];
    assert(obj !is null);
    assert([obj class] is MyClass);
    
    writeln("All tests passed!");
}
