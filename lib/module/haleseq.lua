-- haleseq. module/haleseq

local musicutil = require "musicutil"

local Stage = include("haleseq/lib/submodule/stage")
local Comparator = include("haleseq/lib/submodule/comparator")
local In = include("haleseq/lib/submodule/in")
local Out = include("haleseq/lib/submodule/out")

local paperface = include("haleseq/lib/paperface")
local patching = include("haleseq/lib/patching")

include("haleseq/lib/consts")
include("haleseq/lib/core")


-- ------------------------------------------------------------------------

local Haleseq = {}
Haleseq.__index = Haleseq


-- ------------------------------------------------------------------------
-- constructors

function Haleseq.new(id, STATE,
                     nb_steps, nb_vsteps,
                     screen_id, x, y)
  local p = setmetatable({}, Haleseq)

  p.kind = "haleseq"

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

  p.nb_steps = nb_steps
  p.nb_vsteps = nb_vsteps


  -- --------------------------------
  -- I/O

  p.ins = {}
  p.outs = {}

  p.i_clock = Comparator.new(p.fqid.."_clock", p, nil,
                             SCREEN_W - SCREEN_STAGE_W,
                             SCREEN_H - SCREEN_STAGE_W)
  p.i_vclock = Comparator.new(p.fqid.."_vclock", p, nil,
                             SCREEN_W - SCREEN_STAGE_W,
                             SCREEN_STAGE_W)
  p.i_reset = Comparator.new(p.fqid.."_reset", p, nil,
                             SCREEN_W - SCREEN_STAGE_W,
                             2 * SCREEN_STAGE_W)
  p.i_vreset = Comparator.new(p.fqid.."_vreset", p, nil,
                             SCREEN_W - SCREEN_STAGE_W,
                             0)
  p.i_preset_reset = Comparator.new(p.fqid.."_preset_reset", p, nil,
                                    SCREEN_W - SCREEN_STAGE_W,
                                    4 * SCREEN_STAGE_W)
  p.i_hold = In.new(p.fqid.."_hold", p, nil,
                    SCREEN_W - SCREEN_STAGE_W,
                    3 * SCREEN_STAGE_W)
  p.i_reverse = In.new(p.fqid.."_reverse", p, nil,
                       SCREEN_W - SCREEN_STAGE_W,
                       5 * SCREEN_STAGE_W)

  p.i_preset = In.new(p.fqid.."_preset", p, nil,
                      SCREEN_W - 2 * SCREEN_STAGE_W,
                      SCREEN_H - SCREEN_STAGE_W)


  local stage_start_x = (SCREEN_W - (p.nb_steps * SCREEN_STAGE_W)) / 2

  p.stages = {}
  for s=1,nb_steps do
    local stage = Stage.new(p.fqid.."_stage_"..s, p, stage_start_x, SCREEN_STAGE_Y_OFFSET)
    p.stages[s] = stage
  end

  -- CPO - Common Pulse Out
  --   triggered on any change of preset (via button or trig in)
  --   TODO: goes high and remains high while a push button is pushed
  p.cpo = Out.new(p.fqid.."_cpo", p,
                  stage_start_x + p.nb_steps * SCREEN_STAGE_W, 0)
  -- AEP - All Event Pulse
  p.aep = Out.new(p.fqid.."_aep", p)

  p.cv_outs = {}

  -- A / B / C / D
  for vs=1, nb_vsteps do
    local label = output_nb_to_name(vs)
    local llabel = string.lower(label)
    local o = Out.new(p.fqid.."_"..llabel, p,
                      stage_start_x + p.nb_steps * SCREEN_STAGE_W, SCREEN_STAGE_W*vs)
    p.cv_outs[vs] = o
    -- table.insert(p.outs, o)
  end
  -- ABCD
  local mux_label = mux_output_nb_to_name(nb_vsteps)
  local mux_llabel = string.lower(mux_label)
  p.cv_outs[nb_vsteps+1] = Out.new(p.fqid.."_"..mux_llabel, p,
                                   stage_start_x + p.nb_steps * SCREEN_STAGE_W, SCREEN_STAGE_W*(nb_vsteps+1))


  -- --------------------------------

  p.seqvals = {}
  for s=1,nb_steps do
    p.seqvals[s] = {}
    for vs=1,nb_vsteps do
      p.seqvals[s][vs] = V_MAX/2
    end
  end

  p.step = 1
  p.vstep = 1

  p.prev_step = nil
  p.next_step = nil
  p.next_vstep = nil
  p.is_resetting = false

  p.last_step_t = 0
  p.last_vstep_t = 0
  p.last_preset_t = 0

  p.reverse = false
  p.vreverse = false
  p.hold = false

  p.g_knob = nil
  p.g_btn = nil

  return p
