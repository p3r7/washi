

-- ------------------------------------------------------------------------
-- clock

MCLOCK_DIVS = 64

CLOCK_DIV_DENOMS = {1, 2, 4, 8, 16, 32, 64}
CLOCK_DIVS = {'off', '1/1', '1/2', '1/4', '1/8', '1/16', '1/32', '1/64'}

PULSE_T = 0.02 --FIXME: don't use os.clock() but a lattice clock for stable gate beahvior


-- ------------------------------------------------------------------------
-- sequenced values

V_MAX = 1000


-- ------------------------------------------------------------------------
-- prog / seq

NB_STEPS = 8
NB_VSTEPS = 4


-- ------------------------------------------------------------------------
-- screen - general

SCREEN_W = 128
SCREEN_H = 64


-- ------------------------------------------------------------------------
-- screen - paperface

SCREEN_STAGE_W = 9
-- local SCREEN_STAGE_W = 15
-- local SCREEN_STAGE_Y_OFFSET = 12
SCREEN_STAGE_Y_OFFSET = 1

SCREEN_LEVEL_LABEL = 1
SCREEN_LEVEL_LABEL_SPE = 5
