/*
 * hashset.d
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

module objd.hashset;
public import objd.hash;
import std.stdio;
import std.string;

struct HashSetEntry(K) {
public:
	const K key;
	immutable hash_value hash;
	
	this (const K key, immutable hash_value hash) {
		this.key = key;
		this.hash = hash;
	}
}

class HashSet(K) {
public:
	HashSetEntry!(K)[] entries;
	
	this () {
		entries = new typeof(entries[0])[1];
	}
	
	const(K) get (hash_value hash) const {
		auto startingSlot = hash & mask;
		auto slot = startingSlot;
		for (;;) {
			if (entries[slot].hash == hash)
				return entries[slot].key;
			
			// TODO: make quadratic
			slot = (slot + 1) & mask;
			
			debug {
				//writefln("get: incrementing slot, current load is %s", cast(double)length / entries.length);
			}
			
			if (slot == startingSlot)
				break;
		}
		
		return null;
	}
	
	static if (is(K : void[])) {
		hash_value put (const(K) key) {
			return put(key, murmur_hash(key));
		}
	}
	
	hash_value put (const(K) key, hash_value hash)
	in {
		assert(key !is null);
	} body {
		expand(1);
		
		auto slot = hash & mask;
		for (;;) {
			if (entries[slot].key is null) {
				++length;
				entries[slot] = HashSetEntry!(K)(key, hash);
				break;
			} else if (entries[slot].hash == hash) {
				if (entries[slot].key == key)
					break;
			} else
				// keys shouldn't match if the hashes didn't
				assert(entries[slot].key != key);
			
			// TODO: make quadratic
			slot = (slot + 1) & mask;
			
			debug {
				//writefln("put: incrementing slot, current load is %s", cast(double)length / entries.length);
			}
		}
		
		return hash;
	}
	
	void remove (hash_value hash) {
		auto startingSlot = hash & mask;
		auto slot = startingSlot;
		for (;;) {
			if (entries[slot].hash == hash) {
				entries[slot] = HashSetEntry!(K)(null, hash);
				return;
			}
			
			// TODO: make quadratic
			slot = (slot + 1) & mask;
			
			debug {
				//writefln("remove: incrementing slot, current load is %s", cast(double)length / entries.length);
			}
			
			if (slot == startingSlot)
				break;
		}
	}
	
	int opApply (int delegate (ref hash_value hash, ref const(K) key) dg) {
		int result = 0;
		
		foreach (ref entry; entries) {
			if (entry.key !is null) {
				result = dg(entry.hash, entry.key);
				if (result)
					break;
			}
		}
		
		return result;
	}
	
	override string toString () const {
		string ret = "[\n";
		
		foreach (ref entry; entries) {
			if (entry.key !is null)
				ret ~= format("\t%s : %s\n", entry.hash, entry.key);
		}
		
		return ret ~ "]";
	}
	
	invariant () {
		assert(entries !is null && entries.length > 0);
		assert(entries.length >= length);
		assert(mask == entries.length - 1);
	}

protected:
	size_t length;
	hash_value mask;
	
	void expand (size_t amount)
	in {
		assert(amount > 0);
	} body {
		size_t newLength = length + amount;
		
		size_t capacity = entries.length;
		while (capacity * 7 / 10 < newLength)
			capacity <<= 1;
		
		if (capacity == entries.length)
			return;
		
		assert(capacity > entries.length);
		
		auto currentEntries = entries;
		entries = new typeof(entries[0])[capacity];
		mask = capacity - 1;
		
		foreach (ref entry; currentEntries) {
			// TODO: make quadratic
			auto slot = entry.hash & mask;
			while (entries[slot].key !is null)
				slot = (slot + 1) & mask;
			
			entries[slot] = entry;
		}
	}
}
