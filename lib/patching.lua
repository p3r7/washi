-- haleseq. patching

-- ------------------------------------------------------------------------

local patching = {}


-- ------------------------------------------------------------------------

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

return patching
