local crc_table = {}
local POLY <const> = 0xEDB88320

for i = 0, 255 do
    local crc = i
    for _ = 1, 8 do
        local b = crc & 1
        crc = crc >> 1
        if b == 1 then crc = crc ~ POLY end
    end
    crc_table[i] = crc
end

return function (s, crc)
  crc = ~(crc or 0) & 0xffffffff
  for i = 1, #s - 15, 16 do
      local s0, s1, s2, s3, s4, s5, s6, s7
          , s8, s9, sa, sb, sc, sd, se, sf = ('BBBBBBBBBBBBBBBB'):unpack(s, i)
      crc = crc_table[(crc & 0xFF) ~ s0] ~ (crc >> 8)
      crc = crc_table[(crc & 0xFF) ~ s1] ~ (crc >> 8)
      crc = crc_table[(crc & 0xFF) ~ s2] ~ (crc >> 8)
      crc = crc_table[(crc & 0xFF) ~ s3] ~ (crc >> 8)
      crc = crc_table[(crc & 0xFF) ~ s4] ~ (crc >> 8)
      crc = crc_table[(crc & 0xFF) ~ s5] ~ (crc >> 8)
      crc = crc_table[(crc & 0xFF) ~ s6] ~ (crc >> 8)
      crc = crc_table[(crc & 0xFF) ~ s7] ~ (crc >> 8)
      crc = crc_table[(crc & 0xFF) ~ s8] ~ (crc >> 8)
      crc = crc_table[(crc & 0xFF) ~ s9] ~ (crc >> 8)
      crc = crc_table[(crc & 0xFF) ~ sa] ~ (crc >> 8)
      crc = crc_table[(crc & 0xFF) ~ sb] ~ (crc >> 8)
      crc = crc_table[(crc & 0xFF) ~ sc] ~ (crc >> 8)
      crc = crc_table[(crc & 0xFF) ~ sd] ~ (crc >> 8)
      crc = crc_table[(crc & 0xFF) ~ se] ~ (crc >> 8)
      crc = crc_table[(crc & 0xFF) ~ sf] ~ (crc >> 8)
  end
  for i = #s - (#s % 16) + 1, #s do
      crc = crc_table[(crc & 0xFF) ~ s:byte(i)] ~ (crc >> 8)
  end
  return ~crc & 0xffffffff
end
