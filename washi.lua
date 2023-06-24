-- washi.
-- @eigen
--
--
--
--
--
--    ▼ instructions below ▼
--
-- based on the work of:
-- - Serge Tcherepnin
-- - Rex Probe
-- - Ken Stone
-- - Dakota Melin (@hale)


-- ------------------------------------------------------------------------
-- deps

local lattice = require "lattice"
local musicutil = require "musicutil"
local UI = require "ui"

local nb = include("washi/lib/nb/lib/nb")
local inspect = include("washi/lib/inspect")

local paperface = include("washi/lib/paperface")
local patching = include("washi/lib/patching")
local Scope = include("washi/lib/scope")

-- modules
local NornsClock = include("washi/lib/module/norns_clock")
local QuantizedClock = include("washi/lib/module/quantized_clock")
local PulseDivider = include("washi/lib/module/pulse_divider")
local Rvg = include("washi/lib/module/rvg")
local LfoBank = include("washi/lib/module/lfo_bank")
local Haleseq = include("washi/lib/module/haleseq")
local Output = include("washi/lib/module/output")

include("washi/lib/core")
include("washi/lib/consts")


-- ------------------------------------------------------------------------
-- conf

-- local NB_HALESEQS = 1
local NB_HALESEQS = 2
local NB_OUTS = 6

local norns_clock
local quantized_clocks
local pulse_dividers = {}
local rvgs = {}
local lfos = {}
local haleseqs = {}
local outputs = {}

local page_list = {'clock', 'mod'}
for h=1, NB_HALESEQS do
  table.insert(page_list, 'haleseq '..h)
