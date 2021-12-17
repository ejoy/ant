#pragma once

#include <string>
#include <stack>

class HtmlHandler {
public:
    virtual void OnDocumentBegin() {}
    virtual void OnDocumentEnd() {}
    virtual void OnElementBegin(const char* szName) {}
    virtual void OnElementClose() {}
    virtual void OnElementEnd(const  char* szName, const std::string& inner_xml_data = {}) {}
    virtual void OnCloseSingleElement(const  char* szName) {}
    virtual void OnAttribute(const char* szName, const char* szValue) {}
    virtual void OnTextBegin() {}
    virtual void OnTextEnd(const char* szValue) {}
    virtual void OnComment(const char* szText) {}
    virtual void OnScriptBegin(unsigned int line) {}
    virtual void OnScriptEnd(const char* szValue) {}
    virtual void OnStyleBegin(unsigned int line) {}
    virtual void OnStyleEnd(const char* szValue) {}
    virtual void OnInnerXML(bool inner) {}
    virtual bool IsEmbed() { return false; }
};

enum class HtmlError {
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

class HtmlParser {
public:
    void Parse(std::string_view stream, HtmlHandler* handler);

private:
    std::stack<std::string> m_stack_items;
    unsigned int m_line   = 0;
    unsigned int m_column = 0;
    HtmlHandler* m_handler = nullptr;
    std::string_view m_buf;
    size_t           m_pos;
    bool             m_inner_xml_data = false;
    size_t           m_inner_xml_data_begin;
    std::string      m_inner_xml_tag;
    void UndoChar();
    char GetChar();
    void SkipWhiteSpace();
    bool IsEOF();
    unsigned int GetColumn() const;
    unsigned int GetLine() const;
    void ThrowException(HtmlError code);
    void RethrowException(HtmlParserException& e, HtmlError nCheckCode, HtmlError nSubstituteCode);

    void EnterOpenElement(char c);
    void EnterClosingElement();
    void EnterComment();
    void EnterEntity(void* pData);
    void EnterAttribute(void* pAttr, char c);
};
