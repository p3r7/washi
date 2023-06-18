-- washi. module/haleseq

local musicutil = require "musicutil"
local inspect = include("washi/lib/inspect")

local Stage = include("washi/lib/submodule/stage")
local Comparator = include("washi/lib/submodule/comparator")
local In = include("washi/lib/submodule/in")
local Out = include("washi/lib/submodule/out")

local paperface = include("washi/lib/paperface")
local patching = include("washi/lib/patching")

include("washi/lib/consts")
include("washi/lib/core")


-- ------------------------------------------------------------------------

local Haleseq = {}
Haleseq.__index = Haleseq


-- ------------------------------------------------------------------------
-- constructors

function Haleseq.new(id, STATE,
                     nb_steps, nb_vsteps,
                     page_id, x, y)
  local p = setmetatable({}, Haleseq)

  p.kind = "haleseq"

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

  p.nb_steps = nb_steps
  p.nb_vsteps = nb_vsteps


  -- --------------------------------
  -- I/O

  p.ins = {}
  p.outs = {}

  p.i_clock = Comparator.new(p.fqid.."_clock", p, nil,
                             SCREEN_STAGE_X_NB,
                             7)
  p.i_vclock = Comparator.new(p.fqid.."_vclock", p, nil,
                             SCREEN_STAGE_X_NB,
                             2)
  p.i_reset = Comparator.new(p.fqid.."_reset", p, nil,
                             SCREEN_STAGE_X_NB,
                             3)
  p.i_vreset = Comparator.new(p.fqid.."_vreset", p, nil,
                             SCREEN_STAGE_X_NB,
                             1)
  p.i_preset_reset = Comparator.new(p.fqid.."_preset_reset", p, nil,
                                    SCREEN_STAGE_X_NB,
                                    5)
  p.i_hold = Comparator.new(p.fqid.."_hold", p, nil,
                            SCREEN_STAGE_X_NB,
                            4)
  p.i_reverse = Comparator.new(p.fqid.."_reverse", p, nil,
                               SCREEN_STAGE_X_NB,
                               6)

  p.i_preset = In.new(p.fqid.."_preset", p, nil,
                      SCREEN_STAGE_X_NB - 1,
                      7)


  local stage_start_x = SCREEN_STAGE_X_NB - 2 - p.nb_steps - 1

  p.stages = {}
  for s=1,nb_steps do
    local stage = Stage.new(p.fqid.."_stage_"..s, p, stage_start_x+s-1, 1)
    p.stages[s] = stage
  end

  -- CPO - Common Pulse Out
  --   triggered on any change of preset (via button or trig in)
  --   TODO: goes high and remains high while a push button is pushed
  p.cpo = Out.new(p.fqid.."_cpo", p,
                  stage_start_x + p.nb_steps, 1)
  p.cpo_end_clock = nil
  -- AEP - All Event Pulse
  p.aep = Out.new(p.fqid.."_aep", p,
                  stage_start_x + p.nb_steps + 1, 1)
  p.aep_end_clock = nil

  p.cv_outs = {}

  -- A / B / C / D
  for vs=1, nb_vsteps do
    local label = output_nb_to_name(vs)
    local llabel = string.lower(label)
    local o = Out.new(p.fqid.."_"..llabel, p,
                      stage_start_x + p.nb_steps, vs+1)
    p.cv_outs[vs] = o
  end
  -- ABCD
  local mux_label = mux_output_nb_to_name(nb_vsteps)
  local mux_llabel = string.lower(mux_label)
  p.cv_outs[nb_vsteps+1] = Out.new(p.fqid.."_"..mux_llabel, p,
                                   stage_start_x + p.nb_steps + 1, nb_vsteps+2)


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

  p.vreverse = false

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
                      for o, ins in pairs(self.STATE.links) do
                        if util.string_starts(o, "quantized_clock_global_") and tab.contains(ins, clock_id) then
                          patching.remove_link(self.STATE.links, o, clock_id)
                        end
                      end

                      if CLOCK_DIVS[v] ~= 'off' then
                        patching.add_link(self.STATE.links, "quantized_clock_global_"..CLOCK_DIV_DENOMS[v-1], clock_id)
                      end
                    end
  )
  params:add_option("vclock_div_"..id, "VClock Div", CLOCK_DIVS, tab.key(CLOCK_DIVS, 'off'))
  params:set_action("vclock_div_"..id,
                    function(v)
                      local clock_id = "haleseq_"..self.id.."_vclock"

                      for o, ins in pairs(self.STATE.links) do
                        if util.string_starts(o, "quantized_clock_global_") and tab.contains(ins, clock_id) then
                          patching.remove_link(self.STATE.links, o, clock_id)
                        end
                      end

                      if CLOCK_DIVS[v] ~= 'off' then
                        patching.add_link(self.STATE.links, "quantized_clock_global_"..CLOCK_DIV_DENOMS[v-1], clock_id)
                      end
                    end
  )
  local ON_OFF = {'on', 'off'}
  params:add_option("clock_quantize_"..id, "Clock Quantize", ON_OFF, tab.key(ON_OFF, 'on'))
