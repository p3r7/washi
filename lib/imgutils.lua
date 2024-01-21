
local imgutils = {}


-- -------------------------------------------------------------------------
-- deps

include("lib/kaitai/bmp")
include("lib/kaitai/png")


-- -------------------------------------------------------------------------
-- byte ops

function imgutils.char_to_int(c)
  return string.byte(c, 1)
end

function imgutils.str_to_bitmap(str)
  local out = {}
  for i = 1, #str do
    local c = str:sub(i,i)
    out[i] = imgutils.char_to_int(c)
  end
  return out
end

function imgutils.bitmap_to_str(bitmap)
  local out = ""
  for _, v in ipairs(bitmap) do
    out = out .. string.char(v)
  end
  return out
end

local function are_same_col(c1, c2)
  return (c1[1] == c2[1])
    and (c1[2] == c2[2])
    and (c1[3] == c2[3])
end

function imgutils.bitmap_map_cols(bitmap, col_map)
  for i=1, #bitmap, 3 do
    local col = {bitmap[i], bitmap[i+1], bitmap[i+2]}
    for from, to in pairs(col_map) do
      if are_same_col(col, from) then
        bitmap[i], bitmap[i+1], bitmap[i+2] = table.unpack(to)
        break
      end
    end
  end
end


-- -------------------------------------------------------------------------
-- file parsing

function imgutils.parse_bmp(filepath)
  local bmp = Bmp:from_file(filepath)

  -- local w, h = bmp.dib_info.image_width, bmp.dib_info.image_height_raw

  local offset_bitmap = bmp.file_hdr.ofs_bitmap
  local file = io.open(filepath, "rb")
  local raw_header = file:read(offset_bitmap)
  file:close()

  -- NB: we also have access to a `bmp.bitmap` sub-object but idk how to manipulate it...
  local bitmap = imgutils.str_to_bitmap(bmp._raw_bitmap)

  return raw_header, bitmap
end

function imgutils.parse_png(filepath)
  local w = Png:from_file(filepath)
  return w.chunks[2].body
end


-- -------------------------------------------------------------------------
-- file transformation

function imgutils.bmp_color_mapped(src_filepath, dst_filepath, col_map)
  local raw_header, bitmap = imgutils.parse_bmp(src_filepath)
  imgutils.bitmap_map_cols(bitmap, col_map)

  local raw_bitmap = imgutils.bitmap_to_str(bitmap)

  local file_content = raw_header .. raw_bitmap

  dst_file = assert(io.open(dst_filepath, "wb"))
  dst_file:write(file_content)
  dst_file:close()
end

-- -------------------------------------------------------------------------

return imgutils
