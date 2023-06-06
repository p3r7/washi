-- haleseq. out


-- ------------------------------------------------------------------------

local Out = {}
Out.__index = Out


-- ------------------------------------------------------------------------
-- constructors

function Out.new(id, parent,
                x, y)
  local p = setmetatable({}, Out)

  p.kind = "out"
  p.id = id

  if parent ~= nil then
    p.parent = parent
    if parent.outs ~= nil then
      table.insert(parent.outs, p.id)
    end
  end

  p.x = x
  p.y = y

  p.v = 0

  p.last_updated_t = 0
  p.last_changed_t = 0

  return p
end


-- ------------------------------------------------------------------------
-- accessors

function Out:reset()
  self.v = 0
end

function Out:update(v)
  local now = os.clock()
  local old_v = self.v

  self.last_updated_t = now

  self.v = v

  self.changed = (old_v ~= self.v)
  if self.changed then
    self.last_changed_t = now
  end
end


-- ------------------------------------------------------------------------

return Out
