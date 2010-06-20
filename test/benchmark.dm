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

enum BENCHMARK_TIMES = 10_000_000;

id instance;
SEL selector;

void classMethod () {
	MObject.msgSend!(objd.runtime.Class)(selector);
}

void instanceMethod () {
	instance.msgSend!(objd.runtime.Class)(selector);
}

void main () {
	instance = [MObject new];
	selector = @selector(class);
	
	auto results = benchmark!(classMethod, instanceMethod)(BENCHMARK_TIMES);
	foreach (i, result; results) {
		writefln("running benchmark %s %s times took %s ms (%.2f ms each)", i, BENCHMARK_TIMES, result, cast(real)result / BENCHMARK_TIMES);
	}
}
