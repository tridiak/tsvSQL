//
//  CollectionUtilities.swift
//  Swift-Utilities
//
//  Created by tridiak on 2/10/19.
//  Copyright © 2019 tridiak. All rights reserved.
//

import Foundation

// MARK: Array
extension Array {
	mutating func Keep(first N: Int) {
		if N < 0 { return }
		if N == 0 { self.removeAll() }
		else if N < self.count {
			self.removeLast(self.count - N)
		}
	}
	
}

// MARK: Collection
extension Collection {
	// Get random element from collection. nil will only be returned if the collection is empty.
	func RandomElement() -> Element? {
		if self.isEmpty { return nil }
		if self.count == 1 { return self.first! }
		let A = Array(self)
		let R = Int(arc4random()) % self.count
		return A[R]
	}
}

extension Set {
	func join(separator: String) -> String where Element == String {
		var r = ""
		if self.isEmpty { return "" }
		if self.count == 1 { return self.first! }
		for s in self {
			r.append(s)
			r.append(separator)
		}
		return String(r.dropLast(separator.count))
	}
}
