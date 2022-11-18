//
//  TSVFile.swift
//  tsvSQL
//
//  Created by tridiak on 22/10/22.
//

import Foundation

enum TSVEx : Error {
	case noSuchFile
	case noFirstLine
}


class TSVFile {
	private let firstLine : String
	private var lines : [[String]] = []
	
	enum BroadDataType : String {
		// Default
		case string = "string"
		// (-)(digit)(.)digit
		case double = "double"
		// (-)digit
		case int = "int"
		// 0 or 1 only; T or F; true or false
		case boolean = "boolean"
		//
		case date = "date"
		
		static func Broadest(items: Set<BroadDataType>) -> BroadDataType {
			if items.isEmpty { return .string }
			if items.contains(.string) { return .string }
			if items.contains(.date) { return .date }
			if items.contains(.double) { return .double }
			if items.contains(.int) { return .int }
			return .boolean
		}
		
		var sqlType : String {
			switch self {
				case .string:
					return "TEXT";
				case .double:
					return "FLOAT(32)"
				case .int:
					return "INT";
				case .boolean:
					return "BOOL";
				case .date:
					return "DATE";
			}
		}
	}
	
	enum DataType : Hashable {
		case text
		case varchar(UInt8)
		case decimal(UInt8,UInt8)
		case bool
		case int(UInt8)
		case uint(UInt8)
		case date
		
		static func == (lhs: DataType, rhs: DataType) -> Bool {
			switch (lhs, rhs) {
				case (.text, .text): return true
				case (.varchar, .varchar): return true
				case (.decimal, .decimal): return true
				case (.bool, .bool): return true
				case (.int, .int): return true
				case (.uint, .uint): return true
				case (.date, .date): return true
				default: return false
			}
		}
		
		static func Broadest(items: Set<DataType>) -> DataType {
			if items.isEmpty || items.contains(.text) { return .text }
			if let i = items.firstIndex(of: .varchar(0)) { return items[i] }
			if items.firstIndex(of: .date) != nil { return .date }
			if let i = items.firstIndex(of: .decimal(0, 0)) { return items[i] }
			if let i = items.firstIndex(of: .uint(0)), let j = items.firstIndex(of: .int(0)) {
				if case let .int(I) = items[i], case let .uint(J) = items[j] {
					if I > J { return items[i] }
					return items[j]
				}
			}
			return .bool
		}
		
		func AsBroadType() -> BroadDataType {
			switch self {
				case .text:
					return .string
				case .varchar(_):
					return .string
				case .decimal(_, _):
					return .double
				case .bool:
					return .int
				case .int(_):
					return .int
				case .uint(_):
					return .int
				case .date:
					return .date
			}
		}
	}
	
	static func UserTypeToDataType(item: String) -> DataType? {
		switch item {
			case "text":
				return .text
			case "vc255":
				return .varchar(255)
			case "vc127":
				return .varchar(127)
			case "vc31":
				return .varchar(31)
			case _ where item.FirstPartIs("decimal"):
				let parts = item.split(separator: "_")
				if parts.count != 3 { return nil }
				
				if let n = UInt8(parts[1]), let m = UInt8(parts[2]) {
					return .decimal(m, n)
				}
				return nil
			case "i8": return .int(8)
			case "ui8": return .uint(8)
			case "i16": return .int(16)
			case "ui16": return .uint(16)
			case "i32": return .int(32)
			case "ui32": return .uint(32)
			case "i64": return .int(64)
			case "ui64": return .uint(64)
			case "bool": return .bool
			case "date": return .date
			default:
				return nil
		}
	}
	
	static func DummyDataFor(type: DataType) -> String {
		switch type {
			case .text:
				return ""
			case .varchar(_):
				return ""
			case .decimal(_, _):
				return "0"
			case .bool:
				return "0"
			case .int(_):
				return "0"
			case .uint(_):
				return "0"
			case .date:
				return "2000-1-1"
		}
	}
	
	// Header data type is guesswork. Data type may change as lines are parsed.
	private struct Header {
		init(name: String) {
			self.name = name.replacingOccurrences(of: " ", with: "_")
		}
		let name : String
		//
		var type = Set<BroadDataType>()
		
		static let boolVals = ["0", "1", "t", "f", "true", "false"]
		
		// Headers that have multiple type.
		var multiTypes : Bool { return type.count > 1 }
		
		fileprivate var widest : [BroadDataType:UInt] = [
			.string:0,
			.double:0,
			.int:0,
			.boolean:1,
			.date:0,
		]
		
		fileprivate var dpCount : UInt = 0
		
