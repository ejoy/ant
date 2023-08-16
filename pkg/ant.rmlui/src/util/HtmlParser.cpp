#include <util/HtmlParser.h>
#include <util/Log.h>

#include <assert.h>
#include <string.h>
#include <map>

namespace Rml {

static const char* g_ErrorList[] = {
	"No error",
	"Document is empty",
	"Invalid document format",
	"Invalid instance definition",
	"Missing closing tag",
	"Invalid element name",
	"Closing element does not match to open one",
	"Invalid comment declaration",
	"Invalid symbol within entity",
	"Invalid attribute name",
	"Invalid attribute description",
	"Unknown entity",
	"Root node is not closed",
	"End of file encountered",
	"Missing semicolumn",
	"Missing quote",
	"The text before root node is illegal",
	"The text after root node is illegal",
	"Whitespace after element symbol open is illegal",
	"Whitespace after element symbol close is illegal",
	"Whitespace after processing instruction close is illegal",
	"Missing closing tag or commentary does not closed",
	"Entity before document open root is illegal",
	"Duplicate attribute name",
	"Input data error"
};

const char* HtmlParserException::what() const noexcept {
	return g_ErrorList[(size_t)m_code];
}

const std::map<std::string, char> g_ListEntity = {
	{ "amp", '&'  },
	{ "lt",  '<'  },
	{ "gt",  '>'  },
	{ "quot",'\"' },
	{ "apos",'\'' }
};

static bool IsLetter(char c) {
	if (((unsigned char)c) < 127)
		return isalpha(c) ? true : false;
	return true;
}

static bool IsDigit(char c) {
	return isdigit((unsigned char)c) ? true : false;
}

static bool IsHexDigit(char c) {
	return isxdigit((unsigned char)c) ? true : false;
}

static bool IsSpace(char c) {
	return c == ' ' || c == '\n' || c == '\r' || c == '\t';
}

static bool IsFirstNameValid(char c) {
	if (c == '_') return true;
	if (IsLetter(c)) return true;
	return false;
}

static bool IsCharNameValid(char c) {
	if (c == '.' || c == '_' || c == '-' || c == ':') return true;
	if (IsLetter(c) || IsDigit(c)) return true;
	return false;
}

static std::string& SkipSpace(std::string& s) {
	for (ptrdiff_t i = s.size()-1; i >= 0; --i) {
		switch (s[i]) {
		case ' ':
		case '\t':
		case '\n':
		case '\r':
			break;
		default:
			s.erase(s.begin() + i + 1, s.end());
			return s;
		}
	}
	s.erase();
	return s;
}

void HtmlParser::Parse(std::string_view stream, bool inner, HtmlElement& root) {
    std::stack<HtmlElement*> stack;
	stack.push(&root);

	m_buf = stream;
	m_pos = 0;
	m_line = 0;
	m_column = 0;

	enum TEState {
		st_begin = 0,
		st_ready,
		st_text,
		st_script,
		st_style,
		st_open,
		st_analys,
		st_finish,
		st_finish_extra, 
	};
	TEState state = inner? st_ready: st_begin;
	bool open = inner;

	std::string temp;
	std::string accum;
	while (!IsEOF()) {
		char c = GetChar();

		switch (state) {
		case st_begin: {
			switch (c) {
			case '<':
				state = st_open;
				break;
			case ' ':
			case '\t':
			case '\n':
			case '\r':
				break;
			default:
				ThrowException(HtmlError::SPE_INVALID_FORMAT);
				break;
			}
			break;
		}
		case st_open: {
			switch (c) {
			case ' ':
			case '\t':
			case '\n':
			case '\r':
				ThrowException(HtmlError::SPE_WHITESPASE_OPEN);
				break;
			case '!':
				state = st_analys;
				break;
			case '/':
				EnterClosingElement(stack);
				if (stack.empty()) {
					state = st_finish;
					break;
				}
				state = st_ready;
				break;
			default:
				state = st_ready;
				if (EnterOpenElement(stack, c)) {
					HtmlElement& current = *stack.top();
					open = true;
					if (current.tag == "script") {
						state = st_script;
					}
					else if (current.tag == "style") {
						state = st_style;
					}
				}
				break;
			}
			break;
		}
		case st_analys: {
			switch (c) {
			case '-':
				EnterComment();
				state = st_ready;
				break;
			default:
				ThrowException(HtmlError::SPE_INVALID_INSTANCE);
				break;
			}
			break;
		}
		case st_ready: {
			switch (c) {
			case ' ':
			case '\t':
			case '\n':
			case '\r':
				break;
			case '<':
				state = st_open;
				break;
			case '&':
				if (!open)
					ThrowException(HtmlError::SPE_ENTITY_DOC_OPEN);
				EnterEntity(&temp);
				accum += temp;
				state = st_text;
				break;
			default:
				if (!open)
					ThrowException(HtmlError::SPE_TEXT_BEFORE_ROOT);
				accum += c;
				state = st_text;
				break;
			}
			break;
		}
		case st_script:
			switch (c) {
			case '<':
				if (m_buf[m_pos + 0] == '/'
					&& m_buf[m_pos + 1] == 's'
					&& m_buf[m_pos + 2] == 'c'
					&& m_buf[m_pos + 3] == 'r'
					&& m_buf[m_pos + 4] == 'i'
					&& m_buf[m_pos + 5] == 'p'
					&& m_buf[m_pos + 6] == 't'
					&& m_buf[m_pos + 7] == '>') {
					m_pos += 1;
					HtmlElement& current = *stack.top();
					current.children.emplace_back(HtmlString{accum});
					accum.erase();
					EnterClosingElement(stack);
					open = false;
					if (stack.empty()) {
						state = st_finish;
						break;
					}
					state = st_ready;
					break;
				}
				accum += c;
				break;
			default:
				accum += c;
				break;
			}
			break;
		case st_style:
			switch (c) {
			case '<':
				if (m_buf[m_pos + 0] == '/'
				 && m_buf[m_pos + 1] == 's'
				 && m_buf[m_pos + 2] == 't'
				 && m_buf[m_pos + 3] == 'y'
				 && m_buf[m_pos + 4] == 'l'
				 && m_buf[m_pos + 5] == 'e'
				 && m_buf[m_pos + 6] == '>') {
					m_pos += 1;
					HtmlElement& current = *stack.top();
					current.children.emplace_back(HtmlString{accum});
					accum.erase();
					EnterClosingElement(stack);
					open = false;
					if (stack.empty()) {
						state = st_finish;
						break;
					}
					state = st_ready;
					break;
				}
				accum += c;
				break;
			default:
				accum += c;
				break;
			}
			break;
		case st_text:
			switch (c) {
			case '<': {
				HtmlElement& current = *stack.top();
				current.children.emplace_back(HtmlString{ SkipSpace(accum) });
				accum.erase();
				state = st_open;
				break;
			}
			case '&':
				EnterEntity(&temp);
				accum = accum + temp;
				state = st_text;
				break;
			default:
				accum += c;
			}
			break;
		case st_finish:
			switch (c) {
			case ' ':
			case '\t':
			case '\n':
			case '\r':
				break;
			case '<':
				state = st_finish_extra;
				break;
			default:
				ThrowException(HtmlError::SPE_TEXT_AFTER_ROOT);
				break;
			}
			break;
		case st_finish_extra:
			switch (c) {
			case '!':
				EnterComment();
				state = st_finish;
				break;
			default:
				ThrowException(HtmlError::SPE_TEXT_AFTER_ROOT);
			}
		}
	}

	if (inner) {
		switch (state) {
		case st_begin:
			state = st_open;
			break;
		case st_text: {
			HtmlElement& current = *stack.top();
			current.children.emplace_back(HtmlString{ SkipSpace(accum) });
			accum.erase();
			state = st_open;
			break;
		}
		default:
			break;
		}
	}
	switch (state) {
	case st_begin:
		ThrowException(HtmlError::SPE_EMPTY);
		break;
	case st_ready:
		if (stack.size() != 1)
			ThrowException(HtmlError::SPE_ROOT_CLOSE);
		break;
	case st_text:
		ThrowException(HtmlError::SPE_TEXT_AFTER_ROOT);
		break;
	default:
		break;
	}
}

bool HtmlParser::EnterOpenElement(std::stack<HtmlElement*>& stack, char c) {
	if (!IsFirstNameValid(c))
		ThrowException(HtmlError::SPE_ELEMENT_NAME);

	HtmlElement& element = std::get<HtmlElement>(
		stack.top()->children.emplace_back(HtmlElement{})
	);
	stack.push(&element);
	element.position = {GetLine(), GetColumn()};

	std::string accum;
	accum = c;

	enum TEState { st_name = 0, st_end_name, st_end_attr, st_single };
	TEState state = st_name;

	try {
		for (;;) {
			char c = GetChar();
			switch (state) {
			case st_name:
				switch (c) {
				case '>':
					element.tag = accum;
					return true;
				case '/':
					element.tag = accum;
					state = st_single;
					break;
				case ' ':
				case '\t':
				case '\n':
				case '\r':
					SkipWhiteSpace();
					element.tag = accum;
					state = st_end_name;
					break;
				default:
					if (!IsCharNameValid(c))
						ThrowException(HtmlError::SPE_ELEMENT_NAME);
					else
						accum += c;
				}
				break;
			case st_end_name:
				if (c == '/') {
					state = st_single;
				}
				else {
					HtmlString name, value;
					EnterAttribute(name, value, c);
					for (auto const& [n, _] : element.attributes) {
						if (n == name)
							ThrowException(HtmlError::SPE_DUBLICATE_ATTRIBUTE);
					}
					element.attributes.emplace(name, value);
					SkipWhiteSpace();
					state = st_end_attr;
				}
				break;
			case st_end_attr:
				switch (c) {
				case '/':
					state = st_single;
					break;
				case '>':
					return true;
				default:
					HtmlString name, value;
					EnterAttribute(name, value, c);
					for (auto const& [n, _] : element.attributes) {
						if (n == name)
							ThrowException(HtmlError::SPE_DUBLICATE_ATTRIBUTE);
					}
					element.attributes.emplace(name, value);
					SkipWhiteSpace();
					state = st_end_attr;
				}
				break;
			case st_single:
				switch (c) {
				case ' ':
				case '\t':
				case '\n':
				case '\r':
					ThrowException(HtmlError::SPE_WHITESPASE_CLOSE);
					break;
				case '>':
					stack.pop();
					return false;
				default:
					ThrowException(HtmlError::SPE_MISSING_CLOSING);
					break;
				}
				break;
			}
		}
	}
	catch (HtmlParserException& e) {
		RethrowException(e, HtmlError::SPE_EOF, HtmlError::SPE_MISSING_CLOSING);
		return false;
	}
}

void HtmlParser::EnterClosingElement(std::stack<HtmlElement*>& stack) {
	if (stack.empty())
		ThrowException(HtmlError::SPE_MATCH);
	typedef enum { st_begin, st_name, st_end } TEState;
	std::string accum;
	TEState state = st_begin;
	std::string inner_xml_data;
	try {
		while (true) {
			char c = GetChar();
			switch (state) {
			case st_begin:
				if (IsSpace(c))
					ThrowException(HtmlError::SPE_WHITESPASE_CLOSE);
				if (!IsFirstNameValid(c))
					ThrowException(HtmlError::SPE_ELEMENT_NAME);
				accum += c;
				state = st_name;
				break;
			case st_name:
				switch (c) {
				case '>':
					if (stack.top()->tag != accum)
						ThrowException(HtmlError::SPE_MATCH);
					stack.pop();
					return;
				case ' ':
				case '\t':
				case '\n':
				case '\r':
					SkipWhiteSpace();
					state = st_end;
					break;
				default:
					if (!IsCharNameValid(c))
						ThrowException(HtmlError::SPE_ELEMENT_NAME);
					accum += c;
				}
				break;
			case st_end:
				if (c != '>')
					ThrowException(HtmlError::SPE_MISSING_CLOSING);
				if (stack.top()->tag != accum)
					ThrowException(HtmlError::SPE_MATCH);
				stack.pop();
				return;
			}
		}
	}
	catch (HtmlParserException& e) {
		RethrowException(e, HtmlError::SPE_EOF, HtmlError::SPE_MISSING_CLOSING);
	}
}

void HtmlParser::EnterComment() {
	if (GetChar() != '-')
		ThrowException(HtmlError::SPE_COMMENT);
	try {
		std::string accum;
		typedef enum { st_enter, st_check_end, st_finish } TEState;
		TEState state = st_enter;

		while (true) {
			char c = GetChar();
			switch (state) {
			case st_enter:
				if (c == '-')
					state = st_check_end;
				else
					accum += c;
				break;
			case st_check_end:
				if (c == '-') {
					state = st_finish;
				}
				else {
					accum += '-'; accum += c;
					state = st_enter;
				}
				break;
			case st_finish:
				if (c != '>')
					ThrowException(HtmlError::SPE_MISSING_CLOSING);
				// Comment: accum
				return;
			}
		}
	}
	catch (HtmlParserException& e) {
		RethrowException(e, HtmlError::SPE_EOF, HtmlError::SPE_COMMENT_CLOSE);
	}
}

void HtmlParser::EnterEntity(void* value) {
	std::string& ret = *(std::string*)value;
	ret.erase();
	std::string accum;
	typedef enum { st_enter, st_analys, st_dec, st_hex, st_text } TEState;
	TEState state = st_enter;
	char c;

	try {
		while ((c = GetChar()) != ';') {
			switch (state) {
			case st_enter:
				if (c == '#')
					state = st_analys;
				else {
					accum += c;
					state = st_text;
				}
				break;
			case st_analys:
				if (c == 'x')
					state = st_hex;
				else {
					if (!IsDigit(c))
						ThrowException(HtmlError::SPE_REF_SYMBOL);
					else {
						accum += c;
						state = st_dec;
					}
				}
				break;
			case st_dec:
				if (!IsDigit(c))
					ThrowException(HtmlError::SPE_REF_SYMBOL);
				else
					accum += c;
				break;
			case st_hex:
				if (!IsHexDigit(c))
					ThrowException(HtmlError::SPE_REF_SYMBOL);
				else
					accum += c;
				break;
			case st_text:
				accum += c;
				break;
			}
		}

		unsigned long ucs = 0;
		unsigned int mult = 1;
		int i;

		switch (state) {
		case st_hex:
			for (i = (int)accum.size() - 1; i >= 0; i--) {
				char q = accum[i];
				if (q >= '0' && q <= '9')
					ucs += mult * (q - '0');
				else if (q >= 'a' && q <= 'f')
					ucs += mult * (q - 'a' + 10);
				else if (q >= 'A' && q <= 'F')
					ucs += mult * (q - 'A' + 10);
				mult *= 16;
			}
			ret = (char)ucs;
			break;
		case st_dec:
			for (i = (int)accum.size() - 1; i >= 0; i--) {
				char q = accum[i];
				ucs += mult * (q - '0');
				mult *= 10;
			}
			ret = (char)ucs;
			break;
		case st_text: {
			auto iter = g_ListEntity.find(accum);
			if (iter == g_ListEntity.end()) {
				ThrowException(HtmlError::SPE_UNKNOWN_ENTITY);
			}
			ret = iter->second;
		}
		default:
			break;
		}
	}
	catch (HtmlParserException& e) {
		RethrowException(e, HtmlError::SPE_EOF, HtmlError::SPE_MISSING_SEMI);
	}
}

void HtmlParser::EnterAttribute(HtmlString& name, HtmlString& value, char c) {
	if (!IsFirstNameValid(c))
		ThrowException(HtmlError::SPE_ATTR_NAME);
	name = c;
	typedef enum { st_name, st_end_name, st_begin_value, st_value } TEState;
	TEState state = st_name;
	char open = 0;
	std::string temp;

	try {
		while (true) {
			c = GetChar();

			switch (state) {
			case st_name:
				switch (c) {
				case '=':
					SkipWhiteSpace();
					state = st_begin_value;
					break;
				case ' ':
				case '\t':
				case '\n':
				case '\r':
					SkipWhiteSpace();
					state = st_end_name;
					break;
				default:
					if (!IsCharNameValid(c))
						ThrowException(HtmlError::SPE_ATTR_NAME);
					name += c;
				}
				break;
			case st_end_name:
				if (c != '=')
					ThrowException(HtmlError::SPE_ATTR_DESCR);
				SkipWhiteSpace();
				state = st_begin_value;
				break;
			case st_begin_value:
				if (c == '\'' || c == '"') {
					state = st_value;
					open = c;
				}
				else
					ThrowException(HtmlError::SPE_ATTR_DESCR);
				break;
			case st_value:
				if (c == open)
					return;
// 				switch (c) {
// 				case '&':
// 					EnterEntity(&temp);
// 					attribute->m_value += temp;
// 					break;
// 				default:
				value += c;
				break;
//				}
			}
		}
	}
	catch (HtmlParserException& e) {
		HtmlError code = e.GetCode();
		if (e.GetCode() == HtmlError::SPE_EOF) {
			switch (state) {
			case st_value:
				code = HtmlError::SPE_MISSING_QUOTE;
				break;
			default:
				code = HtmlError::SPE_ATTR_DESCR;
				break;
			}
		}
		RethrowException(e, HtmlError::SPE_EOF, code);
	}
}

void HtmlParser::SkipWhiteSpace() {
	while (!IsEOF()) {
		char c = GetChar();
		if (!IsSpace(c)) {
			UndoChar();
			return;
		}
	}
}

bool HtmlParser::IsEOF() {
	return m_pos >= m_buf.size();
}

void HtmlParser::UndoChar() {
	assert(m_pos > 0);
	m_pos--;
}

char HtmlParser::GetChar() {
	if (IsEOF()) {
		ThrowException(HtmlError::SPE_EOF);
	}
	char c = m_buf[m_pos++];
	if (c == '\n') {
		m_line++;
		m_column = 0;
	}
	else {
		m_column++;
	}
	return c;
}

unsigned int HtmlParser::GetLine() const {
	return m_line + 1;
}

unsigned int HtmlParser::GetColumn() const {
	if (m_column == 0)
		return 1;
	else
		return m_column;
}

void HtmlParser::ThrowException(HtmlError code) {
	throw HtmlParserException(code, GetLine(), GetColumn());
}

void HtmlParser::RethrowException(HtmlParserException& e, HtmlError nCheckCode, HtmlError nSubstituteCode) {
	if (e.GetCode() == nCheckCode)
		e.m_code = nSubstituteCode;
	throw e;
}

bool ParseHtml(const std::string_view& path, const std::string_view& data, bool inner, HtmlElement& html) {
	try {
		HtmlParser parser;
		parser.Parse(data, inner, html);
		return true;
	}
	catch (HtmlParserException& e) {
		if (path.empty()) {
			Log::Message(Log::Level::Error, "Parse error: %s Line: %d Column: %d", e.what(), e.GetLine(), e.GetColumn());
		}
		else {
			Log::Message(Log::Level::Error, "%s Parse error: %s Line: %d Column: %d", path.data(), e.what(), e.GetLine(), e.GetColumn());
		}
		return false;
	}
}

}
