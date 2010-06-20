/*
 * types.d
 * Objective-D runtime
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

module objd.types;
import objd.hash;
import objd.runtime;
import std.c.stdlib;
import std.contracts;
import std.stdio;
import std.string;
import std.traits;
import std.typetuple;

/* Selectors */
alias hash_value SEL;

/* Messaging */
alias int function(id, SEL, ...) IMP;

/* Basic OO types */
class id {
public:
	Class isa;
	
	T msgSend(T, A...)(SEL cmd, A args) {
		Class cls = isa;
		assert(cls !is null);
		
		debug {
			//writefln("invoking method %s with return type %s", cmd, typeid(T));
		}
		
		immutable cache = cmd & (METHOD_CACHE_SIZE - 1);
		auto method = cls.cachedMethods[cache];
		debug {
			//writefln("cached methods: %s", cls.cachedMethods);
		}
		
		if (method is null || method.selector != cmd) {
			do {
				method = cast(Method)cls.methods.get(cmd);
				if (method !is null) {
					cls.cachedMethods[cache] = method;
					goto invoke;
				}
				
				cls = cls.superclass;
			} while (cls !is null);
			
			debug {
				writefln("couldn't find method %s", cmd);
			}
			
			auto doesNotRecognize = sel_registerName("doesNotRecognizeSelector:");
			if (cmd == doesNotRecognize) {
				abort();
			} else {
				this.msgSend!(void)(doesNotRecognize, cmd);
			}
			
			static if (is(T == void))
				return;
			else
				return T.init;
		}
		
	invoke:
		// the safety checks below should always remain in release mode
		// dynamic programming languages become dangerous without typechecking
		
		enforce(TypeInfoConvertibleToType!T(method.returnType), format("requested return type %s does not match defined return type %s for method %s", typeid(T), method.returnType, cmd));
		enforce(A.length == method.argumentTypes.length, format("number of arguments to method %s (%s) does not match %s defined parameters", cmd, A.length, method.argumentTypes.length));
		
		foreach (i, type; A) {
			debug {
				//writefln("checking type %s against argument %s", type.stringof, i);
			}
			
			enforce(TypeConvertibleToTypeInfo!type(method.argumentTypes[i]), format("argument %s of type %s does not match defined parameter type %s for method %s", i + 1, typeid(type), method.argumentTypes[i], sel_getName(cmd)));
		}
		
		auto impl = cast(T function (id, SEL, A))(method.implementation);
		static if (is(T == void))
			impl(this, cmd, args);
		else
			return impl(this, cmd, args);
	}
	
	override string toString () const {
		return isa.name;
	}
}

/* Traits templates */
package bool TypeConvertibleToTypeInfo(T)(immutable TypeInfo info) {
	foreach (type; TypeAndImplicitConversions!T) {
		debug {
			//writefln("checking typeinfo %s against implicit type %s from type %s", cast(TypeInfo)info, typeid(type), typeid(T));
		}
	
		static if (is(T == const)) {
			if (info == cast(immutable)typeid(const type))
				return true;
		} else if (is(T == immutable)) {
			if (info == cast(immutable)typeid(const type) || info == cast(immutable)typeid(immutable type))
				return true;
		} else {
			if (info == cast(immutable)typeid(const type) || info == cast(immutable)typeid(          type))
				return true;
		}
	}
	
	return false;
}

package bool TypeInfoConvertibleToType(T)(immutable TypeInfo info) {
	alias Unqual!(OriginalType!T) U;
	
	if (typeid(U) == info)
		return true;

	static if (is(U == class)) {
		auto classinfo = cast(immutable TypeInfo_Class)info;
		if (classinfo is null)
			return false;
		
		return ClassInfoInheritsFromClassInfo(classinfo, cast(immutable TypeInfo_Class)(typeid(U)));
	} else if (is(U == interface)) {
		auto ifaceinfo = cast(immutable TypeInfo_Interface)info;
		auto cmpinfo = cast(immutable TypeInfo_Interface)(typeid(U));
		if (ifaceinfo is null) {
			auto classinfo = cast(immutable TypeInfo_Class)info;
			if (classinfo is null)
				return false;
			
			return ClassInfoConformsToInterfaceInfo(classinfo, cmpinfo.info);
		} else {
			return InterfaceInfoConformsToInterfaceInfo(ifaceinfo.info, cmpinfo.info);
		}
	} else
		return false;
}

package template TypeAndImplicitConversions(T) {
	alias TypeTuple!(Unqual!(OriginalType!T), ImplicitConversionTargets!(Unqual!(OriginalType!T))) TypeAndImplicitConversions;
}

package bool ClassInfoInheritsFromClassInfo (immutable TypeInfo_Class info, immutable TypeInfo_Class cmpinfo) {
	if (info.base is null)
		return false;
	else if (info.base == cmpinfo)
		return true;
	else
		return ClassInfoInheritsFromClassInfo(info.base, cmpinfo);
}

package bool ClassInfoConformsToInterfaceInfo (immutable TypeInfo_Class info, immutable TypeInfo_Class cmpinfo) {
	foreach (ref iface; info.interfaces) {
		if (cmpinfo == iface.classinfo)
			return true;
		else
			return InterfaceInfoConformsToInterfaceInfo(iface.classinfo, cmpinfo);
	}
	
	if (info.base is null)
		return false;
	else if (info.base == cmpinfo)
		return true;
	else
		return ClassInfoConformsToInterfaceInfo(info.base, cmpinfo);
}

package bool InterfaceInfoConformsToInterfaceInfo (immutable TypeInfo_Class info, immutable TypeInfo_Class cmpinfo) {
	foreach (ref iface; info.interfaces) {
		if (cmpinfo == iface.classinfo)
			return true;
		else
			return InterfaceInfoConformsToInterfaceInfo(iface.classinfo, cmpinfo);
	}
	
	return false;
}