		mutating func SetType(item: String, nullAry : [String]) {
			let item = item.trimmingCharacters(in: .whitespacesAndNewlines)
			if item.isEmpty { return }
			if item.lowercased() == "null" { return }
			if nullAry.contains(item) {
				return
			}
			
			if TSVFile.Header.boolVals.contains(item.lowercased()) {
				type.insert(.boolean)
				return
			}
			
			if var J = Int.init(item) {
				var I = abs(J)
				if widest[.int]! < I { widest[.int] = UInt(I) }
				type.insert(.int)
				// If a double is present but the largest int is bigger, then the X,Y in DECIMAL(X,Y) will be too small
				if type.contains(.double) {
					let ct = String(J).count
					if widest[.double]! < ct { widest[.double] = UInt(ct) }
				}
				return
			}
			
			if var D = Double.init(item) {
				let I = String(D).count
				if widest[.double]! < I { widest[.double] = UInt(I) }
				if let idx = item.firstIndex(of: ".") {
					let K = item.distance(from: item.startIndex, to: idx)
					if dpCount < K {
						dpCount = UInt(K)
					}
				}
				type.insert(.double)
				return
			}
			
			if !item.isEmpty {
				if item.count > widest[.string]! { widest[.string] = UInt(item.count) }
				type.insert(.string)
			}
		}
		
		static var userType : [String:DataType] = [:]
		
		fileprivate func SQLType() -> String {
			let type = TSVFile.Header.userType[name]?.AsBroadType() ?? BroadDataType.Broadest(items: self.type)
			switch type {
				case .string:
					let len =  widest[.string]!
					if len > UInt8.max { return "TEXT" }
					if len > 127 { return "VARCHAR(255)"}
					if len > 31 { return "VARCHAR(127)"}
					return "VARCHAR(31)"
				case .double:
					return "DECIMAL(\(widest[.double]! + dpCount + 1),\(dpCount + 1))"
				case .int:
					let I = widest[.int]!
					if I < Int8.max { return "TINYINT" }
					if I < UInt8.max { return "TINYINT UNSIGNED" }
					if I < Int16.max { return "SMALLINT" }
					if I < UInt16.max { return "SMALLINT UNSIGNED" }
					if I < Int32.max { return "INT" }
					if I < UInt32.max { return "INT UNSIGNED" }
					return I < Int64.max ? "BIGINT" : "BIGINT UNSIGNED"
				case .boolean:
					return "TINYINT"
				case .date:
					return "TIMESTAMP"
			}
		}
		
		fileprivate func SQLDataType() -> DataType {
			let type = TSVFile.Header.userType[name]?.AsBroadType() ?? BroadDataType.Broadest(items: self.type)
			switch type {
				case .string:
					let len =  widest[.string]!
					if len > UInt8.max { return .text }
					if len > 127 { return .varchar(255)}
					if len > 31 { return .varchar(127)}
					return .varchar(31)
				case .double:
					return .decimal(UInt8(widest[.double]!), UInt8(dpCount))
				case .int:
					let I = widest[.int]!
					if I < Int8.max { return .int(8) }
					if I < UInt8.max { return .uint(8) }
					if I < Int16.max { return .int(16) }
					if I < UInt16.max { return .uint(16) }
					if I < Int32.max { return .int(32) }
					if I < UInt32.max { return .uint(32) }
					return .int(64)
				case .boolean:
					return .bool
				case .date:
					return .date
			}
		}
	} // Header
	
	private var headers : [Header] = []
	// If the line item count != headers count, then record it.
	
	struct BadLine : CustomStringConvertible {
		var description: String { return "\(lineNum)-\(colCount):\(line)"}
		
		let lineNum : UInt
		let line : String
		let colCount : UInt
	}
	
	private var badLines : [BadLine] = []
	
	func BadLines() -> String {
		var s = ""
		for bl in badLines {
			s += bl.description + "\n"
		}
		return s
	}
	
	private(set) var multiTypeError = false
	
	init(path: String, nullAry: [String], keywordSuffix : String = "X", ignore1stLine: Bool = false,
		 		colTypes: [String:DataType] = [:]) throws {
		
		Header.userType = colTypes
		
		guard let atf = ZBigTextFile(path: path) else { throw TSVEx.noSuchFile }
		if atf.lineCount == 0 { throw TSVEx.noFirstLine }
		firstLine = atf[0]!.trimmingCharacters(in: .whitespaces)
		if ignore1stLine {
			let ct = firstLine.split(separator: "\t").count
			for idx in 0..<ct {
				headers.append(Header(name: "col_\(idx)"))
			}
		}
		else {
			
			if firstLine.isEmpty { throw TSVEx.noFirstLine }
			
			let ary = firstLine.split(separator: "\t")
			for h in ary {
				headers.append(Header(name: String(h.trimmingCharacters(in: .whitespacesAndNewlines))))
			}
			if atf.lineCount == 1 { return }
		}
		
		let start = UInt(ignore1stLine ? 0 : 1)
		
		for idx in start..<atf.lineCount {
			guard let line = atf[idx] else { continue }
			let items = line.split(separator: "\t", omittingEmptySubsequences: false)
			if items.count != headers.count {
				badLines.append(BadLine(lineNum: UInt(idx), line: line, colCount: UInt(items.count)))
				continue
			}
			
			//FieldType(line: line)
			var l : [String] = []
			for (i, item) in items.enumerated() {
			//	print(String(item))
				headers[i].SetType(item: String(item), nullAry: nullAry)
				if !headers[i].multiTypes {
					multiTypeError = true
				}
				
				l.append(String(item))
			}
			lines.append(l)
		}
	} // init()
	
