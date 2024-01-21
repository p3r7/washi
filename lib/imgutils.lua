
local imgutils = {}


-- -------------------------------------------------------------------------
-- deps

include("lib/kaitai/bmp")
include("lib/kaitai/png")


-- -------------------------------------------------------------------------
-- file parsing

function imgutils.parse_bmp(filepath)
  local w = Bmp:from_file(filepath)
  -- return w.bitmap
  return w._raw_bitmap
end

function imgutils.parse_png(filepath)
  local w = Png:from_file(filepath)
  return w.chunks[2].body
end


-- -------------------------------------------------------------------------

return imgutils
