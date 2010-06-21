/*
 * hash.d
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

module objd.hash;

alias uint hash_value;

//-----------------------------------------------------------------------------
// MurmurHashNeutral2, by Austin Appleby
// Released into the public domain
//-----------------------------------------------------------------------------
package pure hash_value murmur_hash (immutable void[] key, hash_value seed = 0xDEADBEEFU) {
	enum m = 0x5bd1e995U;
	enum r = 24;
	
	hash_value h = seed ^ key.length;
	size_t len = key.length;
	auto data = cast(immutable(ubyte)*)key.ptr;
	
	while (len >= 4) {
		hash_value k;
		
		k  = cast(hash_value)(data[0]);
		k |= cast(hash_value)(data[1]) << 8;
		k |= cast(hash_value)(data[2]) << 16;
		k |= cast(hash_value)(data[3]) << 24;
		
		k *= m;
		k ^= k >> r;
		k *= m;
		
		h *= m;
		h ^= k;
		
		data += 4;
		len  -= 4;
	}
	
	switch (len) {
	case 3:  h ^= cast(hash_value)(data[2]) << 16;
	case 2:  h ^= cast(hash_value)(data[1]) << 8;
	case 1:  h ^= cast(hash_value)(data[0]);
	default: h *= m;
	}
	
	h ^= h >> 13;
	h *= m;
	h ^= h >> 15;
	
	return h;
}

unittest {
	assert(murmur_hash("foo") == murmur_hash("foo"));
	assert(murmur_hash("foo", 42) == murmur_hash("foo", 42));
	assert(murmur_hash("foo", 88) != murmur_hash("foo", 42));
	assert(murmur_hash("foo") != murmur_hash("bar"));
}
