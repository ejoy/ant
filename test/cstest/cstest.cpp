/*
 * Copyright 2011-2020 Branimir Karadzic. All rights reserved.
 * License: https://github.com/bkaradzic/bgfx#license-bsd-2-clause
 */

#include <bx/uint32_t.h>
#include "common.h"
#include "bgfx_utils.h"

#include "bx/readerwriter.h"
#include "entry/dbg.h"
#include "imgui/imgui.h"

namespace
{
struct PosColorVertex
{
	float m_x;
	float m_y;
	float m_z;
	uint32_t m_abgr;

	static void init()
	{
		ms_layout
			.begin()
			.add(bgfx::Attrib::Position, 3, bgfx::AttribType::Float)
			.add(bgfx::Attrib::Color0,   4, bgfx::AttribType::Uint8, true)
			.end();
	};

	static bgfx::VertexLayout ms_layout;
};

bgfx::VertexLayout PosColorVertex::ms_layout;

static PosColorVertex s_plane[] =
{
	{-1.0f,  1.0f,  1.0f, 0xff000000 },
	{ 1.0f,  1.0f,  1.0f, 0xff0000ff },
	{-1.0f, -1.0f,  1.0f, 0xff00ff00 },
	{ 1.0f, -1.0f,  1.0f, 0xff00ffff },
};

static uint16_t s_indices[] = {0, 1, 2, 1, 2, 3};

	static const bgfx::Memory* loadMem(bx::FileReaderI* _reader, const char* _filePath)
	{
		if (bx::open(_reader, _filePath) )
		{
			uint32_t size = (uint32_t)bx::getSize(_reader);
			const bgfx::Memory* mem = bgfx::alloc(size+1);
			bx::read(_reader, mem->data, size);
			bx::close(_reader);
			mem->data[mem->size-1] = '\0';
			return mem;
		}

		DBG("Failed to load %s.", _filePath);
		return NULL;
	}

	static bgfx::ShaderHandle
	load_shader(bx::FileReaderI *_reader, const char* filePath){
		bgfx::ShaderHandle handle = bgfx::createShader(loadMem(_reader, filePath));
		bgfx::setName(handle, bx::FilePath(filePath).getBaseName().getPtr());
		return handle;
	}

	bgfx::ProgramHandle load_compute_program(bx::FileReaderI* _reader, const char* _csname)
	{
		bgfx::ShaderHandle csh = load_shader(_reader, _csname);
		return bgfx::createProgram(csh, false);
	}

	bgfx::ProgramHandle load_program(bx::FileReaderI *_reader, const char* _vsname, const char* _fsname){
		bgfx::ShaderHandle vsh = load_shader(_reader, _vsname);
		bgfx::ShaderHandle fsh = load_shader(_reader, _fsname);

		return bgfx::createProgram(vsh, fsh, false);
	}

class ExampleHelloWorld : public entry::AppI
{
public:
	ExampleHelloWorld(const char* _name, const char* _description, const char* _url)
		: entry::AppI(_name, _description, _url)
	{
	}

	void init(int32_t _argc, const char* const* _argv, uint32_t _width, uint32_t _height) override
	{
		Args args(_argc, _argv);

		m_width  = _width;
		m_height = _height;
		m_debug  = BGFX_DEBUG_TEXT;
		m_reset  = BGFX_RESET_VSYNC;

		bgfx::Init init;
		init.type     = args.m_type;
		init.vendorId = args.m_pciId;
		init.resolution.width  = m_width;
		init.resolution.height = m_height;
		init.resolution.reset  = m_reset;
		bgfx::init(init);

		PosColorVertex::init();

		// Enable debug text.
		bgfx::setDebug(m_debug);

		// Set view 0 clear state.
		bgfx::setViewClear(0
			, BGFX_CLEAR_COLOR|BGFX_CLEAR_DEPTH
			, 0x303030ff
			, 1.0f
			, 0
			);

		m_csProg = load_compute_program(entry::getFileReader(), "../00-helloworld/cs_test.bin");
		m_renderProg = load_program(entry::getFileReader(), "../00-helloworld/vs_plane.bin", "../00-helloworld/fs_plane.bin");
		m_texhandle = bgfx::createTexture2D(512, 512, false, 1, bgfx::TextureFormat::RGBA8, BGFX_TEXTURE_COMPUTE_WRITE);

		m_texUniform = bgfx::createUniform("s_tex", bgfx::UniformType::Sampler, 1);

		imguiCreate();
	}

	virtual int shutdown() override
	{
		imguiDestroy();

		// Shutdown bgfx.
		bgfx::shutdown();

		return 0;
	}

