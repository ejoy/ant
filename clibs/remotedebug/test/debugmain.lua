local rdebug = require "remotedebug"
assert(rdebug.status == "debugger")
local aux = require "debugaux"
local hook = require "debughook"

local function hookpoint(source, line)
	print("HOOKPOINT ->", aux.frame(1))
end

hook.probe("@test.lua",6, hookpoint)

local tmp={}
rdebug.sethook(function(event, line)
	if hook.hook(event,line) then
		return
	end
	if event == "abc" then
		local f = aux.frame(1)
		print(f)
		print("a=>",f.a)
		local meta = rdebug.getmetatable(f.a.__ref)
		print("meta =>", rdebug.value(meta))
		rdebug.assign(meta, nil)
		print("meta =>", rdebug.value(meta))
		local fa = rdebug.copytable(f.a.__ref)
		for k,v in pairs(fa) do
			print("a =>", k,v)
		end
		print("a.b=>",f.a.b)
		print("a.none=>", rdebug.value(f.a.none))
		print("a.b.c=>",f.a.b.c)
		print("a.b.c.d=>",f.a.b.c.d, rdebug.type(f.a.b.c.d))
		print("foo2=>", rdebug.value(f.foo2), rdebug.type(f.foo2))
		print("c=>", f.c)
		print("d=>", f.d)
		print("d[c]=>", f.d[f.c])
		print("_ENV.print=>", rdebug.value(f._ENV.print), rdebug.type(f._ENV.print))
		local print_info = rdebug.getinfo(f._ENV.print)
		for k,v in pairs(print_info) do
			print("_ENV.print:",k,v)
		end
		assert(rdebug.type(f.co) == "thread")
		rdebug.switch(f.co)	-- switch to co
		print(aux.frame(1))	-- co's frame 1
		rdebug.switch()	-- switch back to current thread
		rdebug.hookmask "cr"
	elseif event == "ABC" then
		print(rdebug.getinfo(1).source, line)
	end
end)
