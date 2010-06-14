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
    
    MyClass.addMethod(@selector(copyAndPrint:also:), function id (id self, SEL cmd, string a, string b) {
        writefln("a: %s", a);
        writefln("b: %s", b);
        return self;
    });
    
    [obj copyAndPrint:"hello" also:"world"];
    writeln("All tests passed!");
}