	bool update() override
	{
		if (!entry::processEvents(m_width, m_height, m_debug, m_reset, &m_mouseState) )
		{
			imguiBeginFrame(m_mouseState.m_mx
				,  m_mouseState.m_my
				, (m_mouseState.m_buttons[entry::MouseButton::Left  ] ? IMGUI_MBUT_LEFT   : 0)
				| (m_mouseState.m_buttons[entry::MouseButton::Right ] ? IMGUI_MBUT_RIGHT  : 0)
				| (m_mouseState.m_buttons[entry::MouseButton::Middle] ? IMGUI_MBUT_MIDDLE : 0)
				,  m_mouseState.m_mz
				, uint16_t(m_width)
				, uint16_t(m_height)
				);

			showExampleDialog(this);

			imguiEndFrame();

			// Set view 0 default viewport.
			bgfx::setViewRect(0, 0, 0, uint16_t(m_width), uint16_t(m_height) );

			// This dummy draw call is here to make sure that view 0 is cleared
			// if no other draw calls are submitted to view 0.
			bgfx::touch(0);

			const bx::Vec3 at  = { 0.0f, 0.0f,  0.0f };
			const bx::Vec3 eye = { 0.0f, 0.0f, -5.0f };

			float view[16];
			bx::mtxLookAt(view, eye, at);

			float proj[16];
			bx::mtxProj(proj, 60.0f, float(m_width)/float(m_height), 0.1f, 100.0f, bgfx::getCaps()->homogeneousDepth);

			// Set view and projection matrix for view 0.
			bgfx::setViewTransform(0, view, proj);

			bgfx::setImage(0, m_texhandle, 0, bgfx::Access::Write);
			bgfx::dispatch(0, m_csProg, 512/16, 512/16, 1);

			bgfx::TransientVertexBuffer tvb;
			bgfx::allocTransientVertexBuffer(&tvb, 4, PosColorVertex::ms_layout);
			memcpy(tvb.data, s_plane, sizeof(s_plane));

			bgfx::TransientIndexBuffer tib;
			bgfx::allocTransientIndexBuffer(&tib, 6, false);
			memcpy(tib.data, s_indices, sizeof(s_indices));

			bgfx::setTexture(0, m_texUniform, m_texhandle, 0);

			bgfx::setVertexBuffer(0, &tvb);
			bgfx::setIndexBuffer(&tib);

			bgfx::setState(0, 0);
			bgfx::submit(0, m_renderProg, 0, BGFX_DISCARD_ALL);

			// // Use debug font to print information about this example.
			// bgfx::dbgTextClear();
			// bgfx::dbgTextImage(
			// 	  bx::max<uint16_t>(uint16_t(m_width /2/8 ), 20)-20
			// 	, bx::max<uint16_t>(uint16_t(m_height/2/16),  6)-6
			// 	, 40
			// 	, 12
			// 	, s_logo
			// 	, 160
			// 	);
			// bgfx::dbgTextPrintf(0, 1, 0x0f, "Color can be changed with ANSI \x1b[9;me\x1b[10;ms\x1b[11;mc\x1b[12;ma\x1b[13;mp\x1b[14;me\x1b[0m code too.");

			// bgfx::dbgTextPrintf(80, 1, 0x0f, "\x1b[;0m    \x1b[;1m    \x1b[; 2m    \x1b[; 3m    \x1b[; 4m    \x1b[; 5m    \x1b[; 6m    \x1b[; 7m    \x1b[0m");
			// bgfx::dbgTextPrintf(80, 2, 0x0f, "\x1b[;8m    \x1b[;9m    \x1b[;10m    \x1b[;11m    \x1b[;12m    \x1b[;13m    \x1b[;14m    \x1b[;15m    \x1b[0m");

			// const bgfx::Stats* stats = bgfx::getStats();
			// bgfx::dbgTextPrintf(0, 2, 0x0f, "Backbuffer %dW x %dH in pixels, debug text %dW x %dH in characters."
			// 	, stats->width
			// 	, stats->height
			// 	, stats->textWidth
			// 	, stats->textHeight
			// 	);

			// Advance to next frame. Rendering thread will be kicked to
			// process submitted rendering primitives.
			bgfx::frame();

			return true;
		}

		return false;
	}

	entry::MouseState m_mouseState;

	uint32_t m_width;
	uint32_t m_height;
	uint32_t m_debug;
	uint32_t m_reset;
	bgfx::ProgramHandle m_csProg;
	bgfx::ProgramHandle m_renderProg;
	bgfx::TextureHandle m_texhandle;
	bgfx::UniformHandle m_texUniform;
};

} // namespace

ENTRY_IMPLEMENT_MAIN(
	  ExampleHelloWorld
	, "00-helloworld"
	, "Initialization and debug text."
	, "https://bkaradzic.github.io/bgfx/examples.html#helloworld"
	);
