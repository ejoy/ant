return function (output, namespace, userheader, components)
    local out = {}
    local function writefile(filename)
        local f <close> = assert(io.open(filename, "w"))
        f:write(table.concat(out, "\n"))
        out = {}
    end
    local function write(line)
        out[#out+1] = line
    end
    write "#pragma once"
    write ""
    write "#include \"ecs/select.h\""
    write(("#include \"%s\""):format(userheader))
    write "#include <cstdint>"
    write "#include <tuple>"
    write ""
    write(("namespace %s {"):format(namespace))
    write ""
    write "using eid = uint64_t;"
    write ""
    write "struct REMOVED {};"
    write ""
    for _, info in ipairs(components) do
        local name, type = info[1], info[2]
        if type == "c" then
            local fields = info[3]
            write(("struct %s {"):format(name))
            for _, field in ipairs(fields) do
                write(("\t%s %s;"):format(field[1], field[2]))
            end
            write("};")
            write ""
        elseif type == "raw" then
            local size = info[3]
            write(("struct %s { uint8_t raw[%d]; }"):format(name, size))
            write ""
        elseif type == "tag" then
            write(("struct %s {};"):format(name))
            write ""
        elseif type == "lua" then
            write(("struct %s { unsigned int lua_object; };"):format(name))
            write ""
        elseif type == "int" then
            local field = info[2]
            write(("using %s = %s;"):format(name, field))
            write ""
        end
    end
    write "using _all_ = ::std::tuple<"
    for i = 1, #components-1 do
        local c = components[i]
        write(("\t%s,"):format(c[1]))
    end
    write(("\t%s"):format(components[#components][1]))
    write ">;"
    write ""
    write "}"
    write ""
    write(("namespace component = %s;"):format(namespace))
    write ""
    write "template <>"
    write "constexpr inline auto ecs::component_id<component::eid> = ecs::COMPONENT::EID;"
    write "template <>"
    write "constexpr inline auto ecs::component_id<component::REMOVED> = ecs::COMPONENT::REMOVED;"
    write "template <typename T>"
    write "    requires (ecs::helper::component_has_v<T, component::_all_>)"
    write "constexpr inline auto ecs::component_id<T> = ecs::helper::component_id_v<T, component::_all_>;"
    write ""
    writefile(output)
end
