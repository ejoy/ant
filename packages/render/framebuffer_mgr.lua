local mgr = {}; mgr.__index = mgr

local bgfx = require "bgfx"

local framebuffers = {}
local renderbuffers = {}

local viewid_bindings = {}

function mgr.bind(viewid, fb_idx)
	if not fb_idx then return end
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
		local i
		for idx, attachment in ipairs(attachments) do
			local rb = mgr.get_rb(attachment.rbidx)
			if rb.format[1] == "D" then
				i = idx
				break
			end
		end

		if i ~= nil and i ~= #attachments then
			error(("depth buffer should put on the last render buffer:%d"):format(i))
		end
	end
	local attachments = {...}
	check_render_buffers(attachments)
	attachments.handle = create_fb(attachments)

	local fb_idx = generate_fb_idx()
	framebuffers[fb_idx] = attachments
	return fb_idx
end


local function find_rb_have_multi_ref(rbidx)
	local found = 0
	for fbidx, fb in pairs(framebuffers) do
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
	if not find_rb_have_multi_ref(rbidx) then
		local rb = mgr.get_rb(rbidx)
		bgfx.destroy(rb.handle)
		if mark_rbidx then
			renderbuffers[rbidx] = nil
		end
	end
end

mgr.destroy_rb = destroy_rb

function mgr.destroy(fbidx, keep_rbs)
	local oldfb = framebuffers[fbidx]
	if not keep_rbs then
		for i=1, #oldfb do
			destroy_rb(oldfb[i].rbidx, true)
		end
	end
	bgfx.destroy(oldfb.handle)
	framebuffers[fbidx] = nil
end

function mgr.recreate(fbidx, attachments)
	local oldfb = framebuffers[fbidx]
	--we assume that only framebuffer handle need recreate, render buffer should handle before call it
	bgfx.destroy(oldfb.handle)
	attachments.handle = create_fb(attachments)
	framebuffers[fbidx] = attachments
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

	if rb.cubemap then
		return bgfx.create_texturecube(rb.size, rb.mipmap, rb.layers, rb.format, rb.flags)
	end
	return bgfx.create_texture2d(rb.w, rb.h, rb.mipmap, rb.layers, rb.format, rb.flags)
end

function mgr.create_rb(rb)
	local myrb = copy_arg(rb)
	myrb.handle = create_rb_handle(rb)
	local idx = generate_rb_idx()
	renderbuffers[idx] = myrb
	return idx
end

function mgr.get_rb(fbidx, rbidx)
	rbidx = rbidx and mgr.get(fbidx)[rbidx].rbidx or fbidx
	return renderbuffers[rbidx]
end

function mgr.resize_rb(rbidx, w, h)
	local rb = mgr.get_rb(rbidx)

	local changed = true
	if rb.cubemap and rb.size ~= w then
		rb.size = w
	elseif rb.w ~= w or rb.h ~= h then
		rb.w, rb.h = w, h
	else
		changed = nil
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

return mgr