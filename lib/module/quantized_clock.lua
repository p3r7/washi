-- haleseq. module/quantized clock

local QuantizedClock = {}
QuantizedClock.__index = QuantizedClock


-- ------------------------------------------------------------------------
-- deps

local Comparator = include("haleseq/lib/submodule/comparator")
local Out = include("haleseq/lib/submodule/out")

local paperface = include("haleseq/lib/paperface")
include("haleseq/lib/consts")
include("haleseq/lib/core")


-- ------------------------------------------------------------------------
-- constructors

function QuantizedClock.new(id, STATE,
                            mclock_div, divs, base,
                            screen_id, x, y)
  local p = setmetatable({}, QuantizedClock)

  p.kind = "quantized_clock"

  p.id = id -- id for param lookup
  p.fqid = p.kind.."_"..id -- fully qualified id for i/o routing lookup

  -- --------------------------------

  p.STATE = STATE

  -- --------------------------------
  -- screen

  p.screen = screen_id
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
    p.div_outs[i] = Out.new(p.fqid.."_"..div, p, x, y)
    p.div_states[i] = false
    y = y + SCREEN_STAGE_W
  end

  if base == nil then base = 0 end
  p.base = base

  p.acum = 0

  p.mclock_div = mclock_div

  return p
end

function QuantizedClock.init(id, STATE, mclock_div, divs,
                             screen_id, x, y)
  local q = QuantizedClock.new(id, STATE, mclock_div, divs, nil,
                               screen_id, x, y)

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
-- screen

function QuantizedClock:redraw(x, y, acum)
  for i, v in ipairs(self.divs) do

    local o = self.div_outs[i]

    -- local trig = acum % (MCLOCK_DIVS / CLOCK_DIV_DENOMS[i]) == 0

    local trig = ( (math.abs(os.clock() - o.last_changed_t) < NANA_TRIG_DRAW_T))
    paperface.trig_out(o.x, o.y, trig)
    screen.move(o.x + SCREEN_STAGE_W + 2, o.y + SCREEN_STAGE_W - 2)
    screen.text(v)
    -- y = y + SCREEN_STAGE_W
  end
end


-- ------------------------------------------------------------------------
return QuantizedClock
