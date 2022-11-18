//
//  SimpleOrderedCollection.swift
//  Swift-Utilities
//
//  Created by tridiak on 18/11/22.
//  Copyright © 2022 tridiak. All rights reserved.
//

import Foundation

// Because command line tools can't embed packages, this is a simple ordered dictionary for
// use by ZBigTextFile.
struct SimpleOrderedMap<K: Hashable & Comparable, V: Any> {
	private var keyValues : [(K, V)] = []
	private var keySet : Set<K> = Set()
	
	mutating func Add(key: K, value: V) {
		
		if let idx = keyValues.firstIndex(where: { (K, V) in
			return K == key
		}) {
			keyValues[idx] = (key, value)
		}
		else {
			keySet.insert(key)
			keyValues.append((key, value))
			keyValues.sort { V1, V2 in
				return V1.0 < V2.0
			}
		}
	}
	
	func Get(key: K) -> V? {
		if !keySet.contains(key) { return nil }
		return keyValues.first(where: { (K,V) in
			return K == key
		})!.1
	}
	
	mutating func removeAll() {
		keyValues.removeAll()
		keySet.removeAll()
	}
	
	@discardableResult mutating func Remove(key: K) -> V? {
		if !keySet.contains(key) { return nil }
		keySet.remove(key)
		let idx = keyValues.firstIndex(where: { (K, V) in
			return K == key
		})!
		
		let V = keyValues[idx]
		keyValues.remove(at: idx)
		
		return V.1
	}
	
	subscript(key: K) -> V? {
		get {
			return Get(key: key)
		}
		set(V) {
			if V == nil {
				Remove(key: key)
			}
			else {
				Add(key: key, value: V!)
			}
		}
	}
	
	var count : Int { return keySet.count }
	
	mutating func dropFirst(_ count: Int) {
		if count <= 0 { return }
		if count >= keySet.count {
			keyValues.removeAll()
			keySet.removeAll()
			return
		}
		
		_ = keyValues.dropFirst(count)
		keySet = Set(keyValues.map({ KV in
			return KV.0
		}) )
	}
}
