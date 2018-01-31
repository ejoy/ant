#include <ib-compress/indexbufferdecompression.h>
#include <ib-compress/readbitstream.h>
#include <bgfx/bgfx.h>
#include <stdint.h>

extern "C" uint16_t
create_compressed_ib(uint32_t num, uint32_t csize, const void * src) {
	const bgfx::Memory* mem = bgfx::alloc(num*2);
	ReadBitstream rbs((const uint8_t*)src, csize);
	DecompressIndexBuffer((uint16_t*)mem->data, num / 3, rbs);
	bgfx::IndexBufferHandle ibh = bgfx::createIndexBuffer(mem);
	
	return ibh.idx;
}
