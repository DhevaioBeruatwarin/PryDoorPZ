-- ============================================
-- PRY DOOR - CONFIGURATION
-- Version: 4.0.0
-- ============================================

PryDoor = PryDoor or {}
PryDoor.Config = {
    VERSION = "4.0.0",
    DEBUG = false,

    KEYBIND = Keyboard.KEY_GRAVE,

    TOOLS = {
        "Base.Crowbar",
        "Base.Axe",
        "Base.Screwdriver",
        "Base.Hammer",
        "Base.Wrench"
    },

    DURATION = {
        door = 150,
        garage = 180,
        window = 120,
        vehicle = 200
    },

    MAX_DISTANCE = 4,

    TOOL_BONUS = {
        ["Base.Crowbar"] = 0.20,
        ["Base.Axe"] = 0.10,
        ["Base.Screwdriver"] = 0.00,
        ["Base.Hammer"] = -0.05,
        ["Base.Wrench"] = -0.10
    },

    DIFFICULTY = {
        window = 0.90,
        door = 0.75,
        garage = 0.50,
        vehicle = 0.70
    },

    MIN_STRENGTH = {
        window = 2,
        door = 4,
        garage = 6,
        vehicle = 3
    },

    NOISE_RADIUS = {
        window = 8,
        door = 12,
        garage = 20,
        vehicle = 15
    },

    FAIL_CHANCE = {
        injury = 0.15
    },

    FATIGUE_COST = {
        window = 0.05,
        door = 0.08,
        garage = 0.12,
        vehicle = 0.10
    },

    MESSAGES = {
        NO_TOOL = "I need a prying tool!",
        NOTHING_LOCKED = "Nothing locked nearby.",
        TOO_WEAK = "I'm not strong enough!",
        TOO_TIRED = "Too tired to pry this.",
        SUCCESS = "Got it open!",
        FAILED = "It didn't work!",
        INJURED = "Ouch! That hurt!"
    }
}

return PryDoor.Config
