-- washi. patching


-- ------------------------------------------------------------------------
-- deps

include("washi/lib/core")
include("washi/lib/consts")


-- ------------------------------------------------------------------------

local patching = {}


-- ------------------------------------------------------------------------
-- EDIT

function patching.add_link(links, o, i)
  if links[o] == nil then
    links[o] = {}
  end
  table.insert(links[o], i)
end


function patching.remove_link(links, o, i)
  if links[o] == nil then
    return
  end

  local did_something = false

  -- remove eventually
  for i_i, v in ipairs(links[o]) do
    if v == i then
      table.remove(links[o], i_i)
      did_something = true
      -- break
    end
  end

  if did_something then
    -- simplify links table
    if tab.count(links[o]) == 0 then
      links[o] = nil
    end

    return A_REMOVED
  end
end

function patching.are_linked(links, o_id, i_id)
  return (links[o_id] ~= nil and tab.contains(links[o_id], i_id))
end

function patching.toggle_link(links, o, i)
  if patching.are_linked(links, o, i) then
    patching.remove_link(links, o, i)
    return A_REMOVED
  else
    patching.add_link(links, o, i)
    return A_ADDED
  end
end

function patching.get_link_props(link_props, from_id, to_id)
  if link_props[from_id] ~= nil and link_props[from_id][to_id] ~= nil then
    return link_props[from_id][to_id]
  end
end

function patching.get_or_init_link_props(link_props, from_id, to_id)
  local lprops = patching.get_link_props(link_props, from_id, to_id)
  if lprops ~= nil then
    return lprops
  end

  if link_props[from_id] == nil then link_props[from_id] = {} end
  link_props[from_id][to_id] = {
    scaling = 1.0,
    offset = 0.0,
  }
  return link_props[from_id][to_id]
end

function patching.get_link_v(link_props, from, to)
  local v = from.v
  local lprops = patching.get_link_props(link_props, from.id, to.id)
  if lprops ~= nil then
    if lprops.scaling < 0 then
      v = V_MAX + v * lprops.scaling
    else
      v = v * lprops.scaling
    end
    v = v + lprops.offset
  end
  return v
end


-- ------------------------------------------------------------------------
-- LOOKUP

function patching.is_known_in(ins, i_id)
  return (ins[i_id] ~= nil)
end

function patching.is_known_out(outs, o_id)
  return (outs[o_id] ~= nil)
end

function patching.is_in(nana)
  return (nana.kind == 'in' or nana.kind == 'comparator')
end

function patching.is_out(nana)
  return (nana.kind == 'out' or nana.kind == 'cv_out')
end

function patching.ins_from_labels(ins, in_labels)
  local res = {}

  if in_labels ~= nil then
    for _, in_label in ipairs(in_labels) do
      local i = ins[in_label]
      if i ~= nil then
        table.insert(res, i)
      end
    end
  end

  return res
end


-- ------------------------------------------------------------------------
-- EVAL - INPUT

function patching.input_vals_from_real(incoming_vals)
  local filtered_vals = {}
  for src_out_label, v in pairs(incoming_vals) do
    if src_out_label then
      if src_out_label ~= "GLOBAL" then
        filtered_vals[src_out_label] = v
      end
    end
  end
  return filtered_vals
end

function patching.input_compute_val(compute_mode, incoming_vals)
  -- NB: this one is a special "override" v
  local special_v = incoming_vals["GLOBAL"]
  local in_vals = incoming_vals
  if special_v ~= nil and special_v == 0 then
    in_vals = patching.input_vals_from_real(incoming_vals)
  end

  if compute_mode == V_COMPUTE_MODE_SUM then
    return mean(in_vals)
  elseif compute_mode == V_COMPUTE_MODE_MEAN then
    return sum(in_vals)
  elseif compute_mode == V_COMPUTE_MODE_AND then
    local min_v = math.min(tunpack(in_vals))
  elseif compute_mode == V_COMPUTE_MODE_OR then
    return math.max(tunpack(in_vals))
  end
end


-- ------------------------------------------------------------------------
-- EVAL - SINGLE MODULE

function patching.clear_all_ins(ins)
  for _, i in pairs(ins) do
    tempty(i.incoming_vals)
    i.v = 0
    if i.kind == 'comparator' then
      i.status = 0
      -- i.triggered = false
    end
  end
