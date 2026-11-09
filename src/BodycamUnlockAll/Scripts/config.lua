--[[
    Bodycam Unlock All - user configuration
    ---------------------------------------
    Edit the values below, save the file, and restart Bodycam.
    Delete this file to restore the defaults.
]]

return {
    -- Seconds to wait after the shop data table is found before reading the
    -- inventory. Steam needs a moment to load the player's inventory at
    -- startup; 15 seconds is enough on the tested build.
    WARMUP_SECONDS = 15,

    -- Give up waiting for the game / data table after this many seconds.
    STARTUP_TIMEOUT_SECONDS = 180,

    -- Extra GrantPromoItems attempts if items are still locked afterwards.
    -- 3 means: 1 initial attempt + up to 3 retries, 30 seconds apart.
    RETRIES = 3,
    RETRY_DELAY_SECONDS = 30,

    -- If GrantPromoItems does not unlock everything, try AddPromoItems with
    -- the game's full item-definition catalog as a fallback.
    FALLBACK_ADDPROMOS = true,

    -- Always call GrantPromoItems, even when everything is already owned.
    -- Leave this false for normal use (it exists for testing).
    FORCE_GRANT = false,

    -- Write unlock_status.txt / unlock_log.txt next to the scripts.
    WRITE_STATUS = true,

    -- Rows checked per tick while verifying ownership. Lower values are
    -- gentler on the game thread but take longer.
    VERIFY_CHUNK = 250,

    -- Milliseconds between ticks.
    TICK_MS = 800,
}