end


function Haleseq:init_params()
  local fqid = self.fqid
  local id = self.id

  params:add_group(fqid, "haleseq #"..id, 9)

  params:add_trigger(fqid.."_rnd_seqs", "Randomize Seqs")
  params:set_action(fqid.."_rnd_seqs",
                    function(_v)
                      if params:string("rnd_seq_mode") == 'Scale' then
                        self:randomize_seqvals_scale(params:string("rnd_seq_root"))
                      else
                        self:randomize_seqvals_blip_bloop()
                      end
                    end
  )

  params:add{type = "number", id = fqid.."_preset", name = "Preset", min = 1, max = NB_STEPS, default = 1}
  params:set_action(fqid.."_preset",
                    function(_v)
                      self.last_preset_t = os.clock()
                      self:reset_preset()
                    end
  )

  params:add_trigger("fw_"..id, "Forward")
  params:set_action("fw_"..id,
                    function(_v)
                      local next_preset = mod1(params:get(self.fqid.."_preset") + 1, self.nb_steps)
                      params:set(self.fqid.."_preset", next_preset)
                    end
  )
  params:add_trigger("bw_"..id, "Backward")
  params:set_action("bw_"..id,
                    function(_v)
                      local next_preset = params:get(self.fqid.."_preset") - 1
                      if next_preset == 0 then
                        next_preset = self.nb_steps
                      end
                      params:set(self.fqid.."_preset", next_preset)
                    end
  )
  params:add_trigger("vfw_"..id, "VForward")
  params:set_action("vfw_"..id,
                    function(_v)
                      vclock_acum = vclock_acum + 1
                      mclock_tick(nil, true)
                    end
  )
  params:add_trigger("vbw_"..id, "VBackward")
  params:set_action("vbw_"..id,
                    function(_v)
                      local vreverse_prev = self.vreverse
                      self.vreverse = true
                      vclock_acum = vclock_acum + 1
                      mclock_tick(nil, true)
                      self.vreverse = vreverse_prev
                    end
  )

  params:add_option("clock_div_"..id, "Clock Div", CLOCK_DIVS, tab.key(CLOCK_DIVS, 'off'))
  params:set_action("clock_div_"..id,
                    function(v)
                      local clock_id = "haleseq_"..self.id.."_clock"

                      for o, ins in pairs(STATE.links) do
                        if util.string_starts(o, "quantized_clock_global_") and tab.contains(ins, clock_id) then
                          patching.remove_link(STATE.links, o, clock_id)
                        end
                      end

                      if CLOCK_DIVS[v] ~= 'off' then
                        patching.add_link(links, "quantized_clock_global_"..CLOCK_DIV_DENOMS[v-1], clock_id)
                      end
                    end
  )
  params:add_option("vclock_div_"..id, "VClock Div", CLOCK_DIVS, tab.key(CLOCK_DIVS, 'off'))
  params:set_action("vclock_div_"..id,
                    function(v)
                      local clock_id = "haleseq_"..self.id.."_vclock"

                      for o, ins in pairs(links) do
                        if util.string_starts(o, "quantized_clock_global_") and tab.contains(ins, clock_id) then
                          patching.remove_link(links, o, clock_id)
                        end
                      end

                      if CLOCK_DIVS[v] ~= 'off' then
                        patching.add_link(links, "quantized_clock_global_"..CLOCK_DIV_DENOMS[v-1], clock_id)
                      end
                    end
  )
  local ON_OFF = {'on', 'off'}
  params:add_option("clock_quantize_"..id, "Clock Quantize", ON_OFF, tab.key(ON_OFF, 'on'))
end

