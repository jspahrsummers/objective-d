module objd;
import std.c.stdlib;
import std.stdio;

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
                this.msgSend!(void)(doesNotRecognize);
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
        writefln("adding method %s", name);
        if (name in methods)
            return false;
        else {
            methods[name] = cast(IMP)(impl);
            return true;
        }
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
    
    NSObject.addMethod(sel_registerName("finalize"), function void (id self, SEL cmd) {});
    
    NSObject.addMethod(sel_registerName("init"), function id (id self, SEL cmd) {
        return self;
    });
}
