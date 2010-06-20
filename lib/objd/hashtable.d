/*
 * hashtable.d
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

module objd.hashtable;
public import objd.hash;
import std.stdio;

package struct HashTableEntry(K, V) {
public:
	immutable hash_value hash;
	immutable K key;
	V value;
	
	this (immutable hash_value hash, immutable K key, V value) {
		this.hash = hash;
		this.key = key;
		this.value = value;
	}
}

package struct HashTable(K, V, alias H = murmur_hash) {
public:
	alias HashTableEntry!(K, V) entry_t;

	entry_t[] entries;
	size_t length;
	hash_value mask;
	
	void ensure (size_t newLength) {
		if (entries.length >= newLength)
			return;
		
		// optimize for 0.7 load
		size_t capacity = (entries.length == 0 ? 1 : entries.length);
		do
			capacity <<= 1;
		while (capacity * 7 / 10 < newLength);
	
		auto newMask = capacity - 1;
		auto currentEntries = entries;
		
		entries = new HashTableEntry!(K, V)[capacity];
		foreach (ref entry; currentEntries) {
			entries[slotFor(entry.key, entry.hash)] = entry;
		}
		
		mask = newMask;
	}
	
	entry_t* opBinaryRight(string op)(immutable K key)
		if (op == "in")
	{
		return &entries[slotFor(key, H(key))];
	}
	
	entry_t* set (immutable K key, V value) {
		return set(key, H(key), value);
	}
	
	entry_t* set (immutable K key, immutable hash_value hash, V value) {
		ensure(length + 1);
	
		auto slot = slotFor(key, hash);
		if (entries[slot].key is null) {
			entries[slot] = HashTableEntry!(K, V)(hash, key, value);
			++length;
		}
		
		return &entries[slot];
	}
	
	int opApply (int delegate (const(entry_t)*) dg) const {
		int result = 0;
		
		foreach (i; 0 .. entries.length) {
			if (entries[i].key !is null) {
				result = dg(&entries[i]);
				if (result)
					break;
			}
		}
		
		return result;
	}
	
	invariant () {
		assert(entries.length == 0 || entries.length == mask + 1);
		assert(entries.length >= length);
	}
	
protected:
	size_t slotFor (immutable K key, hash_value hash) const {
		auto h = hash & mask;
		while (entries[h].key !is null && entries[h].key != key) {
			h = (h + 1) & mask;
		}
		
		return h;
	}
}
