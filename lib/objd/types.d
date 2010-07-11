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
import std.contracts;
import std.c.stdlib;
import std.stdio;
import std.string;
import std.traits;
import std.typetuple;

/* Selectors */
alias hash_value SEL;

// a set indexed by unique selectors
struct SelectorSet(V, uint maxLoad = 70) {
public:
	static if (is(V == class) || is(V == interface) || isArray!V || isPointer!V)
		alias V value_type;
	else
		alias V* value_type;

	this (size_t startingCapacity)
	in {
		assert(startingCapacity > 0);
	} body {
		entries = new Entry[1];
		capacity = startingCapacity;
	}
	
	@property final size_t capacity () const {
		return entries.length;
	}
	
	@property final size_t capacity (size_t newCapacity) {
		size_t currentCapacity = entries.length;
		if (newCapacity <= currentCapacity)
			return currentCapacity;
		
		if (currentCapacity == 0)
			currentCapacity = 1;
		
		do
			currentCapacity <<= 1;
		while (currentCapacity < newCapacity);
		
		debug {
			//writefln("resizing to %s", currentCapacity);
		}
		
		auto oldEntries = entries;
		auto oldMask = mask;
		
		entries = new Entry[currentCapacity];
		mask = currentCapacity - 1;
		
		auto numLeft = m_length;
		if (numLeft) {
			foreach (ref Entry entry; oldEntries) {
				if (entry.selector) {
					add(entry.selector, entry.value);
					if (--numLeft == 0)
						break;
				}
			}
		}
		
		return currentCapacity;
	}
	
	@property final size_t length () const {
		return m_length;
	}
	
	final bool add (immutable SEL selector, lazy V value, bool overwrite = false)
	in {
		assert(selector != 0);
	} out (result) {
		assert(result || !overwrite, "if overwriting a key, add() should always be a success");
	} body {
		expandIfNeeded();
	
		auto slot = selector & mask;
		auto startingSlot = slot;
		
		while (entries[slot].selector) {
			debug {
				//writefln("slot %s contains selector %s", slot, entries[slot].selector);
			}
		
			if (entries[slot].selector == selector) {
				if (overwrite) {
					entries[slot] = Entry(selector, value);
					return true;
				} else
					return false;
			}
		
			slot = (slot + 1) & mask;
			debug {
				//writefln("new slot = %s, length = %s", slot, entries.length);
				assert(slot != startingSlot, "set is full even after expansion");
			}
		}
		
		debug {
			//writefln("previous selector in slot %s: %s", slot, entries[slot].selector);
		}
		
		entries[slot] = Entry(selector, value);
		
		debug {
			//writefln("put selector %s in bucket %s", selector, slot);
		}
		
		++m_length;
		return true;
	}
	
	final void clear () {
		enum len = entries.length;
		for (size_t i = 0;i < len;++i)
			entries[i] = Entry(0);
		
		m_length = 0;
	}
	
	final const(value_type) get (immutable SEL selector) const
	in {
		assert(selector != 0);
	} body {
		if (!m_length)
			return null;
	
		auto startingSlot = selector & mask;
		auto slot = startingSlot;
		
		while (entries[slot].selector) {
			if (entries[slot].selector == selector) {
				static if (isPointer!value_type)
					return &entries[slot].value;
				else
					return entries[slot].value;
			}
			
			slot = (slot + 1) & mask;
			if (slot == startingSlot)
				break;
		}
		
		return null;
	}
	
	final value_type get (immutable SEL selector)
	in {
		assert(selector != 0);
	} body {
		if (!m_length)
			return null;
			
		auto startingSlot = selector & mask;
		auto slot = startingSlot;
		
		while (entries[slot].selector) {
			if (entries[slot].selector == selector) {
				static if (isPointer!value_type)
					return &entries[slot].value;
				else
					return entries[slot].value;
			}
			
			slot = (slot + 1) & mask;
			if (slot == startingSlot)
				break;
		}
		
		return null;
	}
	
	final void remove (immutable SEL selector)
	in {
		assert(selector != 0);
	} body {
		if (!m_length)
			return;
		
		auto startingSlot = selector & mask;
		auto slot = startingSlot;
		
		while (entries[slot].selector) {
			if (entries[slot].selector == selector)
				break;
			
			slot = (slot + 1) & mask;
			if (slot == startingSlot)
				return;
		}
		
		auto foundInSlot = slot;
		auto next = (slot + 1) & mask;
		while (next != foundInSlot && entries[next].selector) {
			if ((entries[next].selector & mask) == foundInSlot) {
				entries[slot] = entries[next];
				
				slot = next;
			}
			
			next = (slot + 1) & mask;
		}
		
		entries[slot] = Entry();
	}
	
	final int opApply (int delegate(ref immutable SEL, ref V value) dg) {
		int result = 0;
		for (size_t i = 0;i < entries.length;++i) {
			if (entries[i].selector) {
				result = dg(entries[i].selector, entries[i].value);
				if (result)
					break;
			}
		}
		
		return result;
	}
	
	final int opApply (int delegate(ref immutable SEL, ref const V value) dg) const {
		int result = 0;
		for (size_t i = 0;i < entries.length;++i) {
			if (entries[i].selector) {
				result = dg(entries[i].selector, entries[i].value);
				if (result)
					break;
			}
		}
		
		return result;
	}

protected:
	static struct Entry {
		immutable SEL selector;
		V value;
		
		this (immutable SEL selector, V value = V.init) {
			this.selector = selector;
			this.value = value;
		}
	}
	
	Entry[] entries;
	size_t m_length;
	SEL mask;
	
	final void expandIfNeeded () {
		enum newLen = m_length + 1;
		if (newLen >= entries.length * maxLoad / 100)
			capacity = newLen + newLen * (100 - maxLoad) / 100;
	}
}

/* Messaging */
alias int function(id, SEL, ...) IMP;

/* Basic OO types */
class id {
public:
	Class isa;
	
	override string toString () const {
		return isa.name;
	}
}

enum id nil = null;

/* Traits templates */
package bool TypeConvertibleToTypeInfo(T)(immutable TypeInfo info) {
	foreach (type; TypeAndImplicitConversions!T) {
		debug {
			writefln("checking typeinfo %s against implicit type %s from type %s", cast(TypeInfo)info, typeid(type), typeid(T));
		}
		
		if (info == cast(immutable)typeid(type))
			return true;
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
	alias TypeTuple!(
		Unqual!(OriginalType!T), DeepImplicitConversionTargets!(Unqual!(OriginalType!T))
	) TypeAndImplicitConversions;
}

package template DeepImplicitConversionTargets(T)
//	if (!isArray(T))
{
	alias ImplicitConversionTargets!(T) DeepImplicitConversionTargets;
}

// TODO: implicit conversion of immutable(char)[] to const(char)[] and similar
//package template DeepImplicitConversionTargets(T)
//	if (isArray(T))
//{
//	alias TypeTuple!(ImplicitConversionTargets!(T), ArrayUnqual!(typeof(T[0]), 1)) DeepImplicitConversionTargets;
//}
//
//package template ArrayUnqual(T)
//	if (isArray(T))
//{
//	
//}

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
