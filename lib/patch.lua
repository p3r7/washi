-- washi. patch

local patch = {}


-- ------------------------------------------------------------------------
-- deps

local patching = include("washi/lib/patching")

include("washi/lib/core")


-- ------------------------------------------------------------------------
-- helpers

local function add_link(STATE, from_id, to_id)
  patching.add_link(STATE.links, from_id, to_id)
end


-- ------------------------------------------------------------------------
-- empty patch

function patch.clear(STATE)
  tempty(STATE.links)
  tempty(STATE.link_props)
  STATE.selected_nana = nil
  STATE.selected_link = nil

  patching.clear_all_ins(STATE.ins)

  -- NB: clear the param value so that calls to `patch.init` would detect a change
  params:set("clock_div_"..1, tab.key(CLOCK_DIVS, 'off'))
  params:set("vclock_div_"..1, tab.key(CLOCK_DIVS, 'off'))

  add_link(STATE, "norns_clock", "quantized_clock_global")
end


-- ------------------------------------------------------------------------
-- init patch

function patch.init(STATE)
  print("init patch!")

  patch.clear(STATE)

  -- add_link(STATE, "haleseq_2_abcd", "pulse_divider_1_clock_div")
  add_link(STATE, "pulse_divider_1_3", "haleseq_2_vclock")

  -- NB: creates links bewteen `quantized_clock_global` & `haleseq_1`
  params:set("clock_div_"..1, tab.key(CLOCK_DIVS, '1/16'))
  params:set("vclock_div_"..1, tab.key(CLOCK_DIVS, '1/2'))

  add_link(STATE, "pulse_divider_1_7", "haleseq_1_vclock")
  add_link(STATE, "pulse_divider_1_3", "haleseq_2_vclock")

  -- add_link(STATE, "haleseq_1_a", "haleseq_2_clock")
  add_link(STATE, "haleseq_1_abcd", "haleseq_2_preset")

  -- add_link(STATE, "lfo_bank_1_1", "haleseq_2_preset")
  -- add_link(STATE, "rvg_1_smooth", "haleseq_2_preset")
  -- add_link(STATE, "lfo_bank_2_5", "haleseq_2_preset")
  -- add_link(STATE, "rvg_1_stepped", "haleseq_2_preset")

  -- add_link(STATE, "haleseq_1_abcd", "lfos_1_rate")
  -- add_link(STATE, "haleseq_2_a", "lfos_1_shape")

  add_link(STATE, "haleseq_1_abcd", "output_1")
  add_link(STATE, "haleseq_2_abcd", "output_2")
  add_link(STATE, "haleseq_1_a", "output_3")
  add_link(STATE, "haleseq_2_a", "output_4")
  add_link(STATE, "haleseq_2_b", "output_5")


  -- FIXME: self-patching doesn't work
  -- add_link(STATE, "haleseq_1_stage_5", "haleseq_1_stage_3")

  -- FIXME: x-patching doesn't work
  -- add_link(STATE, "haleseq_1_stage_5", "haleseq_2_stage_3") -- works
  -- add_link(STATE, "pulse_divider_1_3", "haleseq_2_clock")
  -- add_link(STATE, "haleseq_1_stage_5", "haleseq_2_stage_3") -- does not

  -- add_link(STATE, "rvg_1_smooth", "lfo_bank_2_rate")
  -- add_link(STATE, "lfo_bank_2_1", "output_2_vel")
  -- add_link(STATE, "lfo_bank_2_4", "output_2_dur")

  add_link(STATE, "lfo_bank_2_3", "output_2_mod")
end


-- ------------------------------------------------------------------------
-- random patches

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

local function rnd_mod_module(mod_modules)
  local nb_module_types = tab.count(mod_modules)
  local module_type = math.random(nb_module_types)

  local nb_modules_of_type = tab.count(mod_modules[module_type])
  return mod_modules[module_type][math.random(nb_modules_of_type)]
 end

local function rnd_other_mod_module(m, mod_modules)
  local m2 = rnd_mod_module(mod_modules)
  if m ~= nil then
    while m2.fqid == m.fqid do
      m2 = rnd_mod_module(mod_modules)
    end
  end
  return m2
end

local function rnd_mod_out_for_module(m2)
  if m2.kind == 'haleseq' then
    if rnd() < 0.5 then
      return m2.cv_outs[m2.nb_vsteps + 1] -- mux out
    else
      return m2.cv_outs[math.random(m2.nb_vsteps)]
    end
  elseif m2.kind == 'lfo_bank' then
    return m2.wave_outs[math.random(tab.count(m2.wave_outs))]
  elseif m2.kind == 'rvg' then
    if rnd() < 0.50 then
      return m2.o_smooth
    else
      return m2.o_stepped
    end
  end
end

local function rnd_mod_out(mod_modules)
  local m = rnd_mod_module(mod_modules)
  return rnd_mod_out_for_module(m)
end

local function rnd_mod_out_other_module(m, mod_modules)
  local m2 = rnd_other_mod_module(m, mod_modules)
  return rnd_mod_out_for_module(m2)
