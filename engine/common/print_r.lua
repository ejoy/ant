local print = print
local tconcat = table.concat
local tinsert = table.insert
local srep = string.rep
local type = type
local pairs = pairs
local tostring = tostring

local function print_r( root )
    local cache = {[ root ] = "." }
    local function _dump( t, space, name )
        local temp = { }
        for k, v in pairs( t ) do
            local key = tostring( k )
            if cache[ v ] then
                tinsert( temp, "+" .. key .. " {" .. cache[ v ] .. "}" )
            elseif type( v ) == "table" then
                local new_key = name .. "." .. key
                cache[ v ] = new_key
                local next = pairs( t )
                tinsert( temp, "+" .. key .. _dump( v, space .. ( next( t, k ) and "|" or " " ) .. srep( " ", #key ), new_key ))
            else
                tinsert( temp, "+" .. key .. " [" .. tostring( v ) .. "]" )
            end
        end
        return tconcat( temp, "\n"..space )
    end
    print( _dump( root, "", "" ))
end

local function dump_a(args,indent_str)
    local cache = { }
    local temp = { }
    local need_indent = indent_str
    local indent_str = indent_str or ""
    local function output( ... )
        local args = { ... }
        for k = 1, #args do
            tinsert( temp, args[ k ])
        end
    end
    local function _dump( value, path,is_key,indent )
        local my_indent = ""
        if  is_key then
            my_indent = indent 
        end
        local typev = type( value )
        if typev ~= "table" then
            if typev == "string" then
                output( my_indent,"\"", value, "\"" )
            else
                output( my_indent,tostring( value ))
            end
        else --table
            if cache[ value ] then
                output( "{", cache[ value ], "}" )
            else
                cache[ value ] = path
                output( my_indent,"{" )
                if need_indent then
                    output("\n")
                end
                local next_indent = indent..indent_str
                for k, v in pairs( value ) do
                    if not string.find(k,"raw") then
                        if type( k ) == "table" then
                            _dump( k, path..".&"..tostring( k ),true,next_indent)
                            output( "(", tostring( k ), ")" )
                        else
                            _dump( k,nil,true,next_indent ) --k is string or number
                        end
                        output( "=" )
                        _dump( v, path.."."..tostring( k ),false,next_indent)
                        output( next( value, k ) and "," or "" )
                        if need_indent then
                            output("\n")
                        end
                    end
                end
                output( indent,"}" )
                
            end
        end
    end
    
    if #args > 0 then
        output( _dump( args[ 1 ], "",false, "" ))
        for i = 2, #args do
            cache = { }
            if need_indent then
                output( "\n" )
            else
                output( "\t" )
            end
            _dump( args[ i ], "",false, "" )
        end
    end
    return tconcat( temp )
end

--print all args in_single_line
local function print_a( ... )
    local args = { ... }
    local str = dump_a(args)
    print( str)
end

return {
    print_r = print_r,
    dump_a = dump_a,
    print_a = print_a, 
}
