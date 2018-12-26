package.cpath = "../../clibs/?.dll"
package.path = "?.lua;../?.lua"
local plist = require "plist"
local print_r = require "common.print_r"

print(plist.toxml {
	["<a\0>"] = 1,
	b = 2.0,
	c = plist.array { true, false },
	d = plist.date(),
	e = "中文",
	f = plist.data "\0\1\2\3",
	g = plist.dict {
		x = 3.0,
		y = 4,
	}
})

local plist_files = {
"1.plist",
"2.plist",
"3.plist",
"4.plist",
"5.plist",
"6.plist",
"7.plist",
"amp.plist",
"cdata.plist",
"empty_keys.plist",
"entities.plist",
"hex.plist",
"invalid_tag.plist",
"offxml.plist",
"order.plist",
"signed.plist",
"signedunsigned.plist",
"unsigned.plist",
}

for idx, xml in ipairs(plist_files) do
	local f = assert(io.open ("testdata/" .. xml))
	local data = f:read "a"
	f:close()

	local ok, x = pcall(plist.fromxml,data)
	if ok then
		print("===>", xml)
		if type(x) == "table" then
			print_r(x)
		else
			print(x)
		end
	else
		print("ERROR", xml, x)
	end
end



