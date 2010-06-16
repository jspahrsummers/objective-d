module objd.objc;
static import objd.runtime;
import std.stdio;
import std.string;

private extern (System) {
	struct objc_selector {}

	alias objc_selector* ObjCSEL;
	alias void* ObjCId;
	
	/* Message sending */
	ObjCId objc_msgSend (ObjCId, ObjCSEL, ...);
	
	/* Reflection */
	ObjCId objc_getClass (const char* name);
	ObjCSEL sel_registerName (const char* name);
}

class Class : objd.runtime.Class {
public:
	this (string name) {
		super(name, null, false);
		
		ptr = objc_getClass(toStringz(name));
	}
	
	T msgSend(T, A...)(objd.runtime.SEL cmd, A args) {
		auto funcptr = &objc_msgSend;
		auto ret = funcptr(ptr, sel_registerName(toStringz(objd.runtime.sel_getName(cmd))), args);
		return cast(T)ret;
	}
	
package:
	ObjCId ptr;
}

class Instance : objd.runtime.Instance {
public:
	
}
