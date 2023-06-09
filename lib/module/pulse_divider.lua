-- haleseq. module/pulse divider
--
-- CGS pulse divider

local PulseDivider = {}
PulseDivider.__index = PulseDivider


-- ------------------------------------------------------------------------
-- deps

local Comparator = include("haleseq/lib/submodule/comparator")
local In = include("haleseq/lib/submodule/in")
local Out = include("haleseq/lib/submodule/out")

local patching = include("haleseq/lib/patching")
local paperface = include("haleseq/lib/paperface")
include("haleseq/lib/consts")


-- ------------------------------------------------------------------------
-- static conf

local CGS_PULSE_DIVS = {2, 3, 4, 5, 6, 7, 8}


-- ------------------------------------------------------------------------
-- constructors

function PulseDivider.new(id, STATE, divs,
                         page_id, x, y)
  local p = setmetatable({}, PulseDivider)

  p.kind = "pulse_divider"
  p.id = id
  p.fqid = "pulse_divider" .. "_" .. id

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

  p.i = Comparator.new(p.fqid, p, nil, x, y)

  -- VC switch of input for quantized_clock
  p.i_clock_select = In.new(p.fqid..'_clock_div', p, nil, x, y + 1)

  x = x + 1

  if divs == nil then divs = CGS_PULSE_DIVS end
  p.divs = divs
  p.div_states = {}
  p.div_outs = {}
  for i, div in ipairs(p.divs) do
    p.div_outs[i] = Out.new(p.fqid.."_"..div, p, x, y)
    p.div_states[i] = false
    y = y + 1
  end

  p.acum = 0

  if base == nil then base = 0 end
  p.base = base


  return p
end

function PulseDivider:quantized_clock_input_cb(v)
  local id = self.id
  local fqid = self.fqid
  local clock_id = fqid

  for o, ins in pairs(self.STATE.links) do
    if util.string_starts(o, "quantized_clock_global_") and tab.contains(ins, clock_id) then
      patching.remove_link(self.STATE.links, o, clock_id)
    end
  end

  patching.add_link(self.STATE.links, "quantized_clock_global_"..CLOCK_DIV_DENOMS[v], clock_id)

end

function PulseDivider:init_params()
  local id = self.id
  local fqid = self.fqid

  params:add_group(fqid, "pulse divider #"..id, 1)

  params:add_option(fqid.."_clock_div", "Clock Div", CLOCK_DIV_DENOMS, tab.key(CLOCK_DIV_DENOMS, 8))
  params:set_action(fqid.."_clock_div",
                    function(v)
                      self:quantized_clock_input_cb(v)
                    end
  )
  self:quantized_clock_input_cb(params:get(fqid.."_clock_div")) -- force callback for initial default value to create link
end

function PulseDivider.init(id, STATE, divs,
                           page_id, x, y)
  local q = PulseDivider.new(id, STATE, divs,
                             page_id, x, y)

  q:init_params()

  if STATE ~= nil then
    STATE.ins[q.i.id] = q.i
    STATE.ins[q.i_clock_select.id] = q.i_clock_select
    for _, o in ipairs(q.div_outs) do
      STATE.outs[o.id] = o
    end
  end

  return q
end


-- ------------------------------------------------------------------------
-- internal logic

function PulseDivider:process_ins()
  if self.i_clock_select.changed then
    local input_i = round(util.linlin(0, V_MAX, 1, #CLOCK_DIV_DENOMS, self.i_clock_select.v))
    params:set(self.fqid.."_clock_div", input_i)
  end

  if self.i.triggered then
    if self.i.status == 1 then
      self:tick()
    else
      for _, o in ipairs(self.div_outs) do
        o.v = 0
      end
    end
  end
end

function PulseDivider:mod(v, m)
  if self.base == 1 then
    return mod1(v, m)
  else -- base == 0
    return v % m
  end
end

function PulseDivider:tick()
  self.acum = self.acum + 1
  for i, d in ipairs(self.divs) do
    local state = (self:mod(self.acum, d) == 0)
    -- if d == 3 then
    --   dbgf("--------------")
    --   dbgf(self.acum)
    --   dbgf(self:mod(self.acum, d))
    --   dbgf(state)
    -- end
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

function PulseDivider:redraw()

  local triggered = (math.abs(os.clock() - self.i.last_up_t) < NANA_TRIG_DRAW_T)
  paperface.trig_in(paperface.grid_to_screen_x(self.i.x), paperface.grid_to_screen_y(self.i.y), triggered)

  triggered = (math.abs(os.clock() - self.i_clock_select.last_changed_t) < NANA_TRIG_DRAW_T)
  paperface.main_in(paperface.grid_to_screen_x(self.i_clock_select.x), paperface.grid_to_screen_y(self.i_clock_select.y), triggered)

  for i, v in ipairs(self.divs) do
    local o = self.div_outs[i]

    local x = paperface.grid_to_screen_x(o.x)
    local y = paperface.grid_to_screen_y(o.y)

    local trig = ( (math.abs(os.clock() - o.last_changed_t) < NANA_TRIG_DRAW_T))

    paperface.trig_out(x, y, trig)
    screen.move(x + SCREEN_STAGE_W + 2, y + SCREEN_STAGE_W - 2)
    screen.text("/"..v)
  end
end


-- ------------------------------------------------------------------------

return PulseDivider
