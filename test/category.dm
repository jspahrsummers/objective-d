/*
 * category.dm
 * Objective-D category test
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

import std.stdio;
import objd.mobject;

@category MObject

- (string)description {
	return "foobar";
}

- (id)somethingAmazing {
	return self;
}

+ (uint)theMeaningOfLifeTheUniverseAndEverything {
	return 42;
}

@end

void main () {
	writeln("Testing Objective-D categories...");
	
	writeln("--- Invoking category class method and validating result");
	assert([MObject theMeaningOfLifeTheUniverseAndEverything] == 42);
	
	writeln("--- Allocating instance of category'd class");
	id obj = [MObject new];
	assert(obj !is null);
	
	writeln("--- Invoking category instance method and validating result");
	assert([obj somethingAmazing] is obj);
	
	writeln("--- Invoking category method that overrode instance method and validating result");
	assert([obj description] == "foobar");
	
	writeln("--- Invoking category class method through instance and validating result");
	assert([[obj class] theMeaningOfLifeTheUniverseAndEverything] == 42);
	
	writefln("%s passed!", __FILE__);
}
