#pragma once

#include <map>
#include <string>
#include <stack>
#include <vector>
#include <variant>
#include <string_view>
#include <tuple>
#include <cstdint>

namespace Rml {

enum class HtmlError : uint8_t {
    SPE_OK = 0,
    SPE_EMPTY,
    SPE_INVALID_FORMAT,
    SPE_INVALID_INSTANCE,
    SPE_MISSING_CLOSING,
    SPE_ELEMENT_NAME,
    SPE_MATCH,
    SPE_COMMENT,
    SPE_REF_SYMBOL,
    SPE_ATTR_NAME,
    SPE_ATTR_DESCR,
    SPE_UNKNOWN_ENTITY,
    SPE_ROOT_CLOSE,
    SPE_EOF,
    SPE_MISSING_SEMI,
    SPE_MISSING_QUOTE,
    SPE_TEXT_BEFORE_ROOT,
    SPE_TEXT_AFTER_ROOT,
    SPE_WHITESPASE_OPEN,
    SPE_WHITESPASE_CLOSE,
    SPE_WHITESPACE_PROCESS,
    SPE_COMMENT_CLOSE,
    SPE_ENTITY_DOC_OPEN,
    SPE_DUBLICATE_ATTRIBUTE,
    SPE_INPUT_DATA_ERROR,
};

class HtmlParserException : public std::exception {
public:
    const char* what() const noexcept override;
    HtmlError GetCode() const { return m_code; }
    unsigned int GetLine() const { return m_line; }
    unsigned int GetColumn() const { return m_column; }
private:
    friend class HtmlParser;
    HtmlParserException(HtmlError code, unsigned int line, unsigned int column)
        : m_code(code)
        , m_line(line)
        , m_column(column)
    { }
    HtmlError m_code;
    unsigned int m_line;
    unsigned int m_column;
};

using HtmlString = std::string;
using HtmlAttributes = std::map<HtmlString, HtmlString>;
using HtmlPosition = std::tuple<unsigned int, unsigned int>;

struct HtmlElement;
using HtmlNode = std::variant<HtmlElement, HtmlString>;

struct HtmlElement {
    HtmlString            tag;
    HtmlPosition          position;
    HtmlAttributes        attributes;
    std::vector<HtmlNode> children;
};

class HtmlParser {
public:
    void Parse(std::string_view stream, bool inner, HtmlElement& root);

private:
    unsigned int m_line   = 0;
    unsigned int m_column = 0;
    std::string_view m_buf;
    size_t           m_pos;
    void UndoChar();
    char GetChar();
    void SkipWhiteSpace();
    bool IsEOF();
    unsigned int GetColumn() const;
    unsigned int GetLine() const;
    void ThrowException(HtmlError code);
    void RethrowException(HtmlParserException& e, HtmlError nCheckCode, HtmlError nSubstituteCode);

    bool EnterOpenElement(std::stack<HtmlElement*>& stack, char c);
    void EnterClosingElement(std::stack<HtmlElement*>& stack);
    void EnterComment();
    void EnterEntity(void* pData);
    void EnterAttribute(HtmlString& name, HtmlString& value, char c);
};

bool ParseHtml(const std::string_view& path, const std::string_view& data, bool inner, HtmlElement& html);

}
