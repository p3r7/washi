-- washi. cv_out

local CvOut = {}
local CvOut_mt = { __index = CvOut }


-- ------------------------------------------------------------------------
-- deps

local Out = include("washi/lib/submodule/out")
setmetatable(CvOut, {__index = Out})


-- ------------------------------------------------------------------------

function CvOut.new(id, parent,
                   x, y)
  local p = Out.new(id, parent, x, y)
  setmetatable(p, CvOut_mt)
  p.kind = "cv_out"
  return p
end


-- ------------------------------------------------------------------------

return CvOut