end

function Haleseq.init(id, STATE, nb_steps, nb_vsteps,
                           page_id, x, y)
  local h = Haleseq.new(id, STATE, nb_steps, nb_vsteps,
                        page_id, x, y)
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
    local any_stage_preset_up = false
    for v, stage in ipairs(self.stages) do
      if stage.i.triggered and stage.i.status == 1 then
        any_stage_preset_up = true
        params:set(self.fqid.."_preset", v)
        break
      end
    end
    if any_stage_preset_up then
      self.cpo:update(V_MAX/2)
      if self.cpo_end_clock then
        clock.cancel(self.cpo_end_clock)
      end
      self.cpo_end_clock = clock.run(function()
          clock.sleep(TRIG_S)
          -- TODO: propagate
          self.cpo:update(0)
      end)
    end
  end

  if self.i_reset.status == 1 then
    self:reset()
  end
  if self.i_vreset.status == 1 then
    self:vreset()
  end
  if self.i_preset_reset.status == 1 then
    self:reset_preset()
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

    -- REVIEW: should implement special out for gate w/ own pulse width?!
    self.aep:update(V_MAX/2)

    if self.aep_end_clock then
      clock.cancel(self.aep_end_clock)
    end
    self.aep_end_clock = clock.run(function()
        clock.sleep(pulse_width_dur(params:get("pulse_width"), NB_BARS))
        -- TODO: propagate
        self.aep:update(0)
    end)

    -- REVIEW: shoudl maybe set them all to 0 at begining of the fn?
    for s, stage in ipairs(self.stages) do
      local v = 0
      if self.step == s then
        v = V_MAX/2
      end
      stage.o:update(v)
    end
  end
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

  if self.i_hold.status == 1 then
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

  local sign = (self.i_reverse.status == 1) and -1 or 1

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

local G_Y_PRESET = 8
local G_Y_KNOB = 2

local STEPS_GRID_X_OFFSET = 4


function Haleseq:grid_redraw(g)
  local l = 3

  for s=1,self.nb_steps do
    l = 3
    local x = s + STEPS_GRID_X_OFFSET
    local y = 2

    l = (self.step == s) and 5 or 1
    g:led(x, y, l)     -- trig out

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
    -- if (params:get(self.fqid.."_preset") == s) then
    --   l = 8
    -- elseif
    if mode == Stage.M_RUN then
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
    elseif (params:get(self.fqid.."_preset") == s) then
      l = 5
    end
    g:led(x, G_Y_PRESET, l)   -- press / select in
  end

  local x = STEPS_GRID_X_OFFSET + self.nb_steps + 1
  for vs=1,self.nb_vsteps do
    l = (self.vstep == vs) and 5 or 1
    g:led(x, 2+vs, l) -- v out
  end

  paperface.out_grid_redraw(self.cv_outs[self.nb_vsteps+1], g)

  paperface.out_grid_redraw(self.aep, g, 0)
  paperface.out_grid_redraw(self.cpo, g, 0)

  paperface.in_grid_redraw(self.i_vreset, g, 5)
  paperface.in_grid_redraw(self.i_vclock, g, 3)
  paperface.in_grid_redraw(self.i_reset, g, 5)
  paperface.in_grid_redraw(self.i_hold, g, 3)
  paperface.in_grid_redraw(self.i_preset_reset, g, 5)
  paperface.in_grid_redraw(self.i_reverse, g, 3)
  paperface.in_grid_redraw(self.i_clock, g, 3)
