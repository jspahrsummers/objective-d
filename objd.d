module objd;
import std.c.stdlib;
import std.stdio;

/* Basic types */
alias int NSInteger;
alias uint NSUInteger;

/* Selectors */
alias string SEL;

string sel_getName (SEL aSelector) {
    return aSelector;
}

SEL sel_registerName (string str) {
    return str;
}

/* Messaging */
alias int function(id, SEL, ...) IMP;

/* Basic OO types */
class id {
public:
    Class isa;
    
    T msgSend(T, A...)(SEL cmd, A args) {
        Class cls = isa;
        
        IMP invocation = null;
        writefln("invoking method %s", cmd);
        do {
            auto method = cmd in cls.methods;
            if (method) {
                invocation = *method;
                break;
            }
            
            cls = cls.superclass;
        } while (cls !is null);
        
        if (!invocation) {
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
        
        auto impl = cast(T function (id, SEL, A))(invocation);
        static if (is(T == void))
            impl(this, cmd, args);
        else
            return impl(this, cmd, args);
    }
    
    string toString () const {
        return isa.name;
    }
}

class Class : id {
public:
    Class superclass;
    invariant string name;
    
    this (string name, Class superclass = null, bool allocIsa = true) {
        if (allocIsa) {
            isa = new Class("Class", null, false);
            isa.isa = isa;
            if (superclass)
                isa.superclass = superclass.isa;
        }
        
        this.superclass = superclass;
        this.name = name;
    }
    
    bool addMethod(T, A...)(SEL name, T function (id, SEL, A) impl) {
        writefln("adding method %s to %s", name, this.name);
        if (name in methods)
            return false;
        else {
            methods[name] = cast(IMP)(impl);
            return true;
        }
    }
    
    bool hasMethod (SEL name) const {
        return !!(name in methods);
    }
    
    int opApply (int delegate (ref Class) dg) {
        Class cls = this;
        int result = 0;
        do {
            result = dg(cls);
            if (result)
                break;
            
            cls = cls.superclass;
        } while (cls !is null);
        
        return result;
    }
    
    int opApply (int delegate (ref const(Class)) dg) const {
        const(Class) *cls = &this;
        int result = 0;
        do {
            result = dg(*cls);
            if (result)
                break;
            
            cls = &cls.superclass;
        } while (*cls !is null);
        
        return result;
    }
    
    string toString () const {
        return name;
    }

private:
    IMP[SEL] methods;
}

class Instance : id {
    ~this () {
        this.msgSend!(void)("finalize");
    }
}

/* Root object */
Class NSObject;

static this () {
    NSObject = new Class("NSObject");
    
    /* NSObject class methods */
    NSObject.isa.addMethod(sel_registerName("alloc"), function id (id self, SEL cmd) {
        id obj = new Instance;
        obj.isa = cast(Class)self;
        return obj;
    });
    
    NSObject.isa.addMethod(sel_registerName("class"), function Class (id self, SEL cmd) {
        return cast(Class)self;
    });
    
    NSObject.isa.addMethod(sel_registerName("description"), function string (id self, SEL cmd) {
        return self.isa.name;
    });
    
    NSObject.isa.addMethod(sel_registerName("doesNotRecognizeSelector:"), function void (id self, SEL cmd, SEL aSelector) {
        writefln("%s does not recognize selector \"%s\"", self.isa, sel_getName(aSelector));
        abort();
    });
    
    NSObject.isa.addMethod(sel_registerName("instancesRespondToSelector:"), function bool (id self, SEL cmd, SEL aSelector) {
        foreach (Class cls; cast(Class)self) {
            if (cls.hasMethod(aSelector))
                return true;
        }
        
        return false;
    });
    
    NSObject.isa.addMethod(sel_registerName("isSubclassOfClass:"), function bool (id self, SEL cmd, const Class otherClass) {
        foreach (const Class cls; cast(Class)self) {
            if (cls == otherClass)
                return true;
        }
        
        return false;
    });
    
    NSObject.isa.addMethod(sel_registerName("new"), function id (id self, SEL cmd) {
        return self.msgSend!(id)("alloc").msgSend!(id)("init");
    });
    
    NSObject.isa.addMethod(sel_registerName("superclass"), function Class (id self, SEL cmd) {
        return (cast(Class)self).superclass;
    });
    
    /* NSObject instance methods */
    NSObject.addMethod(sel_registerName("description"), function string (id self, SEL cmd) {
        return self.isa.name;
    });
    
    NSObject.addMethod(sel_registerName("class"), function Class (id self, SEL cmd) {
        return self.isa;
    });
    
    NSObject.addMethod(sel_registerName("doesNotRecognizeSelector:"), function void (id self, SEL cmd, SEL aSelector) {
        writefln("%s does not recognize selector \"%s\"", self.isa, sel_getName(aSelector));
        abort();
    });
    
    NSObject.addMethod(sel_registerName("finalize"), function void (id self, SEL cmd) {});
    
    NSObject.addMethod(sel_registerName("hash"), function NSUInteger (id self, SEL cmd) {
        return self.toHash();
    });
    
    NSObject.addMethod(sel_registerName("init"), function id (id self, SEL cmd) {
        return self;
    });
    
    NSObject.addMethod(sel_registerName("isEqual:"), function bool (id self, SEL cmd, const id otherObj) {
        return self == otherObj;
    });
    
    NSObject.addMethod(sel_registerName("isKindOfClass:"), function bool (id self, SEL cmd, const Class otherClass) {
        foreach (const Class cls; self.isa) {
            if (cls == otherClass)
                return true;
        }
        
        return false;
    });
    
    NSObject.addMethod(sel_registerName("isMemberOfClass:"), function bool (id self, SEL cmd, const Class otherClass) {
        return self.isa == otherClass;
    });
    
    NSObject.addMethod(sel_registerName("isProxy"), function bool (id self, SEL cmd) {
        return false;
    });
    
    NSObject.addMethod(sel_registerName("respondsToSelector:"), function bool (id self, SEL cmd, SEL aSelector) {
        foreach (const Class cls; self.isa) {
            if (cls.hasMethod(aSelector))
                return true;
        }
        
        return false;
    });
    
    NSObject.addMethod(sel_registerName("self"), function id (id self, SEL cmd) {
        return self;
    });
    
    NSObject.addMethod(sel_registerName("superclass"), function Class (id self, SEL cmd) {
        return self.isa.superclass;
    });
}

unittest {
    Class MyClass = new Class("MyClass", NSObject);
    assert(MyClass.msgSend!Class(sel_registerName("class")) is MyClass);
    assert(MyClass.msgSend!bool(sel_registerName("isSubclassOfClass:"), NSObject));
    
    id obj = MyClass.msgSend!id(sel_registerName("new"));
    assert(obj !is null);
    assert(obj.msgSend!bool(sel_registerName("isKindOfClass:"), NSObject));
    assert(obj.msgSend!bool(sel_registerName("isKindOfClass:"), MyClass));
    assert(!obj.msgSend!bool(sel_registerName("isMemberOfClass:"), NSObject));
    assert(obj.msgSend!bool(sel_registerName("isMemberOfClass:"), MyClass));
}
