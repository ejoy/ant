
local function openfile(filename)
	local co = coroutine.create(
		function()
			for line in io.lines(filename) do
				coroutine.yield(line)
			end
		end)
	return function ()
		return coroutine.resume(co)
	end
end


local n = openfile("d:/tmp/abc.txt")


repeat
	local success, v = n()
	if success then
		print(v)	
	end	
until not success or v == nil






-- local co = coroutine.create(
-- function ()
-- 	for _, v in ipairs { "haha", "111"} do 
-- 		print(v)
-- 		coroutine.yield()
-- 	end

-- 	print("13333")
-- end)

-- coroutine.resume(co)
-- coroutine.resume(co)
-- coroutine.resume(co)

-- print(coroutine.status(co))

-- coroutine.resume(co)

-- print("end")

-- local testup = 100
-- local function test_testup()
-- 	print(testup)
-- end

-- test_testup()

-- testup = 200
-- test_testup()