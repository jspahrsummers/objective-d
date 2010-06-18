module objd.types;
import objd.runtime;
import std.c.stdlib;
import std.contracts;
import std.stdio;
import std.string;

/* Selectors */
alias string SEL;

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
		writefln("invoking method %s with return type %s", cmd, typeid(T));
		do {
			auto item = cmd in cls.methods;
			if (item) {
				method = *item;
				break;
			}
			
			cls = cls.superclass;
		} while (cls !is null);
		
		if (!method) {
			writefln("couldn't find method %s", cmd);
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
		
		//enforce(typeid(T) == method.returnType, format("requested return type %s does not match defined return type %s for method %s", typeid(T), method.returnType, method.selector));
		enforce(A.length == method.argumentTypes.length, format("number of arguments to method %s (%s) does not match %s defined parameters", method.selector, A.length, method.argumentTypes.length));
		
		foreach (i, type; A) {
			enforce(typeid(type) == method.argumentTypes[i] || typeid(const type) == method.argumentTypes[i], format("argument %s of type %s does not match defined parameter type %s for method %s", i + 1, typeid(type), method.argumentTypes[i], method.selector));
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