end

function patching.clear_all_unlinked_ins(outs, ins, links)
  for in_label, i in pairs(ins) do
    if i ~= nil then
      for out_label, _v in pairs(i.incoming_vals) do
        if out_label ~= 'GLOBAL'
          and not (patching.is_known_out(outs, out_label)
                   and patching.are_linked(links, out_label, in_label)) then
          -- print("clearing link " .. out_label .. " -> " .. in_label)
          i.incoming_vals[out_label] = nil
        end
      end
      i:update()
    end
  end
end

function patching.module_update_all_ins(m)
  if m.ins == nil then
    return
  end
  for _, in_label in ipairs(m.ins) do
    local i = ins[in_label]
    if i ~= nil then
      i:update()
    end
  end
end

-- REVIEW: remove?
-- initial plan was to use to selectively update in values
-- but not necessary since using a map for `incoming_vals`
function patching.module_update_some_ins(m, ins_list)
  if m.ins == nil then
    return
  end
  for _, in_label in ipairs(m.ins) do
    local i = ins[in_label]
    if i ~= nil and tab.contains(ins_list, i) then
      i:update()
    end
  end
end


-- ------------------------------------------------------------------------
-- EVAL - TREE

-- the trick is to not fire any value in the propagate phase but only retrieve the execution plan (map of triggered_module => outbound_links)
-- returned as 2 vals as maps are not ordered in lua
-- ...
function patching.exec_plan(outs, ins, links, in_label,
                            modules, module_triggered_ins, module_out_links, level)
  if modules == nil then modules = {} end
  if module_triggered_ins == nil then module_triggered_ins = {} end
  if module_out_links == nil then module_out_links = {} end
  if level == nil then level = 1 end
  if modules[level] == nil then modules[level] = {} end

  dbg(in_label, level-1)

  local curr_in = ins[in_label]
  if curr_in == nil then
    dbg("!!! in '"..in_label.."' not found", level)
    return modules, module_triggered_ins, module_out_links
  end

  local curr_module = curr_in.parent

  -- anti-feedback mechanism (prevent infinite loops)
  for l, level_mods in ipairs(modules) do
    if l == level then
      break
    end
    if tab.contains(level_mods, curr_module) then
      dbg("!!! in '"..in_label.."' already triggered at level "..l..". cutting feedback loop.")
      return modules, module_triggered_ins, module_out_links
    end
  end

  set_insert(modules[level], curr_module)
  if module_triggered_ins[curr_module] == nil then module_triggered_ins[curr_module] = {} end
  set_insert(module_triggered_ins[curr_module], curr_in)
  if module_out_links[curr_module] == nil then module_out_links[curr_module] = {} end

  local curr_out_labels = curr_module.outs
  if curr_out_labels == nil or tab.count(curr_out_labels) == 0 then -- is at termination module
    -- dbg("!!! at termination branch !!!")
    return modules, module_triggered_ins, module_out_links
  end
  for _, curr_out_label in ipairs(curr_out_labels) do
    local curr_out = outs[curr_out_label]
    if curr_out == nil then
      dbg("!!! out '"..curr_out_label.."' not found", level)
      goto NEXT_OUT
    end

    local next_in_labels = links[curr_out_label]
    if next_in_labels ~= nil then
      for _, next_in_label in ipairs(next_in_labels) do
        dbg(curr_out_label .. " -> " .. next_in_label, level-1)
        if ins[next_in_label] ~= nil then
          set_insert_coord(module_out_links[curr_module], {curr_out, ins[next_in_label]})
        end
        patching.exec_plan(outs, ins, links, next_in_label,
                           modules, module_triggered_ins, module_out_links, level+1)
      end
    end

    ::NEXT_OUT::
  end
  return modules, module_triggered_ins, module_out_links
