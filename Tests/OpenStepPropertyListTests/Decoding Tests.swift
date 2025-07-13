import Testing
import OpenStepPropertyList
import Foundation

struct Decoding {
	@Test func errors() async throws {
		#expect {
			try PropertyList(decoding: "")
		} throws: { error in
			guard let error = error as? PropertyList.DecodingError,
			      error.contentError == PropertyList.ContentError.missingContent else {
				return false
			}
			return true
		}
		
		#expect {
			try PropertyList(decoding: "{}a")
		} throws: { error in
			guard let error = error as? PropertyList.DecodingError,
			      error.contentError == PropertyList.ContentError.oversuppliedContent else {
				return false
			}
			return true
		}
	}
	
	struct StringValue {
		@Test(
			arguments: [
				("word", PropertyList.string("word", options: .unquoted)),
				("0", PropertyList.string("0", options: .unquoted)),
				("123", PropertyList.string("123", options: .unquoted)),
				("-123", PropertyList.string("-123", options: .unquoted)),
				("+123", PropertyList.string("+123", options: .unquoted)),
				("123.456", PropertyList.string("123.456", options: .unquoted)),
				("$123", PropertyList.string("$123", options: .unquoted)),
				(".word", PropertyList.string(".word", options: .unquoted)),
				("some_word", PropertyList.string("some_word", options: .unquoted)),
				("some-word", PropertyList.string("some-word", options: .unquoted)),
				("az/AZ/09", PropertyList.string("az/AZ/09", options: .unquoted)),
			]
		) func unquotedContent(testCase: (input: String, expectedOutput: PropertyList)) async throws {
			let output = try PropertyList(decoding: testCase.input)
			#expect(output == testCase.expectedOutput)
		}
		
		@Test(
			arguments: [
				// double quoted
				(#""""#, PropertyList.string("", options: [])),
				(#""word""#, PropertyList.string("word", options: [])),
				(#""\"""#, PropertyList.string("\"", options: [])),
				(#""\'""#, PropertyList.string("'", options: [])),
				(#""'""#, PropertyList.string("'", options: [])),
				// single quoted
				(#"''"#, PropertyList.string("", options: [])),
				(#"'word'"#, PropertyList.string("word", options: [])),
				(#"'\"'"#, PropertyList.string("\"", options: [])),
				(#"'\''"#, PropertyList.string("'", options: [])),
				(#"'"'"#, PropertyList.string("\"", options: [])),
			]
		) func quoting(testCase: (input: String, expectedOutput: PropertyList)) async throws {
			let output = try PropertyList(decoding: testCase.input)
			#expect(output == testCase.expectedOutput)
		}
		
		@Test(
			arguments: [
				(#""\?""#, PropertyList.string("?", options: [])),
				(#""\\""#, PropertyList.string("\\", options: [])),
				(#""\t""#, PropertyList.string("\t", options: [])),
				(#""\n""#, PropertyList.string("\n", options: .escapedLineFeedsNamed)),
				(#""\r""#, PropertyList.string("\r", options: [])),
				(#""\r\n""#, PropertyList.string("\r\n", options: .escapedLineFeedsNamed)),
				("\"some\nword\"", PropertyList.string("some\nword", options: [])),
				("\"some\\nword\"", PropertyList.string("some\nword", options: .escapedLineFeedsNamed)),
				("\"some\\012word\"", PropertyList.string("some\nword", options: .escapedLineFeedsOctal)),
				("\"some\\\nword\"", PropertyList.string("some\nword", options: .escapedLineFeedsLiteral)),
				(#""\141bc""#, PropertyList.string("abc", options: [])),
				(#""\141\142c""#, PropertyList.string("abc", options: [])),
				(#""\141\142\143""#, PropertyList.string("abc", options: [])),
				(#""\U0061bc""#, PropertyList.string("abc", options: [])),
				(#""\U0061\U0062c""#, PropertyList.string("abc", options: [])),
				(#""\U0061\U0062\U0063""#, PropertyList.string("abc", options: [])),
			]
		) func escapeSequences(testCase: (input: String, expectedOutput: PropertyList)) async throws {
			let output = try PropertyList(decoding: testCase.input)
			#expect(output == testCase.expectedOutput)
		}
		
		@Test(
			arguments: [
				// non-minimal encoding
				([0x22, 0xC0, 0x80, 0x22], PropertyList.ContentError.nonUTF8StringContents),
				([0x22, 0xE0, 0x80, 0x80, 0x22], PropertyList.ContentError.nonUTF8StringContents),
				// UTF-16 surrogates
				([0x22, 0xED, 0xA0, 0x80, 0x22], PropertyList.ContentError.nonUTF8StringContents),
				([0x22, 0xED, 0xBF, 0xBF, 0x22], PropertyList.ContentError.nonUTF8StringContents),
			]
		) func dataErrors(testCase: (input: [UInt8], expectedError: PropertyList.ContentError)) async throws {
			#expect {
				try PropertyList(decoding: testCase.input)
			} throws: { error in
				guard let error = error as? PropertyList.DecodingError,
				      error.contentError == testCase.expectedError else {
					return false
				}
				return true
			}
		}
		
		@Test(
			arguments: [
				(#"""#, PropertyList.ContentError.missingClosingQuote),
				(#""unclosed"#, PropertyList.ContentError.missingClosingQuote),
				(#""\200""#, PropertyList.ContentError.nonASCIIOctalCodeStringEscapeSequence(2, 0, 0)),
				(#""\400""#, PropertyList.ContentError.octalCodeOverflowStringEscapeSequence(4, 0, 0)),
				(#""\UD800\UDC00""#, PropertyList.ContentError.nonUnicodeScalarHexadecimalCodeStringEscapeSequence(55296)),
				(#""\U192""#, PropertyList.ContentError.incompleteHexadecimalCodeStringEscapeSequence),
			]
		) func stringErrors(testCase: (input: String, expectedError: PropertyList.ContentError)) async throws {
			#expect {
				try PropertyList(decoding: testCase.input)
			} throws: { error in
				guard let error = error as? PropertyList.DecodingError,
				      error.contentError == testCase.expectedError else {
					return false
				}
				return true
			}
		}
	}
	
	struct DataValue {
		@Test(
			arguments: [
				("<>", PropertyList.data([])),
				("< >", PropertyList.data([])),
				("<00>", PropertyList.data([0x00])),
				("<1A>", PropertyList.data([0x1A])),
				("<1a>", PropertyList.data([0x1A])),
				("<B2>", PropertyList.data([0xB2])),
				("<b2>", PropertyList.data([0xB2])),
				("<FF>", PropertyList.data([0xFF])),
				("<FFFFFF>", PropertyList.data([0xFF, 0xFF, 0xFF])),
				("<FF FF FF>", PropertyList.data([0xFF, 0xFF, 0xFF])),
				("<F F F F F F>", PropertyList.data([0xFF, 0xFF, 0xFF])),
				("< F F >", PropertyList.data([0xFF])),
			]
		) func decode(testCase: (input: String, expectedOutput: PropertyList)) async throws {
			let output = try PropertyList(decoding: testCase.input)
			#expect(output == testCase.expectedOutput)
		}
		
		@Test(
			arguments: [
				("<", PropertyList.ContentError.missingDataEnd),
				("<ZZ>", PropertyList.ContentError.nonHexadecimalHighByteData(0x5A)),
				("<F>", PropertyList.ContentError.missingHexadecimalLowByteData),
				("<FF F>", PropertyList.ContentError.missingHexadecimalLowByteData),
				("<FF FZ>", PropertyList.ContentError.nonHexadecimalLowByteData(0x5A)),
			]
		) func errors(testCase: (input: String, expectedError: PropertyList.ContentError)) async throws {
			#expect {
				try PropertyList(decoding: testCase.input)
			} throws: { error in
				guard let error = error as? PropertyList.DecodingError,
				      error.contentError == testCase.expectedError else {
					return false
				}
				return true
			}
		}
	}
	
	struct ArrayValue {
		@Test(
			arguments: [
				("()", PropertyList.array([], options: [])),
				("(\n)", PropertyList.array([], options: .breakElementsOntoLines)),
				("(1)", PropertyList.array([
					.string("1", options: .unquoted),
				], options: [])),
				("(1, 2)", PropertyList.array([
					.string("1", options: .unquoted),
					.string("2", options: .unquoted),
				], options: .spaceSeparator)),
				("(1, 2, )", PropertyList.array([
					.string("1", options: .unquoted),
					.string("2", options: .unquoted),
				], options: [.trailingComma, .spaceSeparator])),
				("(\n1,\n2\n)", PropertyList.array([
					.string("1", options: .unquoted),
					.string("2", options: .unquoted),
				], options: .breakElementsOntoLines)),
				("( 1 , 2 , 3 )", PropertyList.array([
					.string("1", options: .unquoted),
					.string("2", options: .unquoted),
					.string("3", options: .unquoted),
				], options: .spaceSeparator)),
				("(1,2,3)", PropertyList.array([
					.string("1", options: .unquoted),
					.string("2", options: .unquoted),
					.string("3", options: .unquoted),
				], options: [])),
				("(())", PropertyList.array([
					.array([], options: []),
				], options: [])),
				("(\n(\n)\n)", PropertyList.array([
					.array([], options: .breakElementsOntoLines),
				], options: .breakElementsOntoLines)),
				("((),(()),((),()))", PropertyList.array([
					.array([], options: []),
					.array([
						.array([], options: []),
					], options: []),
					.array([
						.array([], options: []),
						.array([], options: []),
					], options: []),
				], options: [])),
				("((\n))", PropertyList.array([
					.array([], options: .breakElementsOntoLines),
				], options: [])),
			]
		) func decode(testCase: (input: String, expectedOutput: PropertyList)) async throws {
			let output = try PropertyList(decoding: testCase.input)
			#expect(output == testCase.expectedOutput)
		}
		
		@Test(
			arguments: [
				("(", PropertyList.ContentError.missingContent),
				("(1", PropertyList.ContentError.missingClosingParenthesis),
				("(1, 2", PropertyList.ContentError.missingClosingParenthesis),
				("(1, 2,", PropertyList.ContentError.missingContent),
			]
		) func errors(testCase: (input: String, expectedError: PropertyList.ContentError)) async throws {
			#expect {
				try PropertyList(decoding: testCase.input)
			} throws: { error in
				guard let error = error as? PropertyList.DecodingError,
				      error.contentError == testCase.expectedError else {
					return false
				}
				return true
			}
		}
	}
	
	struct DictionaryValue {
		@Test(
			arguments: [
				("{}", PropertyList.dictionary([:], order: nil, options: [])),
				("{\n}", PropertyList.dictionary([:], order: nil, options: .breakElementsOntoLines)),
				("{a = 1;}", PropertyList.dictionary([
					.init(string: "a", options: .unquoted): .string("1", options: .unquoted),
				], order: nil, options: [])),
				("{a = 1; b = 2;}", PropertyList.dictionary([
					.init(string: "a", options: .unquoted): .string("1", options: .unquoted),
					.init(string: "b", options: .unquoted): .string("2", options: .unquoted),
				], order: nil, options: [])),
				("{\na = 1;\nb = 2;\n}", PropertyList.dictionary([
					.init(string: "a", options: .unquoted): .string("1", options: .unquoted),
					.init(string: "b", options: .unquoted): .string("2", options: .unquoted),
				], order: nil, options: .breakElementsOntoLines)),
				("{ a = 1 ; b = 2 ; }", PropertyList.dictionary([
					.init(string: "a", options: .unquoted): .string("1", options: .unquoted),
					.init(string: "b", options: .unquoted): .string("2", options: .unquoted),
				], order: nil, options: [])),
				("{a=1;b=2;}", PropertyList.dictionary([
					.init(string: "a", options: .unquoted): .string("1", options: .unquoted),
					.init(string: "b", options: .unquoted): .string("2", options: .unquoted),
				], order: nil, options: [])),
				("{a = {b = {c = {d = {e1 = (); e2 = ();};};};};}", PropertyList.dictionary([
					.init(string: "a", options: .unquoted): .dictionary([
						.init(string: "b", options: .unquoted): .dictionary([
							.init(string: "c", options: .unquoted): .dictionary([
								.init(string: "d", options: .unquoted): .dictionary([
									.init(string: "e1", options: .unquoted): .array([], options: []),
									.init(string: "e2", options: .unquoted): .array([], options: []),
								], order: nil, options: []),
							], order: nil, options: []),
						], order: nil, options: []),
					], order: nil, options: []),
				], order: nil, options: [])),
				("{a = {\nb = 1;\n};}", PropertyList.dictionary([
					.init(string: "a", options: .unquoted): .dictionary([
						.init(string: "b", options: .unquoted): .string("1", options: .unquoted),
					], order: nil, options: .breakElementsOntoLines),
				], order: nil, options: [])),
			]
		) func decode(testCase: (input: String, expectedOutput: PropertyList)) async throws {
			let output = try PropertyList(decoding: testCase.input)
			#expect(output == testCase.expectedOutput)
		}
		
		@Test(
			arguments: [
				("{", PropertyList.ContentError.missingContent),
				("{key = value;", PropertyList.ContentError.missingContent),
				("{key", PropertyList.ContentError.missingEqualSignInDictionary),
				("{key =", PropertyList.ContentError.missingContent),
				("{key = value}", PropertyList.ContentError.missingSemicolonInDictionary),
				("{() = value;}", PropertyList.ContentError.nonStringKey),
			]
		) func errors(testCase: (input: String, expectedError: PropertyList.ContentError)) async throws {
			#expect {
				try PropertyList(decoding: testCase.input)
			} throws: { error in
				guard let error = error as? PropertyList.DecodingError,
				      error.contentError == testCase.expectedError else {
					return false
				}
				return true
			}
		}
	}
	
	struct Trivia {
		@Test(
			arguments: [
				// '/' is a valid character in unquoted string:
				// the spaces after strings below are needed, otherwise comment merges with value
				"#(#)#",
				"#(#value #,#value2 #)#",
				"#(#value #,#value2 #,#)#",
				"#{#}#",
				"#{#key #=#value #;#key2 #=#value2 #;#}#",
			],
			[
				"",
				" ",
				"\n",
				" \n ",
				"\r\n",
				"\u{2028}\u{2029}",
				"/**/",
				"/*//*/",
				" /* () */ ",
				" /* // */ ",
				"//\n",
			]
		) func decode(inputPattern: String, trivia: String) async throws {
			let input = inputPattern.replacing("#", with: trivia)
			_ = try PropertyList(decoding: input)
		}
	}
	
	@Test(
		arguments: [
			("/", PropertyList.ContentError.incompleteCommentStart),
			("/+", PropertyList.ContentError.illegalCommentStart(0x2B)),
			("/a", PropertyList.ContentError.illegalCommentStart(0x61)),
			("/*", PropertyList.ContentError.missingCommentEnd),
			("/* some comment", PropertyList.ContentError.missingCommentEnd),
		]
	) func errors(testCase: (input: String, expectedError: PropertyList.ContentError)) async throws {
		#expect {
			try PropertyList(decoding: testCase.input)
		} throws: { error in
			guard let error = error as? PropertyList.DecodingError,
			      error.contentError == testCase.expectedError else {
				return false
			}
			return true
		}
	}
}
