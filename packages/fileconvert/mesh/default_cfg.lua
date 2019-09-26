local config = {
    --[[
        layout element inlcude 6 char, like : n30nif
        first char is attribute type, includes:
            p   --> position
            n   --> normal (can generate by program)
            T   --> tangent (can generate by program)
            b   --> bitangent (can generate by program)
            t   --> texcoord
            c   --> color
            i   --> indices
            w   --> weight
        second char is element count, can be 1, 2 3 and 4
        third char is channel index, can be [0, 7], 0 is default number
        forth char is normalize flag, n for normalize data, N for NOT normalize data
        fifth char is as integer flag, i for as integer data, I for NOT interger data
        sixth char is element type, f for float, h for half float, u for uint8, U for uint10, i for int16
        examples :
            n30nif means :  normal with 3 element(x,y,z) at channel 0
                            normalize to [0, 1], as integer data, save as float type
            p3 means: position with 3 element(x,y,z) at channel 0, NOT normalize and NOT as int, using float type
            T means: tangent with 3 element(x,y,z) at channel 0, NOT normalize and NOT as int, using float type

        layout string can be used to create bgfx_vertex_layout_t
    ]]
    layout = {
        "p3|n30nIf|T|b|t20|c40",
    },
    flags = {
        invert_normal   = false,
        flip_uv         = true,
        ib_32           = false,    -- if index num is lower than 65535
    },
    animation = {
        load_skeleton   = true,
        ani_list        = "all",    -- or {"walk", "stand"}
        cpu_skinning    = false,
    },
}
return config