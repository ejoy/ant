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

--print all args in_single_line
local function print_a( ... )
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
                    output( "[" )
                    if type( k ) == "table" then
                        _dump( k, path..".&"..tostring( k ))
                        output( "(", tostring( k ), ")" )
                    else
                        _dump( k ) --k is string or number
                    end
                    output( "]=" )
                    _dump( v, path.."."..tostring( k ))
                    output( next( value, k ) and "," or "" )
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

return {print_r = print_r,
        print_a = print_a }
