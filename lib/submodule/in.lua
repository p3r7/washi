-- washi. in


-- ------------------------------------------------------------------------
-- deps

local patching = include("washi/lib/patching")

include("washi/lib/consts")


-- ------------------------------------------------------------------------

local In = {}
In.__index = In


-- ------------------------------------------------------------------------
-- constructors

function In.new(id, parent, callback,
               x, y)
  local p = setmetatable({}, In)

  p.kind = "in"
  p.id = id

  if parent ~= nil then
    p.parent = parent
    if parent.ins ~= nil then
      table.insert(parent.ins, p.id)
    end
    if parent.STATE ~= nil then
      parent.STATE.ins[p.id] = p
    end
  end

  -- REVIEW: not using those anymore
  if callback then
    p.callback = callback
  end

  p.x = x
  p.y = y
  if parent.page ~= nil and x ~= nil and y ~= nil then
    local coords = parent.page .. "." .. x .. "." .. y
    parent.STATE.coords_to_nana[coords] = p
  end

  p.compute_mode = V_COMPUTE_MODE_SUM

  p.incoming_vals = {}
  p.v = 0
  p.changed = false

  p.last_updated_t = 0
  p.last_changed_t = 0

  return p
end


-- ------------------------------------------------------------------------
-- api

function In:register(out_label, v)
  self.incoming_vals[out_label] = v
end

function In:update()
  local now = self.parent.STATE.superclk_t
  local old_v = self.v

  self.last_updated_t = now

  -- if tab.count(self.incoming_vals) == 0 and self.v == 0 then
  if tab.count(self.incoming_vals) == 0 then
    self.changed = false
    return
  end

  self.v = patching.input_compute_val(self.compute_mode, self.incoming_vals)

  self.changed = (old_v ~= self.v)
  if self.changed then
    self.last_changed_t = now
    self.parent.STATE.screen_dirty = true
  end

  if self.callback then
    -- self.callback()
  end
end

-- ------------------------------------------------------------------------

return In