function Haleseq.init(id, STATE, nb_steps, nb_vsteps,
                           screen_id, x, y)
  local h = Haleseq.new(id, STATE, nb_steps, nb_vsteps,
                        screen_id, x, y)
  h:init_params()

  if STATE ~= nil then
    STATE.ins[h.i_clock.id] = h.i_clock
    STATE.ins[h.i_vclock.id] = h.i_vclock
    STATE.ins[h.i_reset.id] = h.i_reset
    STATE.ins[h.i_vreset.id] = h.i_vreset
    STATE.ins[h.i_preset.id] = h.i_preset
    STATE.ins[h.i_hold.id] = h.i_hold
    STATE.ins[h.i_reverse.id] = h.i_reverse

    for _, s in ipairs(h.stages) do
      STATE.ins[s.i.id] = s.i
      STATE.outs[s.o.id] = s.o
    end

    STATE.outs[h.cpo.id] = h.cpo
    STATE.outs[h.aep.id] = h.aep

    for _, cv in ipairs(h.cv_outs) do
      STATE.outs[cv.id] = cv
    end

  end
  return h
end


-- ------------------------------------------------------------------------
-- internal logic

function Haleseq:process_ins()
  local ticked = false
  local vticked = false

  if self.i_preset.changed then
    params:set(self.fqid.."_preset", round(util.linlin(0, V_MAX, 1, self.nb_steps, self.i_preset.v)))
  else
    for v, stage in ipairs(self.stages) do
      if stage.i.triggered and stage.i.status == 1 then
        params:set(self.fqid.."_preset", v)
        break
      end
    end
  end

  -- if self.i_clock.status == 1 or forced then
  ticked = self:clock_tick()
  -- end
  -- if self.i_vclock.status == 1 then
  vticked = self:vclock_tick()
  -- end

  -- A / B / C / D
  if ticked then
    for vs=1,self.nb_vsteps do
      self.cv_outs[vs]:update(self:get_current_play_volts(vs))
    end
  end

  -- ABCD
  if ticked or vticked then
    self.cv_outs[self.nb_vsteps+1]:update(self:get_current_mux_play_volts())
  end

  -- TODO: stage gate out!

end


-- ------------------------------------------------------------------------
-- getters

function Haleseq:get_id()
  return self.id
end

function Haleseq:get_nb_vsteps()
  return self.nb_vsteps
end

function Haleseq:is_editing_knob()
  if self.g_knob ~= nil then
    return true
  end
  return false
end


-- ------------------------------------------------------------------------
-- state - pos

function Haleseq:has_next_step()
  if self.next_step ~= nil then
    return true
  end
  return false
end

function Haleseq:has_next_vstep()
  if self.next_vstep ~= nil then
    return true
  end
  return false
end

function Haleseq:reset()
  self.is_resetting = true
  self.next_step = 1
end

function Haleseq:vreset()
  self.next_vstep = 1
end

function Haleseq:reset_preset()
  self.next_step = params:get(self.fqid.."_preset")
end

function Haleseq:are_all_stage_skip(ignore_preset)
  local nb_skipped = 0

  local start = params:get(self.fqid.."_preset")
  if ignore_preset then
    start = 1
  end

  for s=start,self.nb_steps do
    if self.stages[s]:get_mode() == Stage.M_SKIP then
      nb_skipped = nb_skipped + 1
    end
  end
  return (nb_skipped == (self.nb_steps-start+1))
end

function Haleseq:clock_tick()

  local do_quantize = (params:string("clock_quantize_"..self.id) == "on")
  local clock_quantize_is_off = (params:string("clock_div_"..self.id) == "off")

  local clock_input_triggered = (self.i_clock.triggered and self.i_clock.status == 1)

  local clock_is_ticking = (not clock_quantize_is_off) and clock_input_triggered

  -- if clock_quantize_is_off and not self.next_step then
  --   return false
  -- end

  -- --------------------------------
  -- case 1: forced to go to `next_step`

  if self.next_step ~= nil then
    if do_quantize and not (clock_quantize_is_off or clock_is_ticking) then
      return false
    end

    self.step = self.next_step
    self.next_step = nil
    self.last_step_t = os.clock()

    -- NB: i/o patching, to rewrite
    -- if self.stages[self.step].o ~= nil and not (clock_div == 0) then
    --   self.next_step = self.stages[step].o
    -- end

    return true
  end

  -- if clock_quantize_is_off or not clock_is_ticking then
  if not clock_input_triggered then
    return false
  end

  -- --------------------------------
  -- case 2: hold

  if self.hold then
    return false
  end

  -- --------------------------------
  -- case 3: advance

  -- prevent deadlock
  if self:are_all_stage_skip(self.is_resetting) then
    return false
  end

  if self.stages[self.step]:get_mode() ~= Stage.M_TIE then
    self.prev_step = self.step
  end

  local sign = self.reverse and -1 or 1

  -- advance once ...
  self.step = mod1(self.step + sign, self.nb_steps)

  -- ... skip until at preset ...
  if not self.is_resetting then
    while self.step < params:get(self.fqid.."_preset") do
      self.step = mod1(self.step + sign, self.nb_steps)
    end
  end

  -- ... skip stages in skip mode ...
  while self.stages[self.step]:get_mode() == Stage.M_SKIP do
    self.step = mod1(self.step + sign, self.nb_steps)
  end
  if self.step >= params:get(self.fqid.."_preset") then
    self.is_resetting = false
  end

  -- ... skip (again) until at preset ...
  if not self.is_resetting then
    while self.step < params:get(self.fqid.."_preset") do
      self.step = mod1(self.step + sign, self.nb_steps)
    end
  end

  -- NB: i/o patching, to rewrite
  -- if self.stages[self.step].o ~= nil then
  --   self.next_step = self.stages[step].o
  -- end

  self.last_step_t = os.clock()
  return true
