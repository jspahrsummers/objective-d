_Note: This page assumes some knowledge of D, as well as at least peripheral knowledge of Objective-C._

# The Objective-D Programming Language #

**Objective-D** comprises dynamic (runtime-driven) additions to the D programming
language. It is a strict superset of D, meaning that any piece of valid D code
is also, by definition, valid Objective-D code. Objective-D source code files are
named with a .dm extension (for "D + messages") by convention.

The main concept behind Objective-D is that of the _message send_. Instead of
invoking a method or member function on an object (like in C++ or D), you send a
"message," to which the object may either respond or not. Message sending
provides a tremendous amount of flexibility not available in static programming
languages. Messages can be constructed at runtime, unrecognized messages can be
forwarded to another object (facilitating the easy implementation of proxy
objects), and methods themselves can even be added at runtime.

The flexibility of message sending is not without a cost, however. There is a
slight overhead associated with resolving messages and types at runtime. By
combining the static and dynamic object models, Objective-D attempts to provide
performance when it's needed, and flexibility when it's not.

### Classes ###

**Classes** in Objective-D are defined similarly to the following template:

```
@class ClassName : BaseClassName {
	int instanceVar;
	bool anotherVar;
}

- (void)doSomething {
	writeln("Hello world!");
}

@end
```

The `@class` keyword introduces a new Objective-D class, the name of which
immediately follows. Following that is an optional superclass specification,
indicated by a colon and the name of the base class to inherit from. Instance
variables go in the braces that follow.

Any method definitions are placed after the closing brace for the instance
variables, followed by the `@end` keyword. Methods are defined like so:

```
- (string)methodNameWithParameter:(int)val otherParameter:(bool)yesNo {
	return format("parameter: %s, otherParameter: %s", val, yesNo);
}
```

**Methods** start with either a minus `-` or plus `+`. A minus sign indicates an
instance method, while a plus indicates a class method. Following that is the
return type of the method, enclosed in parentheses. Then comes the method name.

Method names in Objective-D follow a syntax similar to that of Smalltalk or
Objective-C, where parameters are named and denoted with colons. A method can
also be defined without any parameters -- and thus contain no colons -- and it
can also end in a trailing word. `connection:didFinishLoading` is thus a valid
method name in Objective-D.

Parameters can only appear, and must appear, after colons in the method name.
The parameter's type is given in parentheses, and its name follows. After the
last part of the method name, there should be a method body enclosed in braces.

The message send corresponding to the above method would look like the
following:

```
string str = [obj methodNameWithParameter:42 otherParameter:false];
```

Square brackets denote an Objective-D message send. The receiver (object
receiving the message) immediately follows the left bracket. The name of the
message follows the receiver and closely mirrors the method definition, with
parameters replaced by argument values. Message sends can also be nested:

```
assert( [[MyClass new] isKindOfClass:[MyClass class]] );
```

Within Objective-D instance methods, the special keyword `self` refers to the
object responding to the message. `self` must be used to access any instance
variables as well; for instance,

```
- (void)add:(int)val andSetToFalse {
	self.instanceVar += val;
	self.anotherVar = false;
}
```

Similarly, the special keyword `super` refers the object's immediate superclass.
This can be used to invoke the superclass implementation of methods that have
been overridden:

```
@class MyClass : MObject {

}

- (string)description {
	return "MyClass: " ~ [super description];
}

@end
```

Objective-D defines a special type `id` that represents any Objective-D object
(including class objects). Additionally, all Objective-D objects ultimately
inherit from D's `Object` class, and so can be used in any places where D
objects are expected. Type inference using `auto` works in Objective-D just as
in D, and is actually the recommended way to utilize objects, as it allows the
Objective-D compiler to perform more static type checking, analysis, and
optimization.

### MObject ###

**MObject** is the name of the default base class for new Objective-D classes.
Defined classes do not automatically inherit from MObject, but it provides the
foundation for interacting with the Objective-D runtime. In order to access it,
you must import the `objd.mobject` module in your code and then specify it as the
base class for any of your classes:

```
import objd.mobject;

@class MyClass : MObject {

}

@end
```

By simply inheriting from MObject, your class can be easily instantiated:

```
void main () {
	auto obj = [[MyClass alloc] init];
	
	// also just performs [[MyClass alloc] init]
	auto obj2 = [MyClass new];
}
```

Because D is a garbage collected language, Objective-D objects are automatically deallocated when not in use anymore. Class objects (those obtained through `[obj class]` or `[MyClass class]`) exist for the entire duration of your program's runtime.

MObject also provides basic methods for reflection. Here are just some examples:

```
void main () {
	auto obj = [MyClass new];
	writefln("%s", [obj class]);
	writefln("%s", [obj superclass]);
	writefln("%s", [MyClass superclass]);
	
	assert([obj respondsToSelector:@selector(isKindOfClass:)]);
	assert([obj isKindOfClass:MyClass]);
	assert([obj isKindOfClass:MObject]);
}
```

