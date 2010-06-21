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

class HashSet(K, bool CACHE = false) {
public:
	this () {
		buckets = new Entry[1];
	}
	
	this (size_t capacity) {
		this();
		this.capacity = capacity;
	}
	
	@property size_t length () const {
		return count;
	}
	
	@property size_t capacity () const {
		return buckets.length;
	}
	
	@property size_t capacity (size_t value) {
		if (value <= buckets.length)
			return buckets.length;
		
		size_t newCapacity = buckets.length;
		do
			newCapacity <<= 1;
		while (newCapacity < value);
	
		auto currentBuckets = buckets;
		buckets = new Entry[newCapacity];
		bucketMask = newCapacity - 1;
		
		foreach (ref const Entry entry; currentBuckets) {
			if (!entry.empty)
				add(entry.key, entry.hash);
		}
		
		return newCapacity;
	}
	
	bool contains (immutable K key) const {
		return get(key             ) !is null;
	}
	
	bool contains (immutable K key, hash_value precalcHash) const {
		return get(key, precalcHash) !is null;
	}
	
	immutable(K)* get (immutable K key) const {
		return get(key, hashKey(key));
	}
	
	immutable(K)* get (immutable K key, hash_value precalcHash) const {
		debug {
			enforce(precalcHash == hashKey(key), "hash of key does not match precalculated hash");
		}
		
		auto slot = precalcHash & bucketMask;
		static if (CACHE) {
			if (buckets[slot].empty || buckets[slot].key != key)
				return null;
			else
				return &buckets[slot].key;
		} else {
			auto startingSlot = slot;
			while (!buckets[slot].empty) {
				if (buckets[slot].hash == precalcHash && buckets[slot].key == key)
					return &buckets[slot].key;
				
				slot = (slot + 1) & bucketMask;
				if (slot == startingSlot)
					break;
			}
			
			return null;
		}
	}
	
	immutable(K) add (immutable K key) {
		return add(key, hashKey(key));
	}
	
	immutable(K) add (immutable K key, hash_value precalcHash) {
		expandIfNeeded();
	
		debug {
			enforce(precalcHash == hashKey(key), "hash of key does not match precalculated hash");
		}
		
		auto slot = precalcHash & bucketMask;
		static if (CACHE) {
			if (buckets[slot].empty)
				++count;
			
			buckets[slot] = Entry(key, precalcHash);
			return key;
		} else {
			while (!buckets[slot].empty) {
				if (buckets[slot].hash == precalcHash && buckets[slot].key == key)
					return buckets[slot].key;
				
				slot = (slot + 1) & bucketMask;
			}
			
			buckets[slot] = Entry(key, precalcHash);
			++count;
			return key;
		}
	}
	
	void clear () {
		foreach (i; 0 .. capacity)
			buckets[i] = Entry();
		
		count = 0;
	}
	
	void remove (immutable K key) {
		remove(key, hashKey(key));
	}
	
	void remove (immutable K key, hash_value precalcHash) {
		debug {
			enforce(precalcHash == hashKey(key), "hash of key does not match precalculated hash");
		}
		
		auto slot = precalcHash & bucketMask;
		
		static if (CACHE) {
			if (buckets[slot].empty)
				return;
			
			--count;
		} else {
			for (;;) {
				if (buckets[slot].empty)
					return;
				else if (buckets[slot].hash == precalcHash || buckets[slot].key == key)
					break;
				
				slot = (slot + 1) & bucketMask;
			}
			
			auto nextSlot = (slot + 1) & bucketMask;
			while (!buckets[nextSlot].empty) {
				buckets[slot] = buckets[nextSlot];
				
				slot = nextSlot;
				nextSlot = (slot + 1) & bucketMask;
			}
			
			--count;
		}
		
		buckets[slot] = Entry();
	}

protected:
	struct Entry {
	public:
		immutable K key;
		immutable hash_value hash;
		bool empty = true;
		
		this (immutable K key, immutable hash_value hash) {
			this.key = key;
			this.hash = hash;
			this.empty = false;
		}
	}
	
	static if (is(K : const void[])) {
		final pure hash_value hashKey (immutable K key) const {
			return murmur_hash(key);
		}
	} else {
		final hash_value hashKey (immutable K key) const {
			static if (__traits(compiles, key.toHash()))
				return key.toHash();
			else {
				// stupid Object const-incorrectness
				auto deconst = cast(K)key;
				return deconst.toHash();
			}
		}
	}
	
	void expandIfNeeded () {
		auto newCount = count + 1;
	
		// optimize for 70% load
		if (newCount > capacity * 7 / 10)
			capacity = newCount + newCount * 3 / 10;
	}

	Entry[] buckets;
	hash_value bucketMask;
	size_t count;
}
