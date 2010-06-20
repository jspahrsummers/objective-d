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
		
		Method method = null;
		debug {
			writefln("invoking method %s with return type %s", cmd, typeid(T));
		}
		
		immutable cache = cmd & (METHOD_CACHE_SIZE - 1);
		if (cls.cachedSelectors[cache] == cmd)
			method = cls.cachedMethods[cache];
		else {
			do {
				auto item = cmd in cls.methods;
				if (item) {
					method = *item;
					break;
				}
				
				cls = cls.superclass;
			} while (cls !is null);
			
			if (!method) {
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
			
			cls.cachedSelectors[cache] = cmd;
			cls.cachedMethods  [cache] = method;
		}
		
		// TODO: this needs to be figured out and re-enabled for type safety
		//enforce(typeid(T) == method.returnType, format("requested return type %s does not match defined return type %s for method %s", typeid(T), method.returnType, method.selector));
		//enforce(A.length == method.argumentTypes.length, format("number of arguments to method %s (%s) does not match %s defined parameters", method.selector, A.length, method.argumentTypes.length));
		//
		//foreach (i, type; A) {
		//	enforce(typeid(type) == method.argumentTypes[i] || typeid(const type) == method.argumentTypes[i], format("argument %s of type %s does not match defined parameter type %s for method %s", i + 1, typeid(type), method.argumentTypes[i], method.selector));
		//}
		
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