MObject itself is implemented in Objective-D. Its source code is available in
`mobject.dm` within the `objd` folder.

### Categories ###

Because of the dynamic nature of Objective-D classes, methods can actually be
added at runtime, or without access to the source code of the original class.
**Categories** are one means by which to do this. A category specifies an existing
class along with methods to add to it; for example, this adds a method named
`meaningOfLifeTheUniverseAndEverything` to MObject, which is already implemented
in the Objective-D runtime library.

```
@category MObject (MyAwesomeExtensions)

- (uint)meaningOfLifeTheUniverseAndEverything {
	return 42;
}

@end
```

The `@category` keyword introduces a category. Since categories only make sense
in the context of existing classes, the name of an existing class must
immediately follow the `@category` keyword -- the class specified will be modified
at runtime by adding all the provided methods. Categories can have a identifier,
which must follow the class name and be enclosed in parentheses, but naming
categories is optional.

Categories are indistinguishable from methods that were originally defined for
the class in question, meaning that they have access to all instance variables
and methods.

Methods defined as part of a category can also override an existing method;
however, once overridden in such a manner, the original implementation can no
longer be accessed. This only applies if the method is defined specifically on
the modified class. Overriding a method on a class that was originally defined
in a superclass still allows access through use of the `super` keyword:

```
@class MyClass : MObject {

}

@end

@category MyClass
// description was originally implemented in MObject
- (string)description {
	return "MyClass: " ~ [super description];
}

@end
```

### Selectors ###

**Selectors** are unique identifiers for methods. Their uniqueness is enforced by
the Objective-D runtime, so that the selectors for two methods of the same name
will always be identical, while the selectors for two methods of different names
will always be different.

Selectors also contain return type information so that the Objective-D runtime
can always determine an appropriate return type for a given message send. As a
side effect of this, all methods sharing the same name must have the same return
type; for example, the following is illegal, even though the two classes have no
relation to each other:

```
@class MyClass : MObject {

}

- (string)value {
	return "foobar";
}

@end

@class OtherClass : MObject {

}

- (int)value {
	return 42;
}

@end
```

Selectors are represented in code by type `SEL`. You can obtain a selector for a
given method name using an `@selector()` expression:

```
void main () {
	SEL aSelector = @selector(methodNameWithParameter:otherParameter:);
}
```

Once obtained in such a manner, selectors can be used for reflection and dynamic
message sending:

```
@class MyClass : MObject {

}

+ (void)printOutClassName:(Class)cls {
	writefln("%s", cls);
}

@end

void main () {
	SEL aSelector = @selector(printOutClassName:);
	
	assert([MyClass respondsToSelector:aSelector]);
	[MyClass performSelector:aSelector withObject:[MObject class]];
}
```

### Objective-C compatibility ###

Objective-D provides a thin layer for compatibility with compiled Objective-C
code. Please note that Objective-D **does not** and will not provide source-based
compatibility. In order to take advantage of the compatibility layer, the
Objective-D compiler and runtime must be built with the `-version=objc_compat`
flag and linked with libobjc (or whatever name the library goes by on your
system).

To import an Objective-C class into Objective-D code, use the `@objc` keyword at
module level. The `@objc` keyword must be followed by the desired class. This
simple declaration will allow you to send messages to the referenced class as if
it were a native Objective-D object:

```
@objc NSString;

void main () {
	assert([NSString class] == NSString);
	
	auto obj = [[NSString alloc] init];
	[obj release];
}
```

Objective-C objects must always be used with inferred types (using `auto`) or with
the fully-qualified name of the Objective-C object type. Anything else will
cause an error when sending messages.

```
void main () {
	auto obj = [NSString new];
	objd.objc.id obj2 = obj;
	
	// ILLEGAL!
	id obj3 = obj2;
	[obj3 release];
}
```

Just like mixing C with D, mixing Objective-C with Objective-D code can become
dangerous if used haphazardly. This especially applies if using reference-counted Objective-C code instead of garbage collection -- for instance, not
using `[obj release]` in either of the above code snippets would result in a memory leak that
could not be reclaimed by the D garbage collector.

Objective-D also has no knowledge of Objective-C return types. For this reason,
messages sent to Objective-C objects are assumed to always return Objective-C
objects (including class objects). This will also work with methods that have no
return value (such as `release`) as long as the result of the message send is not
assigned to anything. If you know a method's return type -- one that does not
return an object -- you can explicitly refer to it with some low-level hackery:

```
@objc NSString;

void main () {
	auto objCStr = [NSString new];

	// return type is provided with the single template parameter
	// the first argument thereafter is the receiver of the message
	// the second argument is the selector for the message
	// any other arguments are passed as part of the message send
	auto len = objd_msgSend!NSUInteger(objCStr, @selector(length));
	
	assert(len == 0);
	[objCStr release];
}
```

Remember to link in any needed Objective-C frameworks when using classes from
those frameworks. `@objc` only declares an (external) Objective-C class -- it does
not import its code directly.