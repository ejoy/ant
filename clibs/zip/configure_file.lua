local input, output = ...

local vars = {
    ZLIB_SYMBOL_PREFIX = ""
}

local outf <close> = assert(io.open(output, "wb"))
for line in io.lines(input) do
    line = line:gsub("@([%w_]+)@", vars)
    outf:write(line, "\n")
end