end

function Haleseq:grid_key(x, y, z)
  if x > STEPS_GRID_X_OFFSET and x <= STEPS_GRID_X_OFFSET + self.nb_steps then

    -- PRESET
    if y == G_Y_PRESET then
      local s = x - STEPS_GRID_X_OFFSET
      -- DEBUG = true
      if (z >= 1) then
        self.g_btn = s
        patching.fire_and_propagate(self.STATE.outs, self.STATE.ins, self.STATE.links, self.stages[s].i.id, V_MAX/2)
      else
        self.g_btn = nil
        patching.fire_and_propagate(self.STATE.outs, self.STATE.ins, self.STATE.links, self.stages[s].i.id, 0)
      end
      return
    end

    -- RUN / SKIP / TIE
    if y == 7 and z >= 1 then
      local s = x - STEPS_GRID_X_OFFSET
      self.stages[s]:mode_cycle()
      return
    end

    -- KNOBS (CV vals)
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

  -- if x == 16 and y == 7 then
  --   if (z >= 1) then
  --     self.i_clock:register("GLOBAL", V_MAX/2)
  --   else
  --     self.i_clock:register("GLOBAL", 0)
  --   end
  --   self.i_clock:update()
  --   return
  -- end
  -- if x == 16 and y == 2 then
  --   if (z >= 1) then
  --     self.i_vclock:register("GLOBAL", V_MAX/2)
  --   else
  --     self.i_vclock:register("GLOBAL", 0)
  --   end
  --   self.i_vclock:update()
  --   return
  -- end

  if x == 16 and y == 2 then
    if (z >= 1) then
      self.i_vreset:register("GLOBAL", V_MAX/2)
    else
      self.i_vreset:register("GLOBAL", 0)
    end
    self.i_vreset:update()
    return
  end
  if x == 16 and y == 4 then
    if (z >= 1) then
      self.i_reset:register("GLOBAL", V_MAX/2)
    else
      self.i_reset:register("GLOBAL", 0)
    end
    self.i_reset:update()
    return
  end
  if x == 16 and y == 5 then
    if (z >= 1) then
      self.i_hold:register("GLOBAL", V_MAX/2)
    else
      self.i_hold:register("GLOBAL", 0)
    end
    self.i_hold:update()
    return
  end
  if x == 16 and y == 6 then
    if (z >= 1) then
      self.i_preset_reset:register("GLOBAL", V_MAX/2)
    else
      self.i_preset_reset:register("GLOBAL", 0)
    end
    self.i_preset_reset:update()
    return
  end
  if x == 16 and y == 7 then
    if (z >= 1) then
      self.i_reverse:register("GLOBAL", V_MAX/2)
    else
      self.i_reverse:register("GLOBAL", 0)
    end
    self.i_reverse:update()
    return
  end
end


-- ------------------------------------------------------------------------
-- screen

local SCREEN_STAGE_OUT_Y = 1
local SCREEN_STAGE_KNOB_Y = 2
local SCREEN_STAGE_MODE_Y = 6
local SCREEN_PRESET_IN_Y = 7