end
table.insert(page_list, 'outputs')
local pages = UI.Pages.new(1, #page_list)
pages:set_index(tab.key(page_list, 'haleseq 1'))


-- ------------------------------------------------------------------------
-- patching

ins = {}
outs = {}
links = {}
coords_to_nana = {}

STATE = {
  ins = ins,
  outs = outs,
  links = links,
  selected_out = nil,
  scope = nil,
  coords_to_nana = coords_to_nana,
}

local function add_link(o, i)
  patching.add_link(links, o, i)
end

local function remove_link(o, i)
  patching.remove_link(links, o, i)
end

local function fire_and_propagate(in_label, initial_v)
  return patching.fire_and_propagate(outs, ins, links,
                                     in_label, initial_v)
end

local function rnd_std_cv_out_llabel_for_haleseq(h)
  return string.lower(output_nb_to_name(math.random(h.nb_vsteps)))
end

local function rnd_cv_out_llabel_for_haleseq(h)
  local out_label = ""
  if rnd() < 0.5 then
    return string.lower(mux_output_nb_to_name(h.nb_vsteps))
  else
    return output_nb_to_name(math.random(h.nb_vsteps))
  end
end

local function rnd_patch()
  tempty(STATE.links)

  add_link("norns_clock", "quantized_clock_global")

  for _, pd in ipairs(pulse_dividers) do
    params:set(pd.fqid.."_clock_div", math.random(#CLOCK_DIV_DENOMS))

    if rnd() < 0.25 then
      local haleseq_id = math.random(tab.count(haleseqs))
      local out_llabel = rnd_cv_out_llabel_for_haleseq(haleseqs[haleseq_id])
      add_link("haleseq_"..haleseq_id.."_"..out_llabel, "pulse_divider_1_clock_div")
    end
  end

  for i, h in ipairs(haleseqs) do
    local has_in_preset_cv_patched = false

    if i > 1 then
      if rnd() < 0.2 then
        -- patch from haleseq_1 to the others' preset
        local out_llabel = rnd_cv_out_llabel_for_haleseq(haleseqs[1])

        add_link("haleseq_1_"..out_llabel, "haleseq_"..i.."_preset")
        has_in_preset_cv_patched = true
      end
    end

    -- clock
    if not has_in_preset_cv_patched or rnd() < 0.1 then
      params:set("clock_div_"..h.id, math.random(#CLOCK_DIVS-1)+1)
    else
      params:set("clock_div_"..h.id, tab.key(CLOCK_DIVS, 'off'))

      local pd_id = math.random(tab.count(pulse_dividers))
      local pd = pulse_dividers[pd_id]
      add_link(pd.fqid.."_"..pd.divs[math.random(tab.count(pd.divs))], "haleseq_"..i.."_clock")
    end

    -- vclock
    if rnd() < 0.5 then
      params:set("vclock_div_"..h.id, math.random(#CLOCK_DIVS-1)+1)
    else
      params:set("vclock_div_"..h.id, tab.key(CLOCK_DIVS, 'off'))

      local pd_id = math.random(tab.count(pulse_dividers))
      local pd = pulse_dividers[pd_id]
      add_link(pd.fqid.."_"..pd.divs[math.random(tab.count(pd.divs))], "haleseq_"..i.."_vclock")
    end
  end

  local assigned_outs = {}
  for i, _output in ipairs(outputs) do
    if i <= 2 then
      add_link("haleseq_"..i.."_abcd", "output_"..i)
    else
      local haleseq_id = math.random(tab.count(haleseqs))
      local cv_llabel = rnd_std_cv_out_llabel_for_haleseq(haleseqs[haleseq_id])
      local out_label = "haleseq_"..haleseq_id.."_"..cv_llabel
      while tab.contains(assigned_outs, out_label) do
        haleseq_id = math.random(tab.count(haleseqs))
        cv_llabel = rnd_std_cv_out_llabel_for_haleseq(haleseqs[haleseq_id])
        out_label = "haleseq_"..haleseq_id.."_"..cv_llabel
      end

      table.insert(assigned_outs, out_label)
      add_link(out_label, "output_"..i)
    end
  end

  DEBUG = true
end

-- ------------------------------------------------------------------------
-- state

local s_lattice

local g = nil
local has_grid = false

local g_knob = nil
local g_btn = nil

function grid_connect_maybe(_g)
  if not has_grid then
    g = grid.connect()
    if g.device ~= nil then
      g.key = grid_key
      has_grid = true
    end
  end
end

function grid_remove_maybe(_g)
  if g.device.port == _g.port then
    -- current grid got deconnected
    has_grid = false
  end
end


local function get_current_haleseq()
  local curr_page = page_list[pages.index]
  for i=1,NB_HALESEQS do
    if curr_page == "haleseq "..i then
      return haleseqs[i]
    end
  end
end

-- ------------------------------------------------------------------------
-- state - sequence values

local is_resetting = false

local prev_step = nil
local step = 1
local vstep = 1

local last_step_t = 0
local last_vstep_t = 0
local last_preset_t = 0

local stages = {}
local seqvals = {}

local V_MAX = 1000
local V_NB_OCTAVES = 10
local V_TRIG = 500


-- ------------------------------------------------------------------------
-- playback

local last_enc_note_play_t = 0

function all_notes_off()
  for _, o in ipairs(outputs) do
    o:nb_note_off()
  end
end


-- ------------------------------------------------------------------------
-- sequence

local next_step = nil
local clock_acum = 0
local reverse = false
local hold = false

local next_vstep = nil
local vclock_acum = 0
local vreverse = false

local mclock_acum = 0
local last_mclock_tick_t = 0

is_doing_stuff = false

function mclock_tick(t, forced)
  if mclock_acum % (MCLOCK_DIVS / NB_BARS) == 0 then
    last_mclock_tick_t = os.clock()
  end
  if not forced then
    mclock_acum = mclock_acum + 1
  end

  if is_doing_stuff then
    return
  end

  is_doing_stuff = true

  fire_and_propagate("norns_clock", V_MAX/2)
  fire_and_propagate("norns_clock", 0)

  is_doing_stuff = false
end


-- ------------------------------------------------------------------------
-- script lifecycle

local redraw_clock
local grid_redraw_clock

function get_first_nb_voice_midi_param_option_id(voice_id)
  local nb_voices = params:lookup_param("nb_voice_"..voice_id).options
  for i, v in ipairs(nb_voices) do
    if util.string_starts(v, "midi: ") and not (util.string_starts(v, "midi: nb ") or util.string_starts(v, "midi: virtual ")) then
      return i
    end
  end
end

local PATCH_CONF_EXT = ".washipatch"

params.action_read = function(filename, name, pset_number)
  local conf = dofile(filename..PATCH_CONF_EXT)

  for i, hc in ipairs(conf.haleseqs) do
    if haleseqs[i] ~= nil then
      treplace(haleseqs[i].seqvals, hc)
    end
  end

  treplace(links, conf.links)
end

params.action_write = function(filename, name, pset_number)
  local conf = {}

  conf.version = "0.1"

  conf.haleseqs = {}
  for i, h in ipairs(haleseqs) do
	conf.haleseqs[i] = h.seqvals
  end

  conf.links = links

  local confStr = inspect(conf)
  local f, err = io.open(filename..PATCH_CONF_EXT, "wb")
  if err then
    print("FAILED TO WRITE "..filename..PATCH_CONF_EXT)
    return
  end
  f:write("return "..confStr)
  io.close(f)
end

params.action_delete = function(filename, name, pset_number)
  os.execute("rm -f" .. filename .. PATCH_CONF_EXT)
end


local function init_patch()
  add_link("norns_clock", "quantized_clock_global")

  -- add_link("haleseq_2_abcd", "pulse_divider_1_clock_div")
  add_link("pulse_divider_1_3", "haleseq_2_vclock")

  -- NB: creates links bewteen `quantized_clock_global` & `haleseq_1`
  params:set("clock_div_"..1, tab.key(CLOCK_DIVS, '1/16'))
  params:set("vclock_div_"..1, tab.key(CLOCK_DIVS, '1/2'))
  add_link("pulse_divider_1_7", "haleseq_1_vclock")

  add_link("pulse_divider_1_3", "haleseq_2_vclock")

  -- add_link("haleseq_1_a", "haleseq_2_clock")
  add_link("haleseq_1_abcd", "haleseq_2_preset")

  -- add_link("haleseq_1_abcd", "lfos_1_rate")
  -- add_link("haleseq_2_a", "lfos_1_shape")
  -- add_link("lfos_1_1", "haleseq_2_preset")

  add_link("haleseq_1_abcd", "output_1")
  add_link("haleseq_2_abcd", "output_2")
  add_link("haleseq_1_a", "output_3")
  add_link("haleseq_2_a", "output_4")
  add_link("haleseq_2_b", "output_5")

  -- add_link("rvg_1_smooth", "lfo_bank_2_rate")
  -- add_link("lfo_bank_2_1", "output_2_vel")
  -- add_link("lfo_bank_2_4", "output_2_dur")

  add_link("lfo_bank_2_3", "output_2_mod")
end

function init()
  screen.aa(0)
  screen.line_width(1)

  s_lattice = lattice:new{}

  grid_connect_maybe()

  nb.voice_count = NB_OUTS
  nb:init()

  local scope = Scope.new('popup', STATE)
  STATE.scope = scope

  -- stages[5].o = 2

  -- --------------------------------
  -- global params

  params:add_trigger("rnd_all", "Randomize All")
  params:set_action("rnd_all",
                    function(_v)
                      params:set("rnd_seq_root", math.random(#musicutil.NOTE_NAMES))
                      params:set("rnd_seqs", 1)
                      rnd_patch()
                    end
  )

  params:add_trigger("rnd_patch", "Randomize Patch")
  params:set_action("rnd_patch",
                    function(_v)
                      rnd_patch()
                    end
  )

  params:add_trigger("rnd_seqs", "Randomize Seqs")
  params:set_action("rnd_seqs",
                    function(_v)
                      for _, h in ipairs(haleseqs) do
                        local fqid = h.fqid
                        params:set(fqid.."_rnd_seqs", 1)
                      end
                    end
  )


  local RND_MODES = {'Scale', 'Blip Bloop'}
  params:add_option("rnd_seq_mode", "Rnd Mode", RND_MODES, tab.key(RND_MODES, 'Scale'))
  params:set_action("rnd_seq_mode",
                    function(v)
                      if RND_MODES[v] == 'Scale' then
                        params:show("rnd_seq_root")
                      else
                        params:hide("rnd_seq_root")
                      end
                      _menu.rebuild_params()
                    end
  )
  params:add_option("rnd_seq_root", "Rnd Scale", musicutil.NOTE_NAMES, tab.key(musicutil.NOTE_NAMES, 'C'))

  params:add{type = "number", id = "pulse_width", name = "Pulse Width", min = 1, max = 100, default = 10}


  -- --------------------------------
  -- modules

  params:add_separator("modules", "modules")

  norns_clock = NornsClock.init(STATE,
                                tab.key(page_list, 'clock'), 2, 1)
  quantized_clocks = QuantizedClock.init("global", STATE, MCLOCK_DIVS, CLOCK_DIV_DENOMS,
                                         tab.key(page_list, 'clock'), 4, 1)

  pulse_dividers[1] = PulseDivider.init(1, STATE, nil,
                                        tab.key(page_list, 'clock'), 9, 1)

  rvgs[1] = Rvg.init(1, STATE,
                     tab.key(page_list, 'mod'), 2, 1)
  lfos[1] = LfoBank.init(1, STATE,
                         LFO_PHASES, {},
                         tab.key(page_list, 'mod'), 5, 1)
  local BRATIO = 10
  lfos[2] = LfoBank.init(2, STATE,
                         {0, 2, 7, 44, 58, 79, 122},
                         {37/BRATIO, 27/BRATIO, 6.51/BRATIO, 3/BRATIO, 1.52/BRATIO, 1.21/BRATIO, 1/BRATIO},
                         tab.key(page_list, 'mod'), 10, 1)

  for i=1,NB_HALESEQS do
    local h = Haleseq.init(i, STATE, NB_STEPS, NB_VSTEPS,
                           tab.key(page_list, 'haleseq '..i), 0, 0)
    haleseqs[i] = h
  end

  params:add_separator("outputs", "outputs")

  local ox = 1
  for o=1,NB_OUTS do
    local label = ""..o
    if vs ~= 1 and mod1(o,2) == 1 then
      ox = ox + 4
    end
    local oy = mod1(o,2) * 3
    outputs[o] = Output.init(label, STATE,
                             tab.key(page_list, 'outputs'), ox, oy)
  end

  init_patch()

  -- --------------------------------

  nb:add_player_params()

  -- FIXME: can't be set at init like that...
  -- NB: bind multiplexed voice to first midi out if found
  -- local vs_mux = NB_VSTEPS + 1
  -- local p_id = get_first_nb_voice_midi_param_option_id(vs_mux)
  -- if p_id ~= nil then
  --   params:set("nb_voice_"..vs_mux, p_id)
  -- end

  -- NB: randomize seqs
  params:set("rnd_seqs", 1)

  redraw_clock = clock.run(
    function()
      local step_s = 1 / FPS
      while true do
        clock.sleep(step_s)
        redraw()
      end
  end)
  grid_redraw_clock = clock.run(
    function()
      local step_s = 1 / GRID_FPS
      while true do
        clock.sleep(step_s)
        grid_redraw()
      end
  end)

  local sprocket = s_lattice:new_sprocket{
    action = mclock_tick,
    division = 1/MCLOCK_DIVS,
    enabled = true
  }
  s_lattice:start()
end

function cleanup()
  all_notes_off()

  clock.cancel(redraw_clock)
  clock.cancel(grid_redraw_clock)

  STATE.scope:cleanup()
  for _, rvg in ipairs(rvgs) do
    rvg:cleanup()
  end
  for _, lfo in ipairs(lfos) do
    lfo:cleanup()
  end

  s_lattice:destroy()
end


-- ------------------------------------------------------------------------
-- grid

local G_Y_PRESS = 8
local G_Y_KNOB = 2

function grid_redraw()
  g:all(0)

  local curr_page = page_list[pages.index]

  if curr_page == 'clock' then
    norns_clock:grid_redraw(g, quantized_clocks.mclock_mult_trig)
    quantized_clocks:grid_redraw(g)
    pulse_dividers[1]:grid_redraw(g)
  elseif curr_page == 'mod' then
    rvgs[1]:grid_redraw(g)
    lfos[1]:grid_redraw(g)
    lfos[2]:grid_redraw(g)
  elseif curr_page == 'outputs' then
    for _, o in ipairs(outputs) do
      o:grid_redraw(g)
    end
  else
    local h = get_current_haleseq()
    if h ~= nil then
      h:grid_redraw(g)
    end
  end

  g:refresh()
end

function grid_key(x, y, z)
  local curr_page = pages.index
  local screen_coord = curr_page.."."..paperface.grid_x_to_panel_x(x).."."..paperface.grid_y_to_panel_y(y)

  local nana = STATE.coords_to_nana[screen_coord]
  if nana ~= nil and nana.kind == 'out' then
    if (z >= 1) then
      STATE.scope:assoc(nana)
    else
      STATE.scope:clear()
    end
    -- return
  end


  local h = get_current_haleseq()
  if h ~= nil then
    h:grid_key(x, y, z)
  end
end

-- ------------------------------------------------------------------------
-- controls

local k1 = false
local k3 = false

function key(n, v)

  -- single modifiers
  if n == 1 then
    k1 = (v == 1)
  end
  if n == 3 then
    k3 = (v == 1)
  end

  if k1 and k3 then
    params:set("rnd_all", 1)
  end
end

function enc(n, d)
  local curr_page = page_list[pages.index]

  if curr_page == "clock" then
    if n == 2 then
      local sign = math.floor(d/math.abs(d))
      params:set("pulse_divider_1_clock_div", params:get("pulse_divider_1_clock_div") + sign)
      return
    end
  end

  local h = get_current_haleseq()
  if h ~= nil then
    local id = h:get_id()

    if h:is_editing_knob() then
      h:knob(n, d)

      -- retrig note to get a preview
      if (math.abs(os.clock() - last_enc_note_play_t) >= PULSE_T) then
        local vs = h:knob_vs()
        local volts = h:knob_volts()

        local target_in_labels = links[h.cv_outs[vs].id]
        if target_in_labels ~= nil then
          for _, in_label in ipairs(target_in_labels) do
            if util.string_starts(in_label, "output_") then
              local o = ins[in_label].parent
              o:nb_play_volts(volts)
            end
          end
        end

        local target_in_labels_mux = links[h.cv_outs[h.nb_vsteps+1].id]
        if target_in_labels_mux ~= nil then
          for _, in_label in ipairs(target_in_labels_mux) do
            if util.string_starts(in_label, "output_") then
              local o = ins[in_label].parent
              o:nb_play_volts(volts)
            end
          end
        end

        last_enc_note_play_t = os.clock()
      end
      return
    end

    if n == 2 then
      local sign = math.floor(d/math.abs(d))
      params:set("clock_div_"..id, params:get("clock_div_"..id) + sign)
      return
    end
    if n == 3 then
      local sign = math.floor(d/math.abs(d))
      params:set("vclock_div_"..id, params:get("vclock_div_"..id) + sign)
      return
    end

  end

  if n == 1 then
    -- params:set("clock_tempo", params:get("clock_tempo") + d)
    STATE.scope:clear()
    pages:set_index_delta(d, false)
    return
  end
end


-- ------------------------------------------------------------------------
-- screen

function redraw_clock_screen()

  -- NB: `norns_clock` & `quantized_clocks` act a single module
  -- here we're faking the display of the' link bewteen the 2 as a clock multiplier while it's in fact implemented as a clock divider
  -- hence why we're manually drawing the links and showing the trigger ins independently of the real inputs' ins.
  quantized_clocks:redraw()
  norns_clock:redraw(quantized_clocks.mclock_mult_trig)
  if quantized_clocks.mclock_mult_trig then
    paperface.draw_link(norns_clock.x, norns_clock.y, 1, quantized_clocks.x, quantized_clocks.y, 1, 1)
  end

  pulse_dividers[1]:redraw()
end

function redraw()
  screen.clear()

  pages:redraw()

  screen.level(15)

  local curr_page = page_list[pages.index]
  if curr_page == 'clock' then
    redraw_clock_screen()
  elseif curr_page == 'mod' then
    rvgs[1]:redraw()
    lfos[1]:redraw()
    for i, phase in ipairs(LFO_PHASES) do
      if tab.contains({0, 90, 180, 270}, phase) then
        local x = paperface.panel_grid_to_screen_x(lfos[1].x + 1) + SCREEN_STAGE_W + 2
        local y = paperface.panel_grid_to_screen_y(i) + SCREEN_STAGE_W - 2
        screen.move(x, y)
        screen.text(phase.."°")
      end
    end
    lfos[2]:redraw()
    local x = paperface.panel_grid_to_screen_x(lfos[2].x + 1) + SCREEN_STAGE_W + 2
    local yf = paperface.panel_grid_to_screen_y(1) + SCREEN_STAGE_W - 2
    local ys = paperface.panel_grid_to_screen_y(7) + SCREEN_STAGE_W - 2
    screen.move(x, yf)
    screen.text("f")
    screen.move(x, ys)
    screen.text("s")
  elseif curr_page == 'outputs' then
    for _, o in ipairs(outputs) do
      o:redraw()
    end
  else
    local h = get_current_haleseq()
    if h ~= nil then
      h:redraw()
    end
  end

  if STATE.scope:is_on() then
    STATE.scope:redraw(SCREEN_W/4, SCREEN_H/4, SCREEN_W/2, SCREEN_H/2)
  end

  if STATE.selected_out == nil then
    paperface.redraw_active_links(outs, ins, pages.index)
  else
    paperface.redraw_links(outs, links[patching.ins_from_labels(ins, links[STATE.selected_out])], pages.index)
  end

  screen.update()
end
