-- washi. module/lfo bank
--
-- Lfo Bank

local LfoBank = {}
LfoBank.__index = LfoBank


-- ------------------------------------------------------------------------
-- deps

local ControlSpec = require "controlspec"
local Formatters = require "formatters"

local Comparator = include("washi/lib/submodule/comparator")
local In = include("washi/lib/submodule/in")
local Out = include("washi/lib/submodule/out")

local patching = include("washi/lib/patching")
local paperface = include("washi/lib/paperface")

include("washi/lib/consts")
include("washi/lib/core")


-- ------------------------------------------------------------------------
-- impl - wave shape

local t_reso = 10000 -- nb sambles / cycle

local specs = {}
specs.WAVE_SHAPE = ControlSpec.UNIPOLAR
specs.LFO_FREQ = ControlSpec.new(LFO_MIN_RATE, LFO_MAX_RATE, "exp", 0, LFO_DEFAULT_RATE, "Hz")

local function gen_wave_lut(cycles, length)
  local wave_table = {{},{},{},{}}
  for sx = 1, length do
    local x = util.linlin(1, length, 0, cycles, sx)
    local square = math.abs(x * 2 % 2 - 1) - 0.5
    square = square > 0 and 0.5 or math.floor(square) * 0.5
    table.insert(wave_table[1], math.sin(x * 2 * math.pi)) -- Sine
    table.insert(wave_table[2], math.abs((x * 2 - 0.5) % 2 - 1) * 2 - 1) -- Tri
    table.insert(wave_table[3], square) -- Square
    table.insert(wave_table[4], (1 - (x + 0.25) % 1) * 2 - 1) -- Saw
  end
  return wave_table
end

local function format_wave_shape(param)
  local value = param:get()
  local wave_names = {}

  if value < 0.28 then table.insert(wave_names, "Sine") end
  if value > 0.05 and value < 0.64 then table.insert(wave_names, "Tri") end
  if value > 0.38 and value < 0.95 then table.insert(wave_names, "Sqr") end
  if value > 0.71 then table.insert(wave_names, "Saw") end

  local return_string = ""
  for i = 1, #wave_names do
    if i > 1 then return_string = return_string .. "/" end
    return_string = return_string .. wave_names[i]
  end
  return return_string .. " " .. util.round(value, 0.01)
end

local function format_attack(param)
  local return_string
  if params:get("env_type") == 1 then
    return_string = "N/A"
  else
    return_string = Formatters.format_secs(param)
  end
  return return_string
end

