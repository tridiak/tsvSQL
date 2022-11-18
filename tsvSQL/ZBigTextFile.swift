//
//  ZBigTextFile.swift
//  Swift-Utilities
//
//  Created by tridiak on 16/11/22.
//  Copyright © 2022 tridiak. All rights reserved.
//

import Foundation
import OrderedCollections

// Class will throw exception if file changes
class ZBigTextFile : Sequence {
	enum NewLine {
		case classicMac
		case unix
		case windows
		// CR 13, LF 10, CRLF 13 10
	}
	
	private(set) var textLF : NewLine = .unix
	
	private var LFPos : [UInt] = []
	
	private let path : String
	private var openTime : CFAbsoluteTime = 0
	
	// Unix, Mac
	private func GetLFPositions(F : UnsafeMutablePointer<FILE>, size: UInt) -> Bool {
		if size == 0 {
			return true
		}
		if size == 1 {
			LFPos.append(1)
			return true
		}
		var idx = 0
		let LF = textLF == .unix ? 10 : 13
		
		while idx < size {
			let rd = fgetc(F)
			if rd == EOF {
				if ferror(F) != 0 {
					return false
				}
				break
			}
			//if feof(F) != 0 { break }
			
			if rd == LF {
				LFPos.append(UInt(idx))
			}
			idx += 1
		}
		// Add in another LF is last character is not a LF
		if LFPos.last! != size - 1 {
			LFPos.append(size)
		}
		
		return true
	}
	
	private func GetLFPositionsWindows(F : UnsafeMutablePointer<FILE>, size: UInt) -> Bool {
		if size == 0 {
			return true
		}
		if size == 1 {
			LFPos.append(1)
			return true
		}
		var idx = 0
		// Need to factor in the fact that windows LF/NL is 2 bytes and may occur at
		// the end of one 512 block and the start of another
		var maybeLF = false
		
		while idx < size {
			let rd = fgetc(F)
			if rd == EOF {
				if ferror(F) != 0 {
					return false
				}
				break
			}
			if maybeLF && rd == 10 {
				LFPos.append(UInt(idx))
				maybeLF = false
			}
			else if rd == 13 {
				maybeLF = true
			}
			
			idx += 1
		}
		
		if LFPos.last! != size - 1 {
			LFPos.append(size)
		}
		
		return true
	}
	
	private var F : UnsafeMutablePointer<FILE>! = nil
	
	init?(path: String, linefeed LF: NewLine = .unix) {
		textLF = LF
		self.path = path
		
		var st = stat()
		var res = stat(path, &st)
		if res != 0 { return nil }
		
		if (st.st_mode & S_IFMT) != S_IFREG { return nil }
		
		let fileSize = UInt(st.st_size)
		if fileSize >= Int.max { return nil }
		openTime = Double(st.st_mtimespec.tv_sec) // + CFAbsoluteTime(st.st_mtimespec.tv_nsec) / 1_000_000_000
		
		
		F = fopen(path, "r")
		
		if F == nil { return nil }
		
		defer {
		//	fclose(F)
		}
		
		if textLF == .windows {
			if !GetLFPositionsWindows(F: F, size: fileSize) { return nil }
		}
		else {
			if !GetLFPositions(F: F, size: fileSize) { return nil }
		}
	}
	
	deinit {
		if F != nil { fclose(F) }
	}
	
	var fileChanged : Bool {
		var st = stat()
		var res = stat(path, &st)
		if res != 0 { return true }
		if Double(st.st_mtimespec.tv_sec) != openTime { return true }
		return false
	}
	
	var lineCount : UInt {
		return UInt(LFPos.count)
	}
	
	private var lineCache : OrderedDictionary<UInt, String> = [:]
	private var _cacheLineCount : UInt16 = 500
	var cacheLineCount : UInt16 {
		get { return _cacheLineCount }
		set(V) {
			_cacheLineCount = V
			if lineCache.count > _cacheLineCount {
				_ = lineCache.dropFirst(lineCache.count - Int(_cacheLineCount))
			}
		}
	}
	
	private func AddLine(idx: UInt, s: String) {
		if _cacheLineCount == 0 { return }
		if _cacheLineCount == 1 {
			lineCache.removeAll()
			lineCache[idx] = s
			return
		}
		
		lineCache[idx] = s
		if lineCache.count > _cacheLineCount {
			_ = lineCache.dropFirst(Int(_cacheLineCount) / 2)
		}
	}
	
	subscript(idx: UInt) -> String? {
		if idx >= lineCount || idx >= Int.max { return nil }
		if fileChanged { return nil }
		
		if let s = lineCache[idx] { return s }
		
		var startIdx = idx == 0 ? 0 : LFPos[Int(idx) - 1] + 1
		var endIdx = LFPos[Int(idx)]
		
		if textLF == .windows { endIdx -= 1}
		
		fseek(F, Int(startIdx), SEEK_SET)
		
		var bytes : [UInt8] = []
		while startIdx < endIdx {
			let rd = fgetc(F)
			if rd == EOF { return nil }
			bytes.append(UInt8(rd))
			
			startIdx += 1
		}
		
		guard let line = String(bytes: bytes, encoding: .utf8) else { return nil }
		
		AddLine(idx: idx, s: line)
		
		return line
	}
	
	func makeIterator() -> ZBigTIterator {
		return ZBigTIterator(DC: self, index: 0)
	}
}

//--------------------------------
// MARK:- ATF Iterator

public struct ZBigTIterator : IteratorProtocol {
	let DC : ZBigTextFile
	var index : Int = 0
	
	public mutating func next() -> String? {
		let name = DC[UInt(index)]
		
		index += 1
		return name
		
	}
	
	public typealias Element = String
}
