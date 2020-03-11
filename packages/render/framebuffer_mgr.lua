local mgr = {}; mgr.__index = mgr

local bgfx = require "bgfx"

local framebuffers = {}
local renderbuffers = {}

local viewid_bindings = {}

function mgr.bind(viewid, fb_idx)
	viewid_bindings[viewid] = fb_idx
	local fb = mgr.get(fb_idx)
	bgfx.set_view_frame_buffer(viewid, assert(fb.handle))
end

function mgr.unbind(viewid)
	viewid_bindings[viewid] = nil
end

function mgr.get_byviewid(viewid)
	local fb_idx = viewid_bindings[viewid]
	return framebuffers[fb_idx]
end

function mgr.get_fb_idx(viewid)
	return viewid_bindings[viewid]
end

function mgr.get(fb_idx)
	return framebuffers[fb_idx]
end

function mgr.use(fb_idx)
	local fb = mgr.get(fb_idx)
	fb.using = true
	return fb
end

function mgr.not_use(fb_idx)
	local fb = mgr.get(fb_idx)
	fb.using = nil
	return fb
end

local function unique_idx_generator()
	local seed_idx = 0
	return function ()
		seed_idx = seed_idx + 1
		return seed_idx
	end
end

local generate_fb_idx = unique_idx_generator()

local function copy_arg(arg)
	local t = {}
	for k, v in pairs(arg) do
		t[k] = v
	end
	return t
end

local function create_fb_handle(rbs, manager_buffer)
	local myfb = {
		manager_buffer = manager_buffer,
	}
	local rbhandles = {}
	for idx, rbidx in ipairs(rbs) do
		myfb[idx] = rbidx
		rbhandles[#rbhandles+1] = renderbuffers[rbidx].handle
	end
	
	assert(#rbhandles > 0)
	myfb.handle = bgfx.create_frame_buffer(rbhandles, manager_buffer)
	return myfb
end

function mgr.create(fb)
	local myfb
	if fb.wndhandle then
		myfb = copy_arg(fb)
		myfb.handle = bgfx.create_frame_buffer(fb.wndhandle.handle, fb.w, fb.h, fb.color_format, fb.depth_format)
	else
		myfb = create_fb_handle(fb.render_buffers, fb.manager_buffer)
	end

	local fb_idx = generate_fb_idx()
	framebuffers[fb_idx] = myfb
	return fb_idx
end

function mgr.recreate(fbidx, fb)
	assert(fb.wndhandle == nil)
	framebuffers[fbidx] = create_fb_handle(fb.render_buffers, fb.manager_buffer)
end

function mgr.copy(fbidx)
	local template_fb = mgr.get(fbidx)
	local rbs = {}
    for _, rbidx in ipairs(template_fb) do
        local rb = mgr.get_rb(rbidx)
        rbs[#rbs+1] = mgr.create_rb(rb)
    end

    return mgr.create {
        render_buffers = rbs,
        manager_buffer = template_fb.manager_buffer,
    }
end

function mgr.is_wnd_frame_buffer(fb_idx)
	return framebuffers[fb_idx].wndhandle ~= nil
end

local generate_rb_idx = unique_idx_generator()

local function create_rb_handle(rb)
	if rb.w == 0 or rb.h == 0 then
		error(string.format("render buffer width or height should not be 0:%d, %d", rb.w, rb.h))
	end
	return bgfx.create_texture2d(rb.w, rb.h, false, rb.layers, rb.format, rb.flags)
end

function mgr.create_rb(rb)
	local myrb = copy_arg(rb)
	myrb.handle = create_rb_handle(rb)
	local idx = generate_rb_idx()
	renderbuffers[idx] = myrb
	return idx
end

function mgr.get_rb(rb_idx)
	return renderbuffers[rb_idx]
end

function mgr.resize_rb(w, h, rbidx)
	local rb = mgr.get_rb(rbidx)
	if rb.w ~= w or rb.h ~= h then
		rb.w, rb.h = w, h
		rb.handle = create_rb_handle(rb)
		return true
	end
end

local nativehandles = {}
function mgr.bind_native_handle(name, handle)
	assert(type(handle) == "userdata",type(handle))
	if nativehandles[name] then
		error(string.format("%s have been binded!", name))
	end

	nativehandles[name] = handle
end

function mgr.unbind_native_handle(name)
	nativehandles[name] = nil
end

function mgr.get_native_handle(name)
	return nativehandles[name]
end

function mgr.unbind_all_native_handle()
	for k in pairs(nativehandles) do
		nativehandles[k] = nil
	end
end

return mgr