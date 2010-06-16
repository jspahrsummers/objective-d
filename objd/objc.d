module objd.objc;
static import objd.runtime;
import objd.types;
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

alias ObjCObject Class;

class ObjCObject : id {
public:
	this (string className) {
		//super(className, null, false);
		
		ptr = objc_getClass(toStringz(className));
	}
	
	T msgSend(T, A...)(objd.runtime.SEL cmd, A args) {
		static if (is(T == id) || is(T : ObjCObject)) {
			extern(C) ObjCId function (ObjCId, ObjCSEL, A) funcptr;
			funcptr = cast(typeof(funcptr))&objc_msgSend;
			
			auto ret = funcptr(ptr, sel_registerName(toStringz(objd.runtime.sel_getName(cmd))), args);
			return new ObjCObject(ret);
		} else {
			extern(C) T function (ObjCId, ObjCSEL, A) funcptr;
			funcptr = cast(typeof(funcptr))&objc_msgSend;
			
			static if (is(T == void))
				funcptr(ptr, sel_registerName(toStringz(objd.runtime.sel_getName(cmd))), args);
			else {
				auto ret = funcptr(ptr, sel_registerName(toStringz(objd.runtime.sel_getName(cmd))), args);
				return ret;
			}
		}
	}
	
package:
	ObjCId ptr;
	
	this (ObjCId ptr) {
		this.ptr = ptr;
	}
}
