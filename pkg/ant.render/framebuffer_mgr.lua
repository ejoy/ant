local mgr = {}

local bgfx = require "bgfx"

local FRAMEBUFFERS = {}
local RENDER_BUFFERS = {}

local VIEWID_BINDINGS = {}

local VALID_DEPTH_FMT<const> = {
	D24S8 = true, D24 = true, D24X8 = true, D32F = true, D16F = true
}

function mgr.bind(viewid, fb_idx)
	if not fb_idx then return end
	VIEWID_BINDINGS[viewid] = fb_idx
	local fb = mgr.get(fb_idx)
	bgfx.set_view_frame_buffer(viewid, assert(fb.handle))
end

function mgr.unbind(viewid)
	VIEWID_BINDINGS[viewid] = nil
end

function mgr.get_byviewid(viewid)
	local fb_idx = VIEWID_BINDINGS[viewid]
	return FRAMEBUFFERS[fb_idx]
end

function mgr.get_fb_idx(viewid)
	return VIEWID_BINDINGS[viewid]
end

function mgr.get(fb_idx)
	return FRAMEBUFFERS[fb_idx]
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

local function create_fb(attachments)
	for i=1, #attachments do
		local att = attachments[i]
		att.handle = mgr.get_rb(att.rbidx).handle
	end
	return bgfx.create_frame_buffer(attachments)
end

function mgr.create(...)
	local function check_render_buffers(attachments)
		if #attachments == 0 then
			error("need at least 1 render buffer to create framebuffer")
		end
		local depth_idx
		for idx, attachment in ipairs(attachments) do
			local rb = mgr.get_rb(attachment.rbidx)
			if VALID_DEPTH_FMT[rb.format] then
				if depth_idx == nil then
					depth_idx = idx
				else
					error "too many depth attachment"
				end
			end
		end

		if depth_idx ~= nil and depth_idx ~= #attachments then
			error(("depth buffer should put on the last render buffer:%d"):format(depth_idx))
		end
	end
	local attachments = {...}
	check_render_buffers(attachments)
	attachments.handle = create_fb(attachments)

	local fb_idx = generate_fb_idx()
	FRAMEBUFFERS[fb_idx] = attachments
	return fb_idx
end


local function find_rb_have_multi_ref(rbidx)
	local found = 0
	for fbidx, fb in pairs(FRAMEBUFFERS) do
		for i=1, #fb do
			if fb[i].rbidx == rbidx then
				found = found + 1
				if found > 1 then
					return true
				end
			end
		end
	end
end

local function destroy_rb(rbidx, mark_rbidx)
	--if not find_rb_have_multi_ref(rbidx) then
		local rb = mgr.get_rb(rbidx)
		if rb then
			bgfx.destroy(rb.handle)
		end
		if mark_rbidx then
			RENDER_BUFFERS[rbidx] = nil
		end
	--end
end

mgr.destroy_rb = destroy_rb

function mgr.destroy(fbidx, keep_rbs)
	if nil == fbidx then
		return
	end
	local oldfb = FRAMEBUFFERS[fbidx]
	if not keep_rbs then
		for i=1, #oldfb do
			destroy_rb(oldfb[i].rbidx, true)
		end
	end
	bgfx.destroy(oldfb.handle)
	FRAMEBUFFERS[fbidx] = nil
end

function mgr.recreate(fbidx, attachments)
	local oldfb = FRAMEBUFFERS[fbidx]
	--we assume that only framebuffer handle need recreate, render buffer should handle before call it
	bgfx.destroy(oldfb.handle)
	attachments.handle = create_fb(attachments)
	FRAMEBUFFERS[fbidx] = attachments
end

function mgr.copy(fbidx)
	local template_fb = mgr.get(fbidx)
	local fb = {}
    for _, rbidx in ipairs(template_fb) do
        local rb = mgr.get_rb(rbidx)
        fb[#fb+1] = mgr.create_rb(rb)
	end
	
	fb.manager_buffer = template_fb.manager_buffer

    return mgr.create(fb)
end

local generate_rb_idx = unique_idx_generator()

local function create_rb_handle(rb)
	if rb.w == 0 or rb.h == 0 then
		error(string.format("render buffer width or height should not be 0:%d, %d", rb.w, rb.h))
	end

	local mipmap = rb.mipmap or false
	local layers = rb.layers or 1
	local fmt, flags = assert(rb.format), assert(rb.flags)
	if rb.cubemap then
		return bgfx.create_texturecube(rb.size, mipmap, layers, fmt, flags)
	end
	return bgfx.create_texture2d(rb.w, rb.h, mipmap, layers, fmt, flags)
end

function mgr.create_rb(rb)
	local myrb = copy_arg(rb)
	myrb.handle = create_rb_handle(rb)
	local idx = generate_rb_idx()
	RENDER_BUFFERS[idx] = myrb
	return idx
end

function mgr.get_rb(fbidx, rbidx)
	rbidx = rbidx and mgr.get(fbidx)[rbidx].rbidx or fbidx
	return RENDER_BUFFERS[rbidx]
end

function mgr.resize_rb(rbidx, w, h)
	local rb = mgr.get_rb(rbidx)

	local changed = true
	if rb.cubemap and rb.size ~= w then
		rb.size = w
	elseif rb.w ~= w or rb.h ~= h then
		rb.w, rb.h = w, h
	else
		changed = false
	end

	if changed then
		destroy_rb(rbidx)
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

function mgr.get_depth(fbidx)
	local fb = mgr.get(fbidx)
	local rb = mgr.get_rb(fb[#fb].rbidx)
	assert(VALID_DEPTH_FMT[rb.format])
	return rb
end

function mgr.clear()
	for _, rb in pairs(RENDER_BUFFERS) do
		if not rb.unmark then
			bgfx.destroy(rb.handle)
		end
	end
	RENDER_BUFFERS = {}

	for _, fb in pairs(FRAMEBUFFERS) do
		bgfx.destroy(fb.handle)
	end

	FRAMEBUFFERS = {}

	for viewid in pairs(VIEWID_BINDINGS) do
		log.info(("viewid:%d binded framebuffer already remove, need clear"):format(viewid))
	end
end

return mgr