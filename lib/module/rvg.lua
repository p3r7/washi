-- washi. module/random voltage generator
--
-- Serge RVG

local Rvg = {}
Rvg.__index = Rvg


-- ------------------------------------------------------------------------
-- deps

local ControlSpec = require "controlspec"
local Formatters = require "formatters"

local Comparator = include("washi/lib/submodule/comparator")
local In = include("washi/lib/submodule/in")
local Out = include("washi/lib/submodule/out")
local CvOut = include("washi/lib/submodule/cv_out")

local patching = include("washi/lib/patching")
local paperface = include("washi/lib/paperface")

include("washi/lib/consts")


-- ------------------------------------------------------------------------
-- static conf

local specs = {}
specs.LFO_FREQ = ControlSpec.new(LFO_MIN_RATE, LFO_MAX_RATE, "exp", 0, LFO_DEFAULT_RATE, "Hz")


-- ------------------------------------------------------------------------
-- constructors

function Rvg.new(id, STATE,
                 page_id, x, y)
  local p = setmetatable({}, Rvg)

  p.kind = "rvg"
  p.id = id
  p.fqid = p.kind .. "_" .. id

  -- --------------------------------

  p.STATE = STATE
  STATE.modules[p.fqid] = p

  -- --------------------------------
  -- screen

  p.page = page_id
  p.x = x
  p.y = y

  -- --------------------------------
  -- i/o

  p.ins = {}
  p.outs = {}

  p.i_rate = In.new(p.fqid.."_rate", p, nil, x, y+6)
  p.i_trig = Comparator.new(p.fqid.."_trig", p, nil, x+1, y+6)
  p.i_trig_dummy = Comparator.new(p.fqid.."_trig_dummy", p) -- for self-trigging wo/ display

  p.o_smooth = CvOut.new(p.fqid.."_smooth", p, x, y)
  p.o_stepped = Out.new(p.fqid.."_stepped", p, x, y+1)
  p.o_pulse = Out.new(p.fqid.."_pulse", p, x, y+2) -- NB: labelled 'timing' on old units

  -- --------------------------------

  p.accum = 0
  p.clock = clock.run(function()
      p:clock()
  end)

  return p
end

function Rvg:init_params()
  local id = self.id
  local fqid = self.fqid

  params:add_group(fqid, "RVG #"..id, 1)

  params:add{type = "control", id = fqid.."_rate", name = "Freq", controlspec = specs.LFO_FREQ, formatter = Formatters.format_freq}

end

function Rvg.init(id, STATE, page_id, x, y)
  local q = Rvg.new(id, STATE,
                    page_id, x, y)
  q:init_params()
  return q
end

function Rvg:cleanup()
  clock.cancel(self.clock)
end


-- ------------------------------------------------------------------------
-- internal logic

function Rvg:clock()
  local step_s = 1 / LFO_COMPUTATIONS_PER_S

  while true do
    clock.sleep(step_s)

    -- internal clock
    local speed = params:get(self.fqid.."_rate")
    local step = (speed / step_s) / 600
    self.accum = self.accum + step

    local trig = false
    while self.accum > 1 do
      trig = true
      self.accum = self.accum - 1
    end

    -- smooth
    if self.o_smooth.v ~= self.o_stepped.v then
      local v = util.linlin(0, 100, self.o_smooth.v, self.o_stepped.v, round(self.accum * 100))
      self.o_smooth:update(v)
    end

    -- REVIEW: might be better to have a single clock for all RVGs & LFOs doing that?
    -- even maybe an event queue, dropping events that are too old
    if trig then
      patching.fire_and_propagate(self.STATE.outs, self.STATE.ins, self.STATE.links, self.STATE.link_props,
                                  self.i_trig_dummy.id, V_MAX/2)
      -- TODO: unto after TRIG_S!
      patching.fire_and_propagate(self.STATE.outs, self.STATE.ins, self.STATE.links, self.STATE.link_props,
                                  self.i_trig_dummy.id, 0)
    end

    if self.o_smooth.changed then
      patching.fire_and_propagate_from_out(self.STATE.outs, self.STATE.ins, self.STATE.links, self.STATE.link_props,
                                           self.o_smooth.id, self.o_smooth.v)
    end

  end
end

function Rvg:process_ins()
  if self.i_rate.changed then
    params:set(self.fqid.."_rate", round(util.linlin(0, V_MAX, LFO_MIN_RATE, LFO_MAX_RATE, self.i_rate.v)))
  end

  local triggered = (self.i_trig.triggered and self.i_trig.status == 1)
  local self_triggered = (self.i_trig_dummy.triggered and self.i_trig_dummy.status == 1)

  if triggered or self_triggered then
    local v = math.random(V_MAX+1)-1

    self.o_stepped:update(v)

    if self.o_pulse.v == 0 then
      self.o_pulse:update(V_MAX/2)
    else
      self.o_pulse:update(0)
    end
  end
end


-- ------------------------------------------------------------------------
-- grid

function Rvg:grid_redraw(g)
  paperface.module_grid_redraw(self, g)
end


-- ------------------------------------------------------------------------
-- screen

function Rvg:redraw()
  paperface.module_redraw_labels(self)
  paperface.module_redraw_bananas(self)
end

-- ------------------------------------------------------------------------

return Rvg
