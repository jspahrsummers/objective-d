import std.stdio;
import objd;

Class MyClass;

static this () {
    MyClass = new Class("MyClass", NSObject);
}

void main () {
    id obj = MyClass.msgSend!(id)("alloc").msgSend!(id)("init");
    writefln("%s", obj.msgSend!(string)("description"));
    writefln("%s", MyClass.msgSend!(string)("description"));
}