function Haleseq:redraw_stage(s, stage)

  local x = paperface.panel_grid_to_screen_x(stage.x)

  -- trig out
  local at = (self.step == s)
  local trig = at and (math.abs(os.clock() - self.last_step_t) < PULSE_T)
   paperface.trig_out(x, paperface.panel_grid_to_screen_y(stage.o.y), trig)
  if not trig and at then
    paperface.banana(x, paperface.panel_grid_to_screen_y(stage.o.y), false)
  end

  -- trig in
  if params:get(self.fqid.."_preset") == s then
    if (self.g_btn == s) then
      paperface.trig_in(x, paperface.panel_grid_to_screen_y(stage.i.y), true)
    else
      paperface.trig_in(x, paperface.panel_grid_to_screen_y(stage.i.y), false, true)
    end
  else
    paperface.trig_in(x, paperface.panel_grid_to_screen_y(stage.i.y), (self.g_btn == s))
  end

  -- vals (knobs)
  for vs=1,self.nb_vsteps do
    local y = paperface.panel_grid_to_screen_y(stage.y+vs)
    paperface.rect_label(x, y)
    l = 1
    if at then
      if (self.vstep == vs) then
        l = SCREEN_LEVEL_LABEL_SPE
      else
        l = 2
      end
    end
    paperface.knob(x, y, self.seqvals[s][vs], l)
  end

  -- mode
  local mode_y = paperface.panel_grid_to_screen_y(stage.y+self.nb_vsteps+1)
  paperface.rect_label(x, mode_y)
  paperface.mode_switch(x, mode_y, self.stages[s]:get_mode())
end

function Haleseq:redraw()
  -- seq
  for s, stage in ipairs(self.stages) do
    self:redraw_stage(s, stage)
  end

  -- vseq
  for vs=1,self.nb_vsteps do
    local o = self.cv_outs[vs]
    local at = (self.vstep == vs)
    local trig = at and (math.abs(os.clock() - self.last_vstep_t) < PULSE_T)

    local x = paperface.panel_grid_to_screen_x(o.x)
    local y = paperface.panel_grid_to_screen_y(o.y)

    paperface.trig_out(x, y, trig)
    if not trig and at then
      paperface.banana(x, y, false)
    end
  end
  local trig_mux = (math.abs(os.clock() - self.cv_outs[self.nb_vsteps+1].last_changed_t) < PULSE_T)
  local mux_o = self.cv_outs[self.nb_vsteps+1]
  paperface.trig_out(paperface.panel_grid_to_screen_x(mux_o.x), paperface.panel_grid_to_screen_y(mux_o.y), trig_mux, SCREEN_LEVEL_LABEL_SPE)

  -- CPO - Common Pulse Out
  -- (preset change gate out)
  local trig_cpo = (self.cpo.v > 0
                    or (math.abs(os.clock() - self.cpo.last_changed_t) < PULSE_T))
  paperface.trig_out(paperface.panel_grid_to_screen_x(self.cpo.x), paperface.panel_grid_to_screen_y(self.cpo.y), trig_cpo, SCREEN_LEVEL_LABEL_SPE)

  -- AEP - All Event Pulse
  local trig_aep = (self.aep.v > 0 or (math.abs(os.clock() - self.aep.last_changed_t) < PULSE_T))
  paperface.trig_out(paperface.panel_grid_to_screen_x(self.aep.x), paperface.panel_grid_to_screen_y(self.aep.y), trig_aep, SCREEN_LEVEL_LABEL_SPE)

  paperface.in_redraw(self.i_vreset)
  paperface.in_redraw(self.i_vclock)
  paperface.in_redraw(self.i_reset)
  paperface.in_redraw(self.i_hold)
  paperface.in_redraw(self.i_preset_reset)
  paperface.in_redraw(self.i_reverse)
  paperface.in_redraw(self.i_clock)
  paperface.in_redraw(self.i_preset)

  if self.scope_on then
    self.STATE.scope:redraw(SCREEN_W/4, SCREEN_H/4, SCREEN_W/2, SCREEN_H/2)
  end

end


-- ------------------------------------------------------------------------

return Haleseq
