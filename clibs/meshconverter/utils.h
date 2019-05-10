#include <string>
#include <vector>

#include <cassert>

#include <bgfx/bgfx.h>

std::vector<std::string>
split_string(const std::string &ss, char delim);

std::string&
refine_layout(std::string &elem);

std::vector<std::string>
split_layout_elems(const std::string &layout);

std::string
refine_layouts(std::string &layout);

size_t
CalcVertexSize(const std::string &layout);

bgfx::VertexDecl	
GenVertexDeclFromVBLayout(const std::string &vblayout);

std::string
GenVBLayoutFromDecl(const bgfx::VertexDecl &decl);

std::string
GenStreamNameFromDecl(const bgfx::VertexDecl &decl);

std::string
GenStreamNameFromElem(const std::string &elem);

bgfx::Attrib::Enum
GetAttribFromLayoutElem(const std::string &elem);

size_t 
GetVertexElemSizeInBytes(const std::string &elem);

std::string
GetDefaultVertexLayoutElem();