import std.stdio;
import objd;

Class MyClass;

static this () {
    MyClass = new Class("MyClass", NSObject);
}

void main () {
    id obj = MyClass.msgSend!(id)("new");
    writefln("%s", obj.msgSend!(string)("description", 1));
    writefln("%s", MyClass.msgSend!(string)("description"));
}
