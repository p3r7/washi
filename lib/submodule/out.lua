-- haleseq. out


-- ------------------------------------------------------------------------

local Out = {}
Out.__index = Out


-- ------------------------------------------------------------------------
-- constructors

function Out.new(id, parent)
  local p = setmetatable({}, Out)
  p.id = id
  if parent ~= nil then
    p.parent = parent
    if parent.outs ~= nil then
      table.insert(parent.outs, p.id)
    end
  end
  p.v = 0
  return p
end


-- ------------------------------------------------------------------------
-- accessors

function Out:reset()
  self.v = 0
end


-- ------------------------------------------------------------------------

return Out
