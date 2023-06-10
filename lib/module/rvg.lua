-- washi. module/random voltage source
--
-- Serge RVG

local Rvg = {}
Rvg.__index = Rvg


-- ------------------------------------------------------------------------
-- deps

local Comparator = include("washi/lib/submodule/comparator")
local In = include("washi/lib/submodule/in")
local Out = include("washi/lib/submodule/out")

local patching = include("washi/lib/patching")
local paperface = include("washi/lib/paperface")

include("washi/lib/consts")


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

  -- --------------------------------
  -- screen

  p.screen = page_id
  p.x = x
  p.y = y

  -- --------------------------------
  -- i/o

  p.ins = {}
  p.outs = {}

  p.i_rate = In.new(p.fqid.."_rate", p, nil, x, y+4)
  p.i_trig = Comparator.new(p.fqid.."_trig", p, nil, x+1, y+4)

  p.o_smooth = Out.new(p.fqid.."_smooth", p, x, y)
  p.o_stepped = Out.new(p.fqid.."_stepped", p, x, y+1)
  p.o_pulse = Out.new(p.fqid.."_pulse", p, x, y+2) -- NB: labelled 'timing' on old units

  -- --------------------------------

  p.accum = 0
  p.clock = clock.run(function()
      p:clock()
  end)

  return p
end

function Rvg.init(id, STATE, page_id, x, y)
  local q = Rvg.new(id, STATE, divs,
                             page_id, x, y)

  -- q:init_params()

  if STATE ~= nil then
    STATE.ins[q.i_rate.id] = q.i_rate
    STATE.ins[q.i_trig.id] = q.i_trig
    STATE.outs[q.o_smooth.id] = q.o_smooth
    STATE.outs[q.o_stepped.id] = q.o_stepped
    STATE.outs[q.o_pulse.id] = q.o_pulse
  end

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
    local speed = util.linlin(0, V_MAX, LFO_MIN_RATE, LFO_MAX_RATE, self.i_rate.v)
    local step = speed / LFO_COMPUTATIONS_PER_S
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

    if trig then
      patching.fire_and_propagate(self.STATE.outs, self.STATE.ins, self.STATE.links, self.i_trig.id, V_MAX/2)
      patching.fire_and_propagate(self.STATE.outs, self.STATE.ins, self.STATE.links, self.i_trig.id, 0)
    end

  end
end

function Rvg:process_ins()
  if self.i_trig.triggered and self.i_trig.status == 1 then
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
-- screen

function Rvg:redraw()
  local trig = (math.abs(os.clock() - self.i_trig.last_up_t) < NANA_TRIG_DRAW_T)
  paperface.trig_in(paperface.grid_to_screen_x(self.i_trig.x), paperface.grid_to_screen_y(self.i_trig.y), trig)

  trig = (math.abs(os.clock() - self.i_rate.last_changed_t) < NANA_TRIG_DRAW_T)
  paperface.main_in(paperface.grid_to_screen_x(self.i_rate.x), paperface.grid_to_screen_y(self.i_rate.y), trig)

  trig = ( (math.abs(os.clock() - self.o_smooth.last_changed_t) < NANA_TRIG_DRAW_T))
  paperface.trig_out(paperface.grid_to_screen_x(self.o_smooth.x), paperface.grid_to_screen_y(self.o_smooth.y), trig)
  trig = ( (math.abs(os.clock() - self.o_stepped.last_changed_t) < NANA_TRIG_DRAW_T))
  paperface.trig_out(paperface.grid_to_screen_x(self.o_stepped.x), paperface.grid_to_screen_y(self.o_stepped.y), trig)
  trig = ( (math.abs(os.clock() - self.o_pulse.last_changed_t) < NANA_TRIG_DRAW_T))
  paperface.trig_out(paperface.grid_to_screen_x(self.o_pulse.x), paperface.grid_to_screen_y(self.o_pulse.y), trig)

end

-- ------------------------------------------------------------------------

return Rvg
