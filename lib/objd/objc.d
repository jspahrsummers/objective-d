/*
 * objc.d
 * Objective-D compatibility layer for Objective-C
 *
 * Copyright (c) 2010 Justin Spahr-Summers <Justin.SpahrSummers@gmail.com>
 * 
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

module objd.objc;
static import objd.runtime;
static import objd.types;
import objd.hash;
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
		debug {
			this.className = className;
		}
	
		this.ptr = objc_getClass(toStringz(className));
		this.isClass = true;
	}
	
	override bool opEquals (Object other) const {
		auto obj = cast(id)other;
		if (obj is null)
			return false;
		
		return cast(bool)msgSend!(BOOL)(cast(Unqual!(typeof(this)))this, objd.runtime.sel_registerName("isEqual:"), obj.ptr);
	}
	
	// though the "description" method is rather portable, NSString probably isn't
	version (darwin) {
		override string toString () const {
			if (ptr is null)
				return "(null)";
			else
				return stringFromNSString(msgSend!(id)(cast(Unqual!(typeof(this)))this, objd.runtime.sel_registerName("description")));
		}
	}
	
package:
	objc_id ptr;
	immutable bool isClass;
	
	debug {
		string className;
	}
	
	this (objc_id ptr) {
		this.ptr = ptr;
		this.isClass = false;
	}
}

ObjCType!T msgSend(T, A...)(id self, objd.types.SEL cmd, A args) {
	static if (is(T == objd.types.id) || is(T : id)) {
		auto funcptr = cast(FuncPtr!(objc_id, objc_id, SEL, A))&objc_msgSend;
		
		auto ret = funcptr(self.ptr, sel_registerName(toStringz(objd.runtime.sel_getName(cmd))), args);
		return new id(ret);
	} else {
		auto funcptr = cast(FuncPtr!(T, objc_id, SEL, A))&objc_msgSend;
		
		static if (is(T == void))
			funcptr(self.ptr, sel_registerName(toStringz(objd.runtime.sel_getName(cmd))), args);
		else {
			auto ret = funcptr(self.ptr, sel_registerName(toStringz(objd.runtime.sel_getName(cmd))), args);
			return ret;
		}
	}
}

package template ObjCType(T) {
	static if (is(T == objd.types.id) || is(T : id))
		alias id ObjCType;
	else
		alias T ObjCType;
}

// NSString probably isn't very portable
version (darwin) {
	string stringFromNSString (id str) {
		if (str is null || str.ptr is null)
			return "(null)";
	
		auto bytes = msgSend!(const(char)*)(str, objd.runtime.sel_registerName("UTF8String"));
		auto len = strlen(bytes);
		
		auto newStr = new char[len];
		strncpy(newStr.ptr, bytes, len);
		return assumeUnique(newStr);
	}
}
