

local kbdutil = {}


-- ------------------------------------------------------------------------
-- modifiers

function kbdutil.isMod(modifiers, mod)
  return (#modifiers == 1 and modifiers[1] == mod)
end

function kbdutil.isCtrl(modifiers)
  return kbdutil.isMod(modifiers, "ctrl")
end

function kbdutil.isAlt(modifiers)
  return kbdutil.isMod(modifiers, "alt")
end

function kbdutil.isShift(modifiers)
  return kbdutil.isMod(modifiers, "shift")
end


-- ------------------------------------------------------------------------

return kbdutil