end

function Haleseq:vclock_tick()

  local do_quantize = (params:string("clock_quantize_"..self.id) == "off")
  local vclock_is_off = (params:string("vclock_div_"..self.id) == "off")

  local vclock_input_triggered = (self.i_vclock.triggered and self.i_vclock.status == 1)

  local vclock_is_ticking = (not vclock_is_off) and vclock_input_triggered


  -- --------------------------------
  -- case 1: forced to go to `next_vstep`

  if self.next_vstep ~= nil then
    if do_quantize and not (vclock_is_off or vclock_is_ticking) then
      return false
    end

    self.vstep = self.next_vstep
    self.next_vstep = nil
    self.last_vstep_t = os.clock()

    return true
  end

  -- if vclock_is_off or not vclock_is_ticking then
  if not vclock_input_triggered then
    return false
  end

  -- --------------------------------
  -- case 2: hold

  -- NB: hold has no effect on vclock

  -- --------------------------------
  -- case 3: advance

  local sign = self.vreverse and -1 or 1

  self.vstep = mod1(self.vstep + sign, self.nb_vsteps)
  self.last_vstep_t = os.clock()

  return true
end


-- ------------------------------------------------------------------------
-- playback

function Haleseq:get_current_play_stage()
  local s = self.step
  if self.stages[s]:get_mode() == Stage.M_TIE and self.prev_step ~= nil then
    s = self.prev_step
  end
  return s
end

-- A / B / C / D
function Haleseq:get_current_play_volts(vs)
  local s = self:get_current_play_stage()

  return self.seqvals[s][vs]
end

--- ABCD
function Haleseq:get_current_mux_play_volts()
  local s = self:get_current_play_stage()
  return self.seqvals[s][self.vstep]
end


-- ------------------------------------------------------------------------
-- state - sequences

function Haleseq:randomize_seqvals_octaves()
  local nbx = self.nb_steps
  local nby = self.nb_vsteps

  srand(math.random(10000))

  local octave = 3
  local octave_v = V_MAX / V_NB_OCTAVES
  for y=1,nby do
    for x=1,nbx do
      local note = math.random(octave_v + 1) - 1
      self.seqvals[x][y] = octave * octave_v + note
    end
    octave = octave + 1
  end
end

function Haleseq:randomize_seqvals_blip_bloop()
  local nbx = self.nb_steps
  local nby = self.nb_vsteps

  srand(math.random(10000))

  for y=1,nby do
    for x=1,nbx do
      local note = math.random(round(3*V_MAX/4) + 1) - 1
      self.seqvals[x][y] = note
    end
  end
end