	func OutputHeaderTypes() {
		for header in headers {
			let h = header.type.map { TYP in
				return TYP.rawValue
			}
			print("\(header.name) : \(h.joined(separator: ","))")
		}
	}
	
	func OutputMultiTypes() {
		for h in headers {
			if h.multiTypes {
				print("\(h.name)", separator: "; ")
			}
		}
		print("\n")
	}
	
	private func FieldType(line: String) {
		let items = line.split(separator: "\t", omittingEmptySubsequences: false)
		if items.count != headers.count {
			return
		}
		
		for i in items {
			if Header.boolVals.contains(i.lowercased()) {
				print("\(i):boolean", terminator: "; ")
			}
			else if Int(i) != nil {
				print("\(i):int", terminator: "; ")
			}
			else if Double(i) != nil {
				print("\(i):double", terminator: "; ")
			}
			else {
				print("\(i):string", terminator: "; ")
			}
		}
		print("\n")
	}
	
	func OutputAll() {
		for idx in 0..<headers.count {
			var s = headers[idx].name + " : "
			for a in lines {
				s += a[idx] + " ; "
			}
			
			print(s)
		}
	}
	
	func OutputSQLTable(suffix: String, tableName: String) {
		if headers.isEmpty { return }
		var sql = "CREATE TABLE \(tableName) (\n";
		for header in headers {
			sql += ReservedWord(check:header.name, suffix: suffix) + " " + header.SQLType() + ",\n"
		}
		// Get rid of last comma
		sql = String(sql.dropLast(2))
		sql += ");"
		print(sql)
	}
	
	// sqlType is retrieved from Header.SQLType()
	private func TypeCorceCheck(item: String, sqlType: DataType) -> Bool {
		switch sqlType {
			case .text:
				return true
			case .varchar(let N):
				return item.utf8.count < N
			case .decimal(_, _):
				return Double(item) != nil
			case .bool:
				return ["0", "1", "t", "f", "true", "false"].contains(item.lowercased())
			case .int(let N):
				switch N {
					case 8: return Int8(item) != nil
					case 16: return Int16(item) != nil
					case 32: return Int32(item) != nil
					case 64: return Int64(item) != nil
					default: return false
				}
			case .uint(let N):
				switch N {
					case 8: return UInt8(item) != nil
					case 16: return UInt16(item) != nil
					case 32: return UInt32(item) != nil
					case 64: return UInt64(item) != nil
					default: return false
				}
			case .date:
				let df = DateFormatter()
				return df.date(from: "YYYY-MM-DD") != nil
		}
	}
	
	fileprivate func EscapeChars(s: String) -> String {
		return s.replacingOccurrences(of: "'", with: "''").replacingOccurrences(of: "\\", with: "\\\\")
			.replacingOccurrences(of: "\n", with: "").replacingOccurrences(of: "\r", with: "")
	}
	
	static var nullValues : [String] = []
	
	func OutputSQLCreate(suffix: String, tableName: String) {
		if headers.isEmpty { return }
		var sql = "INSERT INTO \(tableName) (\n";
		for header in headers {
			sql += ReservedWord(check:header.name, suffix: suffix) + ", "
		}
		// Get rid of last comma
		sql = String(sql.dropLast(2))
		sql += ")\n"
		sql += "VALUES\n"
		
		// If user has defined a specific type for a column, non-valid values
		// must be set to NULL.
		// Lines with item count != to header count will be skipped.
		
		for sublines in lines {
			if sublines.count != headers.count { continue }
			var idx = 0
			var r = "("
			for val in sublines {
				if TypeCorceCheck(item: EscapeChars(s:val), sqlType: headers[idx].SQLDataType()) {
					if val.isEmpty {
						r += "NULL,"
					}
					else {
						var v = EscapeChars(s: val)
						if TSVFile.nullValues.contains(v) {
							r += "NULL,"
						}
						else {
							r += "'\(v)',"
						}
					}
				}
				else {
					r += "NULL,"
				}
				idx += 1
			}
			r = String(r.dropLast())
			r += "),\n"
			sql += r
		}
		sql = String(sql.dropLast(2))
		sql += ";"
		print(sql)
	}
}
