
-- ------------------------------------------------------------------------

local Panel = {}
Panel.__index = Panel


-- ------------------------------------------------------------------------
-- constructors

function Panel.new(id, STATE, x, y, modules)
  local p = setmetatable({}, Haleseq)

  p.id = id
  p.STATE = STATE

  p.x = x
  p.y = y

  modules = modules or {}
  p.modules = modules

  return p
end


-- ------------------------------------------------------------------------

return Panel