end

local function rnd_out_other_module(m)
  local nb_outs = tab.count(outs)
  local out_labels = tkeys(outs)
  local ol = out_labels[math.random(nb_outs)]
  local o = outs[ol]
  while o.id == 'norns_clock' or o.parent.fqid == m.fqid do
    ol = out_labels[math.random(nb_outs)]
    o = outs[ol]
  end
  return o
end


function patch.random(STATE, pulse_dividers, rvgs, lfos, haleseqs, outputs)
  print("random patch!")

  patch.clear(STATE)

  local mod_modules = {rvgs, lfos, haleseqs}

  for _, pd in ipairs(pulse_dividers) do
    params:set(pd.fqid.."_clock_div", math.random(#CLOCK_DIV_DENOMS))

    if rnd() < 0.25 then
      local from_out = rnd_mod_out_other_module(pd, mod_modules)
      add_link(STATE, from_out.id, pd.fqid.."_clock_div")
    end
  end

  for _, rvg in ipairs(rvgs) do
    if rnd() < 0.25 then
      local from_out = rnd_mod_out_other_module(rvg, mod_modules)
      add_link(STATE, from_out.id, rvg.fqid.."_rate")
    end
  end

  for _, lfo in ipairs(lfos) do
    if rnd() < 0.1 then
      local from_out = rnd_mod_out_other_module(lfo, mod_modules)
      add_link(STATE, from_out.id, lfo.fqid.."_rate")
    end
    if rnd() < 0.1 then
      local from_out = rnd_mod_out_other_module(lfo, mod_modules)
      add_link(STATE, from_out.id, lfo.fqid.."_shape")
    end
    if rnd() < 0.1 then
      local from_out = rnd_mod_out_other_module(lfo, mod_modules)
      add_link(STATE, from_out.id, lfo.fqid.."_hold")
    end
  end

  for i, h in ipairs(haleseqs) do
    local has_in_preset_cv_patched = ((i == 1) and rnd() < 0.01 or rnd() < 0.5)

    if has_in_preset_cv_patched then
      -- patch from haleseq_1 to the others' preset
      local from_out = rnd_mod_out_other_module(h, mod_modules)

      add_link(STATE, from_out.id, "haleseq_"..i.."_preset")
    end

    -- clock
    if not has_in_preset_cv_patched or rnd() < 0.1 then
      params:set("clock_div_"..h.id, math.random(#CLOCK_DIVS-1)+1)
    else
      params:set("clock_div_"..h.id, tab.key(CLOCK_DIVS, 'off'))

      local pd_id = math.random(tab.count(pulse_dividers))
      local pd = pulse_dividers[pd_id]
      add_link(STATE, pd.fqid.."_"..pd.divs[math.random(tab.count(pd.divs))], h.fqid.."_clock")
    end

    -- vclock
    if rnd() < 0.5 then
      params:set("vclock_div_"..h.id, math.random(#CLOCK_DIVS-1)+1)
    else
      params:set("vclock_div_"..h.id, tab.key(CLOCK_DIVS, 'off'))

      local pd_id = math.random(tab.count(pulse_dividers))
      local pd = pulse_dividers[pd_id]
      add_link(STATE, pd.fqid.."_"..pd.divs[math.random(tab.count(pd.divs))], h.fqid.."_vclock")
    end

    if rnd() < 0.1 then
    -- if true then
      local ol = rnd_out_other_module(h).id
      print(ol .. " -> " .. h.fqid.."_reset")
      add_link(STATE, ol, h.fqid.."_reset")
    end
    if rnd() < 0.1 then
      add_link(STATE, rnd_out_other_module(h).id, h.fqid.."_vreset")
    end
    if rnd() < 0.1 then
      add_link(STATE, rnd_out_other_module(h).id, h.fqid.."_preset_reset")
    end
    if rnd() < 0.8 then
      add_link(STATE, rnd_out_other_module(h).id, h.fqid.."_hold")
    end
    if rnd() < 0.1 then
      add_link(STATE, rnd_out_other_module(h).id, h.fqid.."_reverse")
    end

    if params:get(h.fqid.."_preset") > (3 * h.nb_steps / 4) then
      params:set(h.fqid.."_preset", math.random(round(3 * h.nb_steps / 4)))
    end
  end

  local assigned_outs = {}
  for i, output in ipairs(outputs) do
    if i <= 2 then
      add_link(STATE, "haleseq_"..i.."_abcd", "output_"..i)
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
      add_link(STATE, out_label, "output_"..i)
    end

    if rnd() < 0.1 then
      add_link(STATE, rnd_mod_out(mod_modules).id, output.fqid.."_dur")
    end
    if rnd() < 0.1 then
      add_link(STATE, rnd_mod_out(mod_modules).id, output.fqid.."_vel")
    end
    if i <= 2 or rnd() < 0.2 then
      add_link(STATE, rnd_mod_out(mod_modules).id, output.fqid.."_mod")
    end
  end

  -- DEBUG = true
end


-- ------------------------------------------------------------------------

return patch
