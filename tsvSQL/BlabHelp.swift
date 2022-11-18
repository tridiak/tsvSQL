//
//  BlabHelp.swift
//  tsvSQL
//
//  Created by tridiak on 16/11/22.
//

import Foundation

func BlabHelp() {
	print("""
tsvSQL version 0.1. Nov 2022
	Simple tool that parses a tab separated file and outputs MySQL CREATE TABLE or INSERT sql statements.
	The first line will be considered the table column headers unless 'ignoreFirstLine' is passed.
	The first line is also used to determine the number of columns the table has. Lines with differing column counts
	will be ignored.

tsvSQL <path/to/tsv/file> header|sqlTable|sqlCreate|sqlAll (null=<word>,...) (keywordSuffix=<string>) (ignoreFirstLine)
		(tableName=<name>) (colType=<name>:<type>) (badLines)
	'null' is a list of words which are ignored by the tool when determining column type.

	'header' outputs the possible types for each column. By default, when generating the CREATE statement, it will use the most encompassing type
		listed. Least to most: boolean (TINYINT), INT, DECIMAL, DATE, STRING.
		Decimal point count for SQL double type will be based on double with most decimal points.
		INT will be one of TINYINT (UNSIGNED), SMALLINT (UNSIGNED), INT (UNSIGNED) or BIGINT depending on the largest integer value.
		String will be on of VARCHAR(31), VARCHAR(127), VARCHAR(255) or TEXT depending on largest
		string length.

	'keywordSuffix' is what is appended to first line fields if it matches an SQL keyword. Default is 'X'.
		Max length is 8 characters.

	if 'ignoreFirstLine' is passed, the first line is not treated as the header and the column names will be
		col_N where N is an incrementing integer starting from zero.
	
	If 'badLines' is passed, the tool will only out lines whose column count differs from the first line.
	The output for each line will be <line number>-<column count>:<line text>
	Must be passed with 'sqlCreate' option.

	'sqlTable' outputs possible CREATE TABLE command. Requires 'tableName' be passed.
		Floating point values will use the DECIMAL type unless overriden by 'colType'.

	'colType' sets the type for the column, not what the tool thinks it will be.
		If a value is not valid for the type, the type will be set to NULL.
		This option can be passed multiple times.
		Only valid for sqlTable option.
		Types allowed: text (TEXT), vc255 (VARCHAR(255)), vc127 (VARCHAR(127)), vc31 (VARCHAR(31)),
			decimal_NN_MM (DECIMAL(NN,MM)), i8 (TINYINT), ui8 (TINYINT UNSIGNED),
			i16 (SMALLINT), ui16 (SMALLINT UNSIGNED), i32 (INT), ui32 (INT UNSIGNED),
			i64 (BIGINT), ui64 (BIGINT UNSIGNED), bool (TINYINY), date (DATE)
 	
	'sqlCreate' outputs possible INSERT INTO command. Requires 'tableName' be passed.
	
	'sqlAll' outputs both 'sqlTable' and 'sqlCreate'. badLines option is ignored,
""")
}
