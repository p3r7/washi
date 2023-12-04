-- washi. comparator
--
-- a `Comparator` can work:
-- - as a regular `In` (w/ `self.raw_v`)
-- - as a comparator/gate generator (w/ `self.v`)
-- - as flip flops (w/ `self.triggered`)


-- ------------------------------------------------------------------------
-- deps

local patching = include("washi/lib/patching")

include("washi/lib/consts")


-- ------------------------------------------------------------------------

local Comparator = {}
Comparator.__index = Comparator


-- ------------------------------------------------------------------------
-- constructors

function Comparator.new(id, parent, callback,
                       x, y)
  local p = setmetatable({}, Comparator)

  p.kind = "comparator"
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
  p.threshold_mode = V_THRESHOLD_MODE_OWN
  p.threshold = V_DEFAULT_THRESHOLD

  p.incoming_vals = {}
  p.raw_v = 0
  p.v = 0
  p.changed = false
  p.status = 0
  p.triggered = false

  p.last_triggered_t = 0
  p.last_up_t = 0
  p.last_down_t = 0

  return p
end


-- ------------------------------------------------------------------------
-- getter/setter

function Comparator:register(out_label, v)
  self.incoming_vals[out_label] = v
end

function Comparator:update()
  local prev_status = self.status
  local now = self.parent.STATE.superclk_t

  -- if self.id == "haleseq_1_clock" then
  --   dbgf('----------------')
  --   dbgf(self.incoming_vals)
  -- end

  -- if tab.count(self.incoming_vals) == 0 and self.v == 0 then
  if tab.count(self.incoming_vals) == 0 then
    self.changed = false
    return
  end

  local old_raw_v = self.raw_v
  self.raw_v = patching.input_compute_val(self.compute_mode, self.incoming_vals)

  -- self.changed = true
  self.changed = (old_v ~= self.v)

  if self.raw_v >= self.threshold then
    self.status = 1
    self.v = V_MAX / 2
  else
    self.status = 0
    self.v = 0
  end

  self.triggered = (prev_status ~= self.status)
  if self.triggered then
    self.last_triggered_t = now
    if self.status == 1 then
      self.last_up_t = now
    else
      self.last_down_t = now
    end
  end

  -- if self.id == "haleseq_1_clock" then
  --   dbgf('----------------')
  --   dbgf(self.triggered)
  -- end


  if self.triggered and self.callback then
    -- self.callback()
  end
end


-- ------------------------------------------------------------------------

return Comparator
