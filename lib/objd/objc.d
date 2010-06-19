module objd.objc;
static import objd.runtime;
static import objd.types;
import std.c.string;
import std.contracts;
import std.stdio;
import std.string;
import std.traits;

extern (System) {
	/* Cross-platform definitions */
	invariant YES = true;
	invariant NO = false;

	// these types are unsafe as defined in Objective-C
	// Objective-D provides an id wrapper (below) which can be used normally
	alias void* objc_id;
	alias objc_id objc_Class;
	
	/* Platform-specific definitions */
	version (darwin) {
		/* Basic types */
		alias int NSInteger;
		alias uint NSUInteger;
		alias int BOOL;
	
		/* Selectors */
		struct objc_selector {}
		alias objc_selector* SEL;
		
		/* Message sending */
		objc_id objc_msgSend (objc_id, SEL, ...);
		
		/* Reflection */
		const(char)* class_getName (objc_Class);
		objc_id objc_getClass (const char*);
		const(char)* object_getClassName (objc_id);
		SEL sel_registerName (const char*);
	}
	
	// internal template used to cast objc_msgSend to the correct type
	private template FuncPtr(R, A...) {
		alias R function (A...) FuncPtr;
	}
}

alias id Class;

class id : objd.types.id {
public:
	this (string className) {
		this.ptr = objc_getClass(toStringz(className));
		this.isClass = true;
	}
	
	typeof(this) msgSend(T, A...)(objd.types.SEL cmd, A args)
		if (is(T == objd.types.id) || is(T : id))
	{
		auto funcptr = cast(FuncPtr!(objc_id, objc_id, SEL, A))&objc_msgSend;
		
		auto ret = funcptr(ptr, sel_registerName(toStringz(objd.runtime.sel_getName(cmd))), args);
		return new typeof(this)(ret);
	}
	
	T msgSend(T, A...)(objd.types.SEL cmd, A args)
		if (!(is(T == objd.types.id) || is(T : id)))
	{
		auto funcptr = cast(FuncPtr!(T, objc_id, SEL, A))&objc_msgSend;
		
		static if (is(T == void))
			funcptr(ptr, sel_registerName(toStringz(objd.runtime.sel_getName(cmd))), args);
		else {
			auto ret = funcptr(ptr, sel_registerName(toStringz(objd.runtime.sel_getName(cmd))), args);
			return ret;
		}
	}
	
	override bool opEquals (Object other) const {
		auto obj = cast(id)other;
		if (obj is null)
			return false;
		
		auto deconsted = cast(Unqual!(typeof(this)))this;
		return cast(bool)deconsted.msgSend!(BOOL)(objd.runtime.sel_registerName("isEqual:"), obj.ptr);
	}
	
	// though the "description" method is rather portable, NSString probably isn't
	version (darwin) {
		override string toString () const {
			if (ptr is null)
				return "(null)";
			else {
				auto deconsted = cast(Unqual!(typeof(this)))this;
				return stringFromNSString(deconsted.msgSend!(id)(objd.runtime.sel_registerName("description")));
			}
		}
	}
	
package:
	objc_id ptr;
	immutable bool isClass;
	
	this (objc_id ptr) {
		this.ptr = ptr;
		this.isClass = false;
	}
}

// NSString probably isn't very portable
version (darwin) {
	string stringFromNSString (id str) {
		if (str is null || str.ptr is null)
			return "(null)";
	
		auto bytes = str.msgSend!(const(char)*)(objd.runtime.sel_registerName("UTF8String"));
		auto len = strlen(bytes);
		
		auto newStr = new char[len];
		strncpy(newStr.ptr, bytes, len);
		return assumeUnique(newStr);
	}
}
