-- washi. module/quantized clock

local QuantizedClock = {}
QuantizedClock.__index = QuantizedClock


-- ------------------------------------------------------------------------
-- deps

local Comparator = include("washi/lib/submodule/comparator")
local Out = include("washi/lib/submodule/out")

local paperface = include("washi/lib/paperface")
include("washi/lib/consts")
include("washi/lib/core")


-- ------------------------------------------------------------------------
-- constructors

function QuantizedClock.new(id, STATE,
                            mclock_div, divs, base,
                            page_id, x, y)
  local p = setmetatable({}, QuantizedClock)

  p.kind = "quantized_clock"

  p.id = id -- id for param lookup
  p.fqid = p.kind.."_"..id -- fully qualified id for i/o routing lookup

  -- --------------------------------

  p.STATE = STATE

  -- --------------------------------
  -- screen

  p.page = page_id
  p.x = x
  p.y = y

  -- --------------------------------
  -- i/o

  p.ins = {}
  p.outs = {}

  p.i = Comparator.new(p.fqid, p, nil)

  p.divs = divs
  p.div_states = {}
  p.div_outs = {}
  for i, div in ipairs(divs) do
    p.div_outs[i] = Out.new(p.fqid.."_"..div, p, x+1, y)
    p.div_states[i] = false
    y = y + 1
  end

  if base == nil then base = 0 end
  p.base = base

  p.acum = 0

  p.mclock_div = mclock_div
  p.mclock_mult_trig = false

  return p
end

function QuantizedClock.init(id, STATE, mclock_div, divs,
                             page_id, x, y)
  local q = QuantizedClock.new(id, STATE, mclock_div, divs, nil,
                               page_id, x, y)

  if STATE ~= nil then
    STATE.ins[q.i.id] = q.i
    for _, o in ipairs(q.div_outs) do
      STATE.outs[o.id] = o
    end
  end

  return q
end


-- ------------------------------------------------------------------------
-- internal logic

function QuantizedClock:process_ins()
  if self.i.triggered then
    if self.i.status == 1 then
      self:tick()
    else
      -- NB: end of input trigger
      -- we only really need to do it for highest precision divider (1/64) iif it has the same resolution as the global latice superclock
      for _, o in ipairs(self.div_outs) do
        o.v = 0
      end
    end
  end
end

function QuantizedClock:mod(v, m)
  if self.base == 1 then
    return mod1(v, m)
  else -- base == 0
    return v % m
  end
end

function QuantizedClock:tick()
  self.acum = self.acum + 1
  for i, d in ipairs(self.divs) do
    local m = self.mclock_div / d
    local state = (self:mod(self.acum, m) == 0)
    self.div_states[i] = state
    if state then
      self.div_outs[i]:update(V_MAX / 2)
    else
      self.div_outs[i]:update(0)
    end
  end
end


-- ------------------------------------------------------------------------
-- grid

function QuantizedClock:grid_redraw(g)
  -- dummy input
  for i, v in ipairs(self.divs) do
    if v == (self.mclock_div / 8) then
      local l = 3
      if self.mclock_mult_trig then
        l = 10
      end
      local x = paperface.panel_to_grid_x(g, self.x)
      local y = paperface.panel_to_grid_y(g, self.y)

      g:led(x, y, l)
    end
  end

  paperface.module_grid_redraw(self, g)
end


-- ------------------------------------------------------------------------
-- screen

function QuantizedClock:redraw()
  paperface.module_redraw(self)

  for i, v in ipairs(self.divs) do

    local o = self.div_outs[i]

    local x = paperface.panel_grid_to_screen_x(o.x)
    local y = paperface.panel_grid_to_screen_y(o.y)

    -- local trig = ( (math.abs(os.clock() - o.last_changed_t) < NANA_TRIG_DRAW_T))
    -- paperface.trig_out(x, y, trig)


    screen.move(x + SCREEN_STAGE_W + 2, y + SCREEN_STAGE_W - 2)
    screen.text(v)

    -- NB: dummy input linked to norns clock
    -- quantized clock is implemented as a standard pulse divider
    -- but it presents itself as a pulse multiplier
    if v == (self.mclock_div / 8) then
      self.mclock_mult_trig = trig
      local tame = (self.STATE.grid_mode ~= M_SCOPE)
      paperface.trig_in(paperface.panel_grid_to_screen_x(self.x), paperface.panel_grid_to_screen_y(self.y), trig, false, tame)
    end

  end
end


-- ------------------------------------------------------------------------
return QuantizedClock