function Haleseq:randomize_seqvals_scale(root_note)
  local nbx = self.nb_steps
  local nby = self.nb_vsteps

  local octaves = {1, 2, 3, 4, 5, 7, 8, 9}

  srand(math.random(10000))

  local chord_root_freq = tab.key(musicutil.NOTE_NAMES, root_note) - 1
  local scale = musicutil.generate_scale_of_length(chord_root_freq, nbx)
  local nb_notes_in_scale = tab.count(scale)

  for y=1,nby do
    for x=1,nbx do
      local note = scale[math.random(nb_notes_in_scale)] + 12 * octaves[math.random(#octaves)]
      self.seqvals[x][y] = round(util.linlin(0, 127, 0, V_MAX, note))
    end
  end
end


-- ------------------------------------------------------------------------
-- knobs

function Haleseq:knob(n, d)
  local v = self.g_knob[1]
  local vs = self.g_knob[2]
  self.seqvals[v][vs] = util.clamp(self.seqvals[v][vs] + d*5, 0, V_MAX)
end

function Haleseq:knob_vs()
  if self.g_knob == nil then
    return
  end
  return self.g_knob[2]
end

function Haleseq:knob_volts()
  if self.g_knob == nil then
    return
  end
  local v = self.g_knob[1]
  local vs = self.g_knob[2]
  return self.seqvals[v][vs]
end

-- ------------------------------------------------------------------------
-- grid

local G_Y_PRESS = 8
local G_Y_KNOB = 2

local STEPS_GRID_X_OFFSET = 4


function Haleseq:grid_redraw(g)
  local l = 3

  for s=1,self.nb_steps do
    l = 3
    local x = s + STEPS_GRID_X_OFFSET
    local y = 1

    g:led(x, y, 1)     -- trig out
    y = y + 1
    g:led(x, y, 1)     -- trig in
    for vs=1,self.nb_vsteps do
      if (self.step == s) and (self.vstep == vs) then
        l = 15
      else
        l = round(util.linlin(0, V_MAX, 0, 12, self.seqvals[s][vs]))
      end
      g:led(x, G_Y_KNOB+vs, l) -- value
    end
    y = y + self.nb_vsteps + 1
    --                -- <pad>
    l = 1
    local mode = self.stages[s]:get_mode()
    if (params:get(self.fqid.."_preset") == s) then
      l = 8
    elseif mode == Stage.M_RUN then
      l = 2
    elseif mode == Stage.M_SKIP then
      l = 0
    elseif mode == Stage.M_TIE then
      l = 4
    end
    g:led(x, y, l)   -- tie / run / skip
    l = 1
    if self.next_step ~= nil then
      if self.next_step == s then
        l = 5
      elseif self.step == s then
        l = 2
      end
    elseif self.step == s then
      l = 10
    end
    g:led(x, G_Y_PRESS, l)   -- press / select in
  end

  local x = STEPS_GRID_X_OFFSET + self.nb_steps + 1
  for vs=1,self.nb_vsteps do
    l = (self.vstep == vs) and 5 or 1
    g:led(x, 2+vs, l) -- v out
  end

  g:led(16, 1, 5) -- vreset
  g:led(16, 2, 1) -- vclock
  g:led(16, 3, 5) -- reset
  g:led(16, 4, 3) -- hold
  g:led(16, 5, 5) -- preset
  g:led(16, 6, 3) -- reverse
  g:led(16, 7, 3) -- clock
end

function Haleseq:grid_key(x, y, z)
  if x > STEPS_GRID_X_OFFSET and x <= STEPS_GRID_X_OFFSET + self.nb_steps then
    if y == G_Y_PRESS then
      local s = x - STEPS_GRID_X_OFFSET
      -- DEBUG = true
      if (z >= 1) then
        self.g_btn = s

        -- TODO: should be a set stage input & propagate!
        -- params:set(self.fqid.."_preset", s)
        -- self.last_preset_t = os.clock()
        -- self:process_ins(true)

        -- self.stages[s].i.register("user", V_MAX/2)
        -- or even better
        patching.fire_and_propagate(self.STATE.outs, self.STATE.ins, self.STATE.links, self.stages[s].i.id, V_MAX/2)

      else
        -- self.stages[s].i.register("user", 0)
        -- or even better
        patching.fire_and_propagate(self.STATE.outs, self.STATE.ins, self.STATE.links, self.stages[s].i.id, 0)
        self.g_btn = nil
      end
      return
    end
    if y == 7 and z >= 1 then
      local s = x - STEPS_GRID_X_OFFSET
      self.stages[s]:mode_cycle()
      return
    end
    if y >= G_Y_KNOB and y < G_Y_KNOB + NB_STEPS then
      if z >= 1 then
        local s = x - STEPS_GRID_X_OFFSET
        local vs = y - G_Y_KNOB
        self.g_knob = {s, vs}
      else
        self.g_knob = nil
      end
    end
  end

  if x == 16 and y == 1 and z >= 1 then
    self:vreset()
    return
  end
  if x == 16 and y == 3 and z >= 1 then
    self:reset()
    return
  end
  if x == 16 and y == 4 then
    self.hold = (z >= 1)
    return
  end
  if x == 16 and y == 5 and z >= 1 then
    self:reset_preset()
    return
  end
  if x == 16 and y == 6 then
    self.reverse = (z >= 1)
    return
  end
end


-- ------------------------------------------------------------------------
-- screen

local SCREEN_STAGE_OUT_Y = 1
local SCREEN_STAGE_KNOB_Y = 2
local SCREEN_STAGE_MODE_Y = 6
local SCREEN_PRESET_IN_Y = 7

function Haleseq:redraw_stage(x, y, s)
  local y2

  -- trig out
  y2 = y + (SCREEN_STAGE_OUT_Y - 1) * SCREEN_STAGE_W
  local at = (self.step == s)
  local trig = at and (math.abs(os.clock() - self.last_step_t) < PULSE_T)
   paperface.trig_out(x, y2, trig)
  if not trig and at then
    paperface.banana(x, y2, false)
  end

  -- trig in
  y2 = y + (SCREEN_PRESET_IN_Y - 1) * SCREEN_STAGE_W
  if params:get(self.fqid.."_preset") == s then
    if (self.g_btn == s) then
      paperface.trig_in(x, y2, true)
    else
      paperface.trig_in(x, y2, false, true)
    end
  else
    paperface.trig_in(x, y2, (self.g_btn == s))
  end

  -- vals
  y2 = y + (SCREEN_STAGE_KNOB_Y - 1) * SCREEN_STAGE_W
  for vs=1,self.nb_vsteps do
    -- l = SCREEN_LEVEL_LABEL
    -- if params:get(self.fqid.."_preset") == s then
    --   l = SCREEN_LEVEL_LABEL_SPE
    -- end
    -- paperface.rect_label(x, y2, l)
    paperface.rect_label(x, y2)
    l = 1
    if at then
      if (self.vstep == vs) then
        l = SCREEN_LEVEL_LABEL_SPE
      else
        l = 2
      end
    end
    paperface.knob(x, y2, self.seqvals[s][vs], l)
    y2 = y2 + SCREEN_STAGE_W
  end

  -- mode
  y2 = y + (SCREEN_STAGE_MODE_Y - 1) * SCREEN_STAGE_W
  paperface.rect_label(x, y2)
  paperface.mode_switch(x, y2, self.stages[s]:get_mode())
end

function Haleseq:redraw()
  -- seq
  local x = (SCREEN_W - (self.nb_steps * SCREEN_STAGE_W)) / 2
  for s=1,self.nb_steps do
    self:redraw_stage(x, SCREEN_STAGE_Y_OFFSET, s)
    x = x + SCREEN_STAGE_W
  end

  -- vseq
  local y = SCREEN_STAGE_Y_OFFSET + (SCREEN_STAGE_KNOB_Y - 1) * SCREEN_STAGE_W
  for vs=1,self.nb_vsteps do
    local at = (self.vstep == vs)
    local trig = at and (math.abs(os.clock() - self.last_vstep_t) < PULSE_T)
    paperface.trig_out(x, y, trig)
    if not trig and at then
      paperface.banana(x, y, false)
    end
    y = y + SCREEN_STAGE_W
  end

  -- CPO (preset change gate out)
  local y = SCREEN_STAGE_Y_OFFSET
  paperface.trig_out(x, y, math.abs(os.clock() - self.last_preset_t) < PULSE_T, SCREEN_LEVEL_LABEL_SPE)

  x = x + SCREEN_STAGE_W * 2

  trig = false
  paperface.trig_in(x, y, trig) -- vreset
  y = y + SCREEN_STAGE_W
  trig = (math.abs(os.clock() - self.i_vclock.last_up_t) < PULSE_T)
  paperface.trig_in(x, y, trig) -- vclock
  y = y + SCREEN_STAGE_W
  trig = false
  paperface.trig_in(x, y, trig) -- reset
  y = y + SCREEN_STAGE_W
  paperface.trig_in(x, y, trig) -- hold
  y = y + SCREEN_STAGE_W
  paperface.trig_in(x, y, trig) -- preset (reset)
  y = y + SCREEN_STAGE_W
  paperface.trig_in(x, y, trig) -- reverse
  y = y + SCREEN_STAGE_W
  trig = (math.abs(os.clock() - self.i_clock.last_up_t) < PULSE_T)
  paperface.trig_in(x, y, trig) -- clock

  x = x - SCREEN_STAGE_W
  trig = (math.abs(os.clock() - self.i_preset.last_changed_t) < PULSE_T)
  paperface.main_in(x, y, trig) -- preset (VC)
end


-- ------------------------------------------------------------------------

return Haleseq