function LfoBank:lookup_wave(x, shape_cv)
  x = util.round(x)

  local index_f = shape_cv * (#self.wave_lut - 1) + 1
  local index = util.round(index_f)
  local delta = index_f - index

  local index_offset = delta < 0 and -1 or 1
  local y

  -- Wave table lookup
  if delta == 0 then
    y = self.wave_lut[index][x]
  else
    y = self.wave_lut[index + index_offset][x] * math.abs(delta) + self.wave_lut[index][x] * (1 - math.abs(delta))
  end

  return y
end

local function mod_wave_index(i, phase)
  local i_shift = 0
  if phase ~= nil then
    i_shift = util.linlin(0, 360, 1, t_reso, phase)
  end

  i = i + i_shift

  while i >= t_reso do
      i = i - t_reso
  end

  -- NB: dirty bandaid
  if i < 1 then
    -- print ("BUMPING: "..x)
    i = 1
  else
    -- print ("KEEPING: "..x)
  end

  return i
end


-- ------------------------------------------------------------------------
-- constructors

function LfoBank.new(id, STATE,
                  phase_shifts, ratios,
                  page_id, x, y)
  local p = setmetatable({}, LfoBank)

  p.kind = "lfo_bank"
  p.id = id
  p.fqid = p.kind .. "_" .. id

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

  p.i_trig_dummy = Comparator.new(p.fqid.."_trig_dummy", p)

  p.i_rate = In.new(p.fqid.."_rate", p, nil, x, y+4)
  p.i_shape = In.new(p.fqid.."_shape", p, nil, x, y+5)
  p.i_hold = In.new(p.fqid.."_hold", p, nil, x, y+6)

  p.wave_outs = {}

  if phase_shifts == nil then
    p.phase_shifts = {}
  else
    p.phase_shifts = phase_shifts
  end

  if ratios == nil then
    p.ratios = {}
  else
    p.ratios = ratios
  end

  for i, phase in ipairs(phase_shifts) do
    p.wave_outs[i] = Out.new(p.fqid.."_"..i, p, x+1, y+i-1)
  end

  -- --------------------------------

  p.accums = {}
  for i, phase in ipairs(phase_shifts) do
    p.accums[i] = 0
  end

  p.clock = clock.run(function()
      p:clock()
  end)

  p.wave_lut = gen_wave_lut(1, t_reso)

  return p
end

function LfoBank:init_params()
  local id = self.id
  local fqid = self.fqid

  params:add_group(fqid, "Lfo Bank #"..id, 2)

    params:add{type = "control", id = fqid.."_rate", name = "Freq", controlspec = specs.LFO_FREQ, formatter = Formatters.format_freq}
    params:add{type = "control", id = fqid.."_shape", name = "Shape", controlspec = specs.WAVE_SHAPE, formatter = format_wave_shape}

end

function LfoBank.init(id, STATE,
                   phase_shifts, ratios,
                   page_id, x, y)
  local q = LfoBank.new(id, STATE,
                     phase_shifts, ratios,
                     page_id, x, y)

  q:init_params()

  if STATE ~= nil then
    STATE.ins[q.i_rate.id] = q.i_rate
    STATE.ins[q.i_shape.id] = q.i_shape
    STATE.ins[q.i_hold.id] = q.i_hold
    STATE.ins[q.i_trig_dummy.id] = q.i_trig_dummy
    for _, o in pairs(q.wave_outs) do
      STATE.outs[o.id] = o
    end
  end

  return q
end

function LfoBank:cleanup()
  clock.cancel(self.clock)
end


-- ------------------------------------------------------------------------
-- internal logic

function LfoBank:clock()
  local step_s = 1 / LFO_COMPUTATIONS_PER_S

  while true do
    clock.sleep(step_s)

    -- internal clock
    local speed = params:get(self.fqid.."_rate")
    local step = (speed / step_s) * t_reso / 600

    if self.i_hold.status == 1 then
      goto NEXT_LFO_CLOCK_TICK
    end

    for i, o in ipairs(self.wave_outs) do
      local ratio = 1
      if self.ratios[i] ~= nil then
        ratio = self.ratios[i]
      end

      local phase = 0
      if self.phase_shifts[i] ~= nil then
        phase = self.phase_shifts[i]
      end

      self.accums[i] = mod_wave_index(self.accums[i] + step * ratio)

      local v_norm = self:lookup_wave(mod_wave_index(self.accums[i], phase), params:get(self.fqid.."_shape"))
      local v = round(util.linlin(-1, 1, 0, V_MAX, v_norm))
      o:update(v)
    end

    -- NB: self-triggering to send out vals
    -- REVIEW: might be better to have a single clock for all RVGs & LfoBank doing that?
    -- even maybe an event queue, dropping events that are too old
    patching.fire_and_propagate(self.STATE.outs, self.STATE.ins, self.STATE.links, self.i_trig_dummy.id, V_MAX/2)

    ::NEXT_LFO_CLOCK_TICK::
  end
end

function LfoBank:process_ins()
  if self.i_rate.changed then
    params:set(self.fqid.."_rate", round(util.linlin(0, V_MAX, LFO_MIN_RATE, LFO_MAX_RATE, self.i_rate.v)))
  end
  if self.i_shape.changed then
    params:set(self.fqid.."_shape", self.i_shape.v/V_MAX)
  end
end


-- ------------------------------------------------------------------------
-- grid

function LfoBank:grid_redraw(g)
  paperface.module_grid_redraw(self, g)
end


-- ------------------------------------------------------------------------
-- screen

function LfoBank:redraw()
  paperface.module_redraw(self)
end

-- ------------------------------------------------------------------------

return LfoBank
