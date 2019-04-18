--print all args in_single_line
local function print_a( ... )
    local print = print
    local tconcat = table.concat
    local tinsert = table.insert
    local srep = string.rep
    local type = type
    local pairs = pairs
    local tostring = tostring
    local cache = { }
    local temp = { }
    local function output( ... )
        local args = { ... }
        for k = 1, #args do
            tinsert( temp, args[ k ])
        end
    end
    local function _dump( value, path )
        local typev = type( value )
        if typev ~= "table" then
            if typev == "string" then
                output( "\"", value, "\"" )
            else
                output( tostring( value ))
            end
        else --table
            if cache[ value ] then
                output( "{", cache[ value ], "}" )
            else
                cache[ value ] = path
                output( "{" )
                for k, v in pairs( value ) do
                    if not string.find(k,"raw") then

                        output( "" )
                        if type( k ) == "table" then
                            _dump( k, path..".&"..tostring( k ))
                            output( "(", tostring( k ), ")" )
                        else
                            _dump( k ) --k is string or number
                        end
                        output( "=" )
                        _dump( v, path.."."..tostring( k ))
                        output( next( value, k ) and "," or "" )
                    end
                end
                output( "}" )
                
            end
        end
    end
    local args = { ... }
    if #args > 0 then
        output( _dump( args[ 1 ], "" ))
        for i = 2, #args do
            cache = { }
            output( "\t" )
            _dump( args[ i ], "" )
        end
    end
    print( tconcat( temp ))
end


local function line_ident(line)
    local space = string.byte(" ")
    for i = 1,string.len(line) do
        local char = string.byte(line,i)
        if char ~= space then
            return i - 1
        end
    end
end

local ref_head = "--- &"
local ref_head_len = string.len(ref_head)
local function convert(file_path)
    local file = io.open(file_path,"r")
    local index = 0
    local ref_table = {}
    local cur_hex_id = nil
    for line in file:lines() do
        index = index + 1
        if string.sub(line,1,3) == "---" then
            cur_hex_id = nil
        end
        if cur_hex_id then
            assert(ref_table[cur_hex_id])
            table.insert(ref_table[cur_hex_id],line)
        end
        if string.sub(line,1,ref_head_len) == ref_head then
            local hex_id = string.sub(line,ref_head_len+1)
            ref_table[hex_id] = {}
            cur_hex_id = hex_id
        end
    end
    file:close()
    print_a(ref_table)
    file = io.open(file_path,"r")
    local index = 0
    local output = {}

    local function output_line(line,ident_prefix)
        local ident = line_ident(line)
        if ident then
            local line_content = string.sub(line,ident+1)
            local hex_id = string.match(line_content,"--- %*([%w%d]+)")
            if hex_id then
                table.insert(output,string.rep(" ",(ident+ident_prefix)*2))
                table.insert(output,"---\n")
                for i,sub_line in ipairs(ref_table[hex_id]) do
                    output_line(sub_line,ident+ident_prefix)
                end
            else
                local key_name = nil
                key_name,hex_id = string.match(line_content,"([%w%d_]+):%*([%w%d]+)")
                if hex_id then
                    table.insert(output,string.rep(" ",(ident+ident_prefix)*2))
                    table.insert(output,key_name..":\n")
                    for i,sub_line in ipairs(ref_table[hex_id]) do
                        output_line(sub_line,ident+ident_prefix+2)
                    end
                end
                
            end
            if not hex_id then
                table.insert(output,string.rep(" ",(ident+ident_prefix)*2))
                table.insert(output,line_content.."\n")
            end
        end
    end

    for line in file:lines() do
        index = index +1
        output_line(line,0)
    end
    file:close()
    local content = table.concat(output,"")
    local ofile = io.open("convert_"..file_path,"w+")
    ofile:write(content)
    ofile:close()
end

local function main()
    convert(arg[1])
end

main()