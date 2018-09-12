#include <string>
#include <vector>

#include <cassert>

#include "bgfx/bgfx.h"

#if defined(DISABLE_ASSERTS)
# define verify(expr) ((void)(expr))
#else
# define verify(expr) assert(expr)
#endif	

std::vector<std::string>
Split(const std::string &ss, char delim);

std::vector<std::string>
AdjustLayoutElem(const std::string &layout);

size_t
CalcVertexSize(const std::string &layout);

bgfx::VertexDecl	
GenVertexDeclFromVBLayout(const std::string &vblayout);

std::string
GenVBLayoutFromDecl(const bgfx::VertexDecl &decl);