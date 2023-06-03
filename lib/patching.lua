-- haleseq. patching


-- ------------------------------------------------------------------------
-- deps

include("haleseq/lib/core")


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

  -- simplify links table
  if did_something and tab.count(links[o]) == 0 then
    links[o] = nil
  end
end


-- ------------------------------------------------------------------------
-- EVAL - SINGLE MODULE

function patching.module_clear_unlinked_ins(outs, ins, links, m)
  if m.ins == nil then
    return
  end
  for _, in_label in ipairs(m.ins) do
    local i = ins[in_label]
    if i ~= nil then
      for out_label, _v in pairs(i.incoming_vals) do
        if outs[out_label] == nil or links[out_label] == nil or not tab.contains(links[out_label], in_label) then
          i.incoming_vals[out_label] = nil
        end
      end
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
    return modules, module_out_links
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
        patching.exec_plan(outs, ins, links, next_in_label, modules, module_triggered_ins, module_out_links, level+1)
      end
    end

    ::NEXT_OUT::
  end
  return modules, module_triggered_ins, module_out_links
end


-- ... then in this 2nd function, loop over ordered (by level) sequence of triggered_modules, process input vals (`module:process_ins`) & set next module's vals (`target_input:update`)
function patching.fire_and_propagate(outs, ins, links,
                                     in_label, initial_v)

  if initial_v == nil then initial_v = V_MAX/2 end

  dbg("----------")
  dbg("PATCH LAYOUT")
  dbg("----------")
  local fired_modules, fired_ins, link_map = patching.exec_plan(outs, ins, links, in_label)

  dbg("----------")
  dbg("TRIGGERED MODULES")
  dbg("----------")

  for level, modules in ipairs(fired_modules) do
    for _, m in ipairs(modules) do
      patching.module_clear_unlinked_ins(outs, ins, links, m)
    end
  end

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
        local v = from.v

        dbg(from.id .. " -> " .. to.id .. ": " .. v, level-1)

        to:register(from.id, v)
      end

      :: NEXT_MODULE ::
    end
  end

  -- for _, i in ipairs(fired_ins) do
  --   dbg(i.id)

  --   local parent = i.parent
  --   parent:process_ins()
  -- end

  dbg("----------")
  DEBUG = false

end


-- ------------------------------------------------------------------------

return patching
