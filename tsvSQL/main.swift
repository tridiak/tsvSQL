//
//  main.swift
//  tsvSQL
//
//  Created by tridiak on 22/10/22.
//

import Foundation

enum Option {
	case header
	case sqlTable
	case sqlCreate
	case all
}

/*
tsvSQL <path/to/tsv/file> header|sqlTable|sqlCreate (null=<word>,...) (keywordSuffix=<string>) (ignoreFirstLine)
		(tableName=<name>) (colType=<name>:<type>)
	if 'null' is present, any word passed is ignored for determining type for column.
	
	'sqlCreate' outputs possible INSERT INTO command. Requires 'tableName' be passed.
	'header' outputs the possible types for each column. By default, it will use the most encompassing type
		listed. Least to most: boolean (TINYINT), INT, DECIMAL, DATE, STRING.
		Decimal point count for SQL double type will be based on double with most dps.
 		INT will be one of TINYINT, SMALLINT or INT depending on the largest integer value.
 		String will be on of VARCHAR(31), VARCHAR(127), VARCHAR(255) or TEXT depending on largest
 			string length.
	
 	'keywordSuffix' is what is appended to first line fields if it matches an SQL keyword. Default is 'X'.
		Max length is 8 characters.
	
	if 'ignoreFirstLine' is passed, the first line is not treated as the header and the column names will be
		col_N where N is an incrementing integer starting from zero.

	'sqlTable' outputs possible CREATE TABLE command. Requires 'tableName' be passed.
		Floating point values will use the DECIMAL type unless overriden by 'colType'.
	
	'colType' sets the type for the column, not what the tool thinks it will be.
		If a value is not valid for the type, the type will be set to NULL
		This option can be passed multiple times.
 		Only valid for sqlTable option.
 		Types allowed: text (TEXT), vc255 (VARCHAR(255)), vc127 (VARCHAR(127)), vc31 (VARCHAR(31)),
 			decimal_NN_MM (DECIMAL(NN,MM)), i8 (TINYINT), ui8 (TINYINT UNSIGNED),
 			i16 (SMALLINT), ui16 (SMALLINT UNSIGNED), i32 (INT), ui32 (INT UNSIGNED),
 			i64 (BIGINT), ui64 (BIGINT UNSIGNED), bool (TINYINY), date (DATE)
*/

if CommandLine.argc <= 1 {
	BlabHelp()
	exit(0)
}

var opt : Option? = nil
var nullAry : [String] = []
var keywordSuffix = "X"
var ignore1stLine = false
var tableName : String? = nil
var colTypes : [String:TSVFile.DataType] = [:]
var badLines = false

let path = CommandLine.arguments[1]

for idx in 2..<CommandLine.argc {
	let s = CommandLine.arguments[Int(idx)]
	if s == "header" { opt = .header; continue }
	if s == "sqlCreate" { opt = .sqlCreate; continue }
	if s == "sqlTable" { opt = .sqlTable; continue }
	if s == "sqlAll" { opt = .all; continue }
	if s == "badLines" { badLines = true; continue }
	
	let parts = s.BeforeAndAfter(marker: "=")
	
	if s.FirstPartIs("null=") {
		if parts.after == nil {
			print("Empty 'null' argument")
			exit(1)
		}
		nullAry = parts.after!.split(separator: ",").map { S in
			return S.trimmingCharacters(in: .whitespaces)
		}
		continue
	}
	
	if s == "ignoreFirstList" {
		ignore1stLine = true
		continue
	}
	
	if s.FirstPartIs("keywordSuffix=") {
		if parts.after == nil || parts.after!.trimmingCharacters(in: .whitespaces).isEmpty {
			print("Empty 'keywordSuffix' argument")
			exit(1)
		}
		
		keywordSuffix = String(parts.after!.prefix(8))
		continue
	}
	
	if s.FirstPartIs("tableName=") {
		if parts.after == nil || parts.after!.trimmingCharacters(in: .whitespaces).isEmpty {
			print("Empty 'keywordSuffix' argument")
			exit(1)
		}
		
		tableName = String(parts.after!.prefix(32))
		continue
	}
	
	if s.FirstPartIs("colType=") {
		if parts.after == nil || parts.after!.trimmingCharacters(in: .whitespaces).isEmpty {
			print("Empty 'colType' arguments")
			exit(1)
		}
		
		let nameTypeParts = parts.after!.BeforeAndAfter(marker: ":")
		if nameTypeParts.after == nil {
			print("Missing argument after ':'")
			exit(1)
		}
		
		guard let dt = TSVFile.UserTypeToDataType(item: nameTypeParts.after!.lowercased()) else {
			print("Unknown type \(nameTypeParts.after!)")
			exit(1)
		}
		
		colTypes[nameTypeParts.before] = dt
		continue
	}
	
	print("Invalid argument: \(s)")
	exit(1)
}

if opt == nil {
	print("'header, sqlTable or sqlCreate must be passed")
	exit(1)
}
do {
	let tsv = try TSVFile(path: path, nullAry: nullAry, keywordSuffix: keywordSuffix, ignore1stLine: ignore1stLine,
		colTypes: colTypes)
	TSVFile.nullValues = nullAry
	
	if opt == .header {
		tsv.OutputHeaderTypes()
	}
//	else if opt == .all {
//		tsv.OutputAll()
//	}
	else if opt == .sqlTable {
		if tableName == nil {
			print("'sqlTable' requires a table name")
			exit(1)
		}
		tsv.OutputSQLTable(suffix: keywordSuffix, tableName: tableName!)
	}
	else if opt == .sqlCreate {
		if tableName == nil {
			print("'sqlTable' requires a table name")
			exit(1)
		}
		if badLines {
			print(tsv.BadLines())
		}
		else {
			tsv.OutputSQLCreate(suffix: keywordSuffix, tableName: tableName!)
		}
	}
	else if opt == .all {
		if tableName == nil {
			print("'sqlTable' requires a table name")
			exit(1)
		}
		
		tsv.OutputSQLTable(suffix: keywordSuffix, tableName: tableName!)
		print("\n")
		tsv.OutputSQLCreate(suffix: keywordSuffix, tableName: tableName!)
	}
}
catch TSVEx.noFirstLine {
	print("Empty file or invalid first line")
	exit(1)
}
catch TSVEx.noSuchFile {
	print("\(path) is not a file or is not present")
	exit(1)
}


