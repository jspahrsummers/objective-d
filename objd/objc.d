module objd.objc;
static import objd.runtime;
static import objd.types;
import std.c.string;
import std.contracts;
import std.stdio;
import std.string;
import std.traits;

private extern (System) {
	alias void* objc_id;
	alias objc_id objc_Class;

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
		extern(C) objc_id function (objc_id, SEL, A) funcptr;
		funcptr = cast(typeof(funcptr))&objc_msgSend;
		
		auto ret = funcptr(ptr, sel_registerName(toStringz(objd.runtime.sel_getName(cmd))), args);
		return new typeof(this)(ret);
	}
	
	T msgSend(T, A...)(objd.types.SEL cmd, A args)
		if (!(is(T == objd.types.id) || is(T : id)))
	{
		extern(C) T function (objc_id, SEL, A) funcptr;
		funcptr = cast(typeof(funcptr))&objc_msgSend;
		
		static if (is(T == void))
			funcptr(ptr, sel_registerName(toStringz(objd.runtime.sel_getName(cmd))), args);
		else {
			auto ret = funcptr(ptr, sel_registerName(toStringz(objd.runtime.sel_getName(cmd))), args);
			return ret;
		}
	}
	
	override string toString () const {
		if (ptr is null)
			return "(null)";
		else if (isClass) {
			auto className = class_getName(cast(Unqual!(typeof(ptr)))ptr);
		
			auto len = strlen(className);
			auto name = new char[len + 1];
			strncpy(name.ptr, className, len);
			name[len] = '\0';
			
			return assumeUnique(name);
		} else {
			auto className = object_getClassName(cast(Unqual!(typeof(ptr)))ptr);
		
			auto len = strlen(className);
			auto name = new char[len + 1];
			strncpy(name.ptr, className, len);
			name[len] = '\0';
			
			return format("<%s: %#x>", name, cast(const void*)this);
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

string stringFromNSString (id str) {
	auto bytes = str.msgSend!(const(char)*)(objd.runtime.sel_registerName("UTF8String"));
	auto len = strlen(bytes);
	
	auto newStr = new char[len + 1];
	strncpy(newStr.ptr, bytes, len);
	newStr[len] = '\0';
	
	return assumeUnique(newStr);
}
