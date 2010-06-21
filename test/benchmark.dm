/*
 * benchmark.dm
 * Objective-D speed benchmark
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

import std.date;
import std.stdio;
import objd.mobject;
import objd.runtime;

enum BENCHMARK_TIMES = 10_000_000;

__gshared id instance;
__gshared Class function (id, SEL) classIMP;

void classMethod () {
	[MObject class];
}

void instanceMethod () {
	[instance class];
}

@class MyClass : MObject {
}

+ (bool)doSomething:(int)a with:(double)b and:(char)c {
	return false;
}
@end

void methodWithArgs () {
	[MyClass doSomething:42 with:3.14 and:'!'];
}

void impCached () {
	classIMP(MObject, @selector(class));
}

void main () {
	instance = [MObject new];
	
	auto method = MObject.isa.methods.get(@selector(class));
	assert(method !is null);
	
	classIMP = cast(typeof(classIMP))(method.implementation);
	assert(classIMP !is null);
	
	auto results = benchmark!(classMethod, instanceMethod, methodWithArgs, impCached)(BENCHMARK_TIMES);
	foreach (i, result; results) {
		writefln("running benchmark %s %s times took %s ms (%.2f ms each)", i + 1, BENCHMARK_TIMES, result, cast(real)result / BENCHMARK_TIMES);
	}
}
