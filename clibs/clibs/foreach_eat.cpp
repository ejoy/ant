#include "foreach_eat.h"
#include "memory_file.h"
#include "array_view.h"
#include <Windows.h>

class pe_reader {
public:
	pe_reader(const void* d)
		: data((const char*)d)
	{ }
	bool isOK() const {
		return data;
	}
	PIMAGE_DOS_HEADER get_dos_header() const {
		return (PIMAGE_DOS_HEADER)data;
	}
	PIMAGE_FILE_HEADER get_file_header() const {
		return (PIMAGE_FILE_HEADER)(data + get_dos_header()->e_lfanew + 4);
	}
	const char* get_opt_header() const {
		return (data + get_dos_header()->e_lfanew + 4 + sizeof(IMAGE_FILE_HEADER));
	}
	const char* directory(DWORD directory) const {
		const char* h = get_opt_header();
		if (PIMAGE_OPTIONAL_HEADER32(h)->Magic == IMAGE_NT_OPTIONAL_HDR64_MAGIC) {
			return rva_to_addr(PIMAGE_OPTIONAL_HEADER64(h)->DataDirectory[directory].VirtualAddress);
		}
		else {
			return rva_to_addr(PIMAGE_OPTIONAL_HEADER32(h)->DataDirectory[directory].VirtualAddress);
		}
	}
	const char* rva_to_addr(DWORD rva) const {
		std::array_view<IMAGE_SECTION_HEADER> sections(
			PIMAGE_SECTION_HEADER(
				data
				+ get_dos_header()->e_lfanew 
				+ FIELD_OFFSET(IMAGE_NT_HEADERS, OptionalHeader) 
				+ get_file_header()->SizeOfOptionalHeader
			)
			, get_file_header()->NumberOfSections
		);
		for (auto const& s : sections) {
			if (s.VirtualAddress <= rva && s.VirtualAddress + s.Misc.VirtualSize >= rva) {
				return data + s.PointerToRawData + (rva - s.VirtualAddress);
			}
		}
		return data + rva;
	}

private:
	const char* data;
};

void foreach_eat(const wchar_t* dll, std::function<void(const std::string&)> fn) {
	memory_file file(dll);
	pe_reader r(file.data());
	if (!r.isOK()) {
		return;
	}
	PIMAGE_EXPORT_DIRECTORY eat = (PIMAGE_EXPORT_DIRECTORY)r.directory(IMAGE_DIRECTORY_ENTRY_EXPORT);
	DWORD* names_address = (DWORD*)(r.rva_to_addr(eat->AddressOfNames));
	for (DWORD i = 0; i < eat->NumberOfNames; ++i) {
		fn(r.rva_to_addr(names_address[i]));
	}
}
