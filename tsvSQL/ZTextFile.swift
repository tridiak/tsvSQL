//
//  ZTextFile.swift
//  Swift-Utilities
//
//  Created by tridiak on 16/11/22.
//  Copyright © 2022 tridiak. All rights reserved.
//

import Darwin
import Foundation
// Rewrite of ATextFile. Does not inherit from ABinaryFile.

// This file loads the entire file into memory. So either it works or the
// system throws a fit and kills the app.
class ZTextFile : Sequence {
	enum NewLine {
		case classicMac
		case unix
		case windows
		// CR 13, LF 10, CRLF 13 10
	}
	
	private(set) var textLF : NewLine = .unix
	
	// The file data.
	private var blob : UnsafeMutableRawPointer!
	// Above blob as a UInt8 array.
	private var bytePtr : UnsafePointer<UInt8>!
	private var dataSize : UInt64 = 0
	
	init?(path: String, linefeed LF: NewLine = .unix) {
		textLF = LF
		
		//---------------------------------------------------
		var st = stat()
		var res = stat(path, &st)
		if res != 0 { return nil }
		
		if (st.st_mode & S_IFMT) != S_IFREG { return nil }
		
		var F : UnsafeMutablePointer<FILE>!
		F = fopen(path, "r")
		
		if F == nil { return nil }
		
		defer {
			fclose(F)
		}
		
		blob = UnsafeMutableRawPointer.allocate(byteCount: Int(st.st_size), alignment: 1)
		if blob == nil { return nil }
		
		dataSize = UInt64(st.st_size)
		if dataSize > 0 {
			let itemsRead = fread(blob, Int(dataSize), 1, F)
			
			if itemsRead == 0 {
				blob.deallocate()
				return nil
			}
			
			bytePtr = UnsafePointer(blob!.bindMemory(to: UInt8.self, capacity: Int(dataSize)))
			
			if dataSize >= Int.max { return nil }
			//-----------------------------------------------------------
			
			if textLF == .windows {
				if !RetrieveLinesWindows() { return nil }
			}
			else {
				if !RetrieveLines() { return nil }
			}
		}
	}
	
	deinit {
		if blob != nil {
			blob.deallocate()
		}
	}
	
	convenience init?(desc: Int32, linefeed LF: NewLine = .unix) {
		var buffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
		if fcntl(desc, F_GETPATH, &buffer) == -1 { return nil }
		
		let path = String(cString: buffer)
		
		self.init(path: path, linefeed: LF)
	}
	
	//--------------------
	// 'idx' is inout because windows new line is two characters and we
	// will need to increment the index.
	private func IsLineFeed(idx : inout Int) -> Bool {
		let C = bytePtr[idx]
		
		switch textLF {
			case .classicMac:
				return C == 13
			case .unix:
				return C == 10
			case .windows:
				if C != 13 { return false }
				if idx + 1 == dataSize { return false }
				if C == 10 {
					idx += 1
					return true
				}
				return false
		}
	} // IsLineFeed()
	
	private var lines : [String] = []
	var lineCount : UInt { return UInt(lines.count) }
	// Will throw exception if UTF8 character sequence is invalid
	private func RetrieveLines() -> Bool {
		var s : [UInt8] = []
		if dataSize == 0 { return true }
		if dataSize == 1 {
			if (textLF == .unix && bytePtr[0] != 10) || (textLF == .classicMac && bytePtr[0] != 13) {
				s.append(bytePtr[0])
				guard let strg = String(bytes: s, encoding: .utf8) else { return false }
				lines.append(strg)
			}
			return true
		}
		
		var idx : Int = 0
		var lastIsLF = true
		for _ in 0..<dataSize {
			
			if IsLineFeed(idx: &idx) {
				guard let strg = String(bytes: s, encoding: .utf8) else { return false }
				lines.append(strg)
				s.removeAll()
				lastIsLF = true
			}
			else {
				s.append(bytePtr[idx])
				lastIsLF = false
			}
			
			idx += 1
		}
		
		if !lastIsLF {
			guard let strg = String(bytes: s, encoding: .utf8) else { return false }
			lines.append(strg)
		}
		
		blob = nil
		bytePtr = nil
		
		return true
	} // RetrieveLines()
	
	private func RetrieveLinesWindows() -> Bool {
		var s : [UInt8] = []
		if dataSize == 0 { return true }
		if dataSize == 1 {
			s.append(bytePtr[0])
			guard let strg = String(bytes: s, encoding: .utf8) else { return false }
			lines.append(strg)
			
			return true
		}
		if dataSize == 2 {
			if bytePtr[0] == 13 && bytePtr[1] == 10  { return true }
			guard let strg = String(bytes: s, encoding: .utf8) else { return false }
			lines.append(strg)
			
			return true
		}
		var idx : Int = 0
		var lastIsLF = true
		while idx < dataSize {
			if idx < dataSize - 1 && bytePtr[idx] == 13 && bytePtr[idx + 1] == 10 {
				guard let strg = String(bytes: s, encoding: .utf8) else { return false }
				lines.append(strg)
				s.removeAll()
				lastIsLF = true
				idx += 1
			}
			else {
				s.append(bytePtr[idx])
				lastIsLF = false
			}
			
			idx += 1
		}
		if !lastIsLF {
			guard let strg = String(bytes: s, encoding: .utf8) else { return false }
			lines.append(strg)
		}
		return true
	}
	
	subscript(idx: UInt) -> String? {
		if idx >= lineCount || idx >= Int.max { return nil }
		return lines[Int(idx)]
	}
	
	func makeIterator() -> ZTIterator {
		return ZTIterator(DC: self, index: 0)
	}
}

//--------------------------------
// MARK:- ATF Iterator

public struct ZTIterator : IteratorProtocol {
	let DC : ZTextFile
	var index : Int = 0
	
	public mutating func next() -> String? {
		let name = DC[UInt(index)]
		
		index += 1
		return name
		
	}
	
	public typealias Element = String
}
