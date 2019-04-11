local mgr = {}; mgr.__index = mgr

local fb_mapper = {__mode="v"}
function mgr.bind(viewid, fb)
	fb_mapper[viewid] = fb
end

function mgr.unbind(viewid)
	fb_mapper[viewid] = nil
end

function mgr.get(viewid)
	return fb_mapper[viewid]
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