end
-- like `patching.exec_plan`, but takes multiple ins (at level #1) at once
function patching.exec_plan_mult(outs, ins, links, in_labels,
                                 modules, module_triggered_ins, module_out_links, level)
  if modules == nil then modules = {} end
  if module_triggered_ins == nil then module_triggered_ins = {} end
  if module_out_links == nil then module_out_links = {} end

  for _, in_label in ipairs(in_labels) do
    -- if ins[in_label] ~= nil then
    --   set_insert_coord(module_out_links[curr_module], {curr_out, ins[in_label]})
    -- end
    patching.exec_plan(outs, ins, links, in_label,
                       modules, module_triggered_ins, module_out_links)
  end

  return modules, module_triggered_ins, module_out_links
end

function patching.exec_plan_from_out(outs, ins, links, out_label)
  local curr_out = outs[out_label]
  if curr_out == nil then
    dbg("!!! out '"..out_label.."' not found", level)
  end

  local next_in_labels = links[out_label]

  if next_in_labels ~= nil then
    return patching.exec_plan_mult(outs, ins, links, next_in_labels)
  else
    return {}, {}, {}
  end
end


-- ... then in this 2nd function, loop over ordered (by level) sequence of triggered_modules, process input vals (`module:process_ins`) & set next module's vals (`target_input:update`)
function patching.fire_and_propagate(outs, ins, links, link_props,
                                     in_label, initial_v)

  if initial_v == nil then initial_v = V_MAX/2 end

  dbg("----------")
  dbg("PATCH LAYOUT")
  dbg("----------")
  local fired_modules, fired_ins, link_map = patching.exec_plan(outs, ins, links, in_label)

  dbg("----------")
  dbg("TRIGGERED MODULES")
  dbg("----------")

  -- patching.clear_all_unlinked_ins(outs, ins, links)

  for level, modules in ipairs(fired_modules) do
    for _, m in ipairs(modules) do

      dbg(m.fqid, level-1)

      if level == 1 then
        local from_label = "GLOBAL"
        local to = ins[in_label]
        dbg(from_label .. " -> " .. to.id .. ": " .. initial_v, level-1)
        to:register(from_label, initial_v)
      end

      patching.module_update_all_ins(m)
      m:process_ins()

      for _, outbound_link in ipairs(link_map[m]) do

        local from = outbound_link[1]
        local to = outbound_link[2]

        -- edge case of first module externally triggered (global norns clock)
        -- no real notion (for now) of input/output value handled by this module
        -- could be dealt w/ by using a superclock, but idk if i wann go there yet
        --
        -- FIXME: better way would be to define Trigger kind of Out that resets itself at the end of loop
        local v = patching.get_link_v(link_props, from, to)

        dbg(from.id .. " -> " .. to.id .. ": " .. v, level-1)

        to:register(from.id, v)
      end

      :: NEXT_MODULE ::
    end
  end

  dbg("----------")
  DEBUG = false

end

function patching.fire_and_propagate_from_out(outs, ins, links, link_props,
                                              out_label, initial_v)

  if initial_v == nil then initial_v = V_MAX/2 end

  dbg("----------")
  dbg("PATCH LAYOUT")
  dbg("----------")
  local fired_modules, fired_ins, link_map = patching.exec_plan_from_out(outs, ins, links, out_label)

  dbg("----------")
  dbg("TRIGGERED MODULES")
  dbg("----------")

  -- patching.clear_all_unlinked_ins(outs, ins, links)

  for level, modules in ipairs(fired_modules) do

    if level == 1 then
      local from_label = out_label
      local from = outs[out_label]
      local next_in_labels = links[out_label]

      for _, in_label in ipairs(next_in_labels) do
        local to = ins[in_label]
        if to == nil then
          print("WARNING: unknown in "..in_label)
        else
          local v = patching.get_link_v(link_props, from, to)
          dbg(from_label .. " -> " .. to.id .. ": " .. v, level-1)
          to:register(from_label, v)
        end
      end
    end

    for _, m in ipairs(modules) do

      dbg(m.fqid, level-1)

      patching.module_update_all_ins(m)
      m:process_ins()

      for _, outbound_link in ipairs(link_map[m]) do

        local from = outbound_link[1]
        local to = outbound_link[2]

        local v = patching.get_link_v(link_props, from, to)

        dbg(from.id .. " -> " .. to.id .. ": " .. v, level-1)

        to:register(from.id, v)
      end

      :: NEXT_MODULE ::
    end
  end

  dbg("----------")
  DEBUG = false

end




-- ------------------------------------------------------------------------

return patching
