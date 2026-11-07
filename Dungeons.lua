local ADDON, ns = ...

-- One-hour fake key. Chests use retail M+ ratios: +3 = 60%, +2 = 80%, +1 = 100%.
ns.LIMIT = 3600
ns.PLUS3 = 2160 -- 36:00
ns.PLUS2 = 2880 -- 48:00
ns.PLUS1 = 3600 -- 60:00
ns.PREFIX = "ForeverPlus" -- addon comm prefix, <= 16 chars
ns.FORCE_PER_KILL = 2

-- Recommended level bands: installed ForeverGuide/DungeonData.lua, not admission limits.
-- Clear = every standard boss in `bosses` plus 100% enemy forces.
-- Each creature kill is 2% (50 kills = 100%). Rares / optionals are omitted.
-- /fplus complete still force-ends. Shaper's Terrace has no published roster yet.

ns.DUNGEONS = {
    rfc = {
        name = "Ragefire Chasm",
        levelMin = 13, levelMax = 18,
        instanceIDs = {389},
        names = {"ragefire chasm"},
        lastBosses = {"Bazzalan"},
        lastNpc = {11519},
        bosses = {
            {n="Oggleflint", id=11517},
            {n="Taragaman the Hungerer", id=11520},
            {n="Jergosh the Invoker", id=11518},
            {n="Bazzalan", id=11519},
        },
    },
    thanes = {
        name = "Hall of Thanes",
        levelMin = 13, levelMax = 18,
        instanceIDs = {},
        names = {"hall of thanes", "the hall of thanes"},
        lastBosses = {"Durgen Dirgehammer"},
        lastNpc = {},
        bosses = {
            {n="Faldrim Anvilmar"},
            {n="Magmatus"},
            {n="Plunder"},
            {n="Durgen Dirgehammer"},
        },
    },
    lordaeron = {
        name = "Ruins of Lordaeron",
        levelMin = 15, levelMax = 20,
        instanceIDs = {},
        names = {"ruins of lordaeron"},
        lastBosses = {"Rath'mael"},
        lastNpc = {},
        bosses = {
            {n="The Baron"},
            {n="Witherfang"},
            {n="The Abandoned"},
            {n="Bjork"},
            {n="Viktor the Vile"},
            {n="Rath'mael"},
        },
    },
    wc = {
        name = "Wailing Caverns",
        levelMin = 17, levelMax = 24,
        instanceIDs = {43},
        names = {"wailing caverns"},
        lastBosses = {"Mutanus the Devourer", "Mutanus"},
        lastNpc = {3654},
        bosses = {
            {n="Lady Anacondra", id=3671},
            {n="Lord Cobrahn", id=3669},
            {n="Lord Pythas", id=3670},
            {n="Lord Serpentis", id=3673},
            {n="Verdan the Everliving", id=5775},
            {n="Mutanus the Devourer", id=3654},
        },
    },
    dm = {
        name = "The Deadmines",
        levelMin = 17, levelMax = 26,
        instanceIDs = {36},
        names = {"the deadmines", "deadmines"},
        lastBosses = {"Edwin VanCleef", "VanCleef"},
        lastNpc = {639},
        bosses = {
            {n="Rhahk'Zor", id=644},
            {n="Sneed", id=643},
            {n="Gilnid", id=1763},
            {n="Mr. Smite", id=646},
            {n="Captain Greenskin", id=647},
            {n="Edwin VanCleef", id=639},
        },
    },
    sfk = {
        name = "Shadowfang Keep",
        levelMin = 22, levelMax = 30,
        instanceIDs = {33},
        names = {"shadowfang keep"},
        lastBosses = {"Archmage Arugal", "Arugal"},
        lastNpc = {4275},
        bosses = {
            {n="Rethilgore", id=3914},
            {n="Razorclaw the Butcher", id=3886},
            {n="Baron Silverlaine", id=3887},
            {n="Commander Springvale", id=4278},
            {n="Odo the Blindwatcher", id=4279},
            {n="Fenrus the Devourer", id=4274},
            {n="Wolf Master Nandos", id=3927},
            {n="Archmage Arugal", id=4275},
        },
    },
    excavation = {
        name = "Excavation Site: Wetlands",
        levelMin = 26, levelMax = 31,
        instanceIDs = {},
        names = {"excavation site", "excavation site: wetlands", "whelgar"},
        lastBosses = {"Relic Guardian"},
        lastNpc = {260326},
        bosses = {
            {n="Saltspine", id=260322},
            {n="Shadetooth", id=260325},
            {n="Highland Horror", id=260808},
            {n="Relic Guardian", id=260326},
        },
    },
    bfd = {
        name = "Blackfathom Deeps",
        levelMin = 24, levelMax = 32,
        instanceIDs = {48},
        names = {"blackfathom deeps"},
        lastBosses = {"Aku'mai"},
        lastNpc = {4829},
        bosses = {
            {n="Ghamoo-ra", id=4887},
            {n="Lady Sarevess", id=4831},
            {n="Gelihast", id=6243},
            {n="Lorgus Jett", id=12902},
            {n="Twilight Lord Kelris", id=4832},
            {n="Old Serra'kis", id=4830},
            {n="Aku'mai", id=4829},
        },
    },
    stocks = {
        name = "The Stockade",
        levelMin = 24, levelMax = 32,
        instanceIDs = {34},
        names = {"the stockade", "stormwind stockade", "stockade"},
        lastBosses = {"Bazil Thredd", "Dextren Ward"},
        lastNpc = {1716, 1663},
        bosses = {
            {n="Targorr the Dread", id=1696},
            {n="Kam Deepfury", id=1666},
            {n="Hamhock", id=1717},
            {n="Bazil Thredd", id=1716},
            {n="Dextren Ward", id=1663},
        },
    },
    dalaran = {
        name = "City of Dalaran",
        levelMin = 28, levelMax = 33,
        instanceIDs = {},
        names = {"city of dalaran", "dalaran"},
        lastBosses = {"Shade of the Archmage"},
        lastNpc = {},
        bosses = {
            {n="Atrexis the Grave Knight"},
            {n="Arcane Anomaly"},
            {n="Fel Ancient"},
            {n="Mana Devourer"},
            {n="Unstable Sentinel"},
            {n="Arcanic Enigma"},
            {n="Shade of the Archmage"},
        },
    },
    rfk = {
        name = "Razorfen Kraul",
        levelMin = 29, levelMax = 38,
        instanceIDs = {47},
        names = {"razorfen kraul"},
        lastBosses = {"Charlga Razorflank"},
        lastNpc = {4421},
        bosses = {
            {n="Roogug", id=6168},
            {n="Aggem Thorncurse", id=4424},
            {n="Death Speaker Jargba", id=4428},
            {n="Overlord Ramtusk", id=4420},
            {n="Agathelos the Raging", id=4422},
            {n="Charlga Razorflank", id=4421},
        },
    },
    gnomer = {
        name = "Gnomeregan",
        levelMin = 29, levelMax = 38,
        instanceIDs = {90},
        names = {"gnomeregan"},
        lastBosses = {"Mekgineer Thermaplugg", "Thermaplugg"},
        lastNpc = {7800},
        bosses = {
            {n="Grubbis", id=7361},
            {n="Viscous Fallout", id=7079},
            {n="Electrocutioner 6000", id=6235},
            {n="Crowd Pummeler 9-60", id=6229},
            {n="Mekgineer Thermaplugg", id=7800},
        },
    },
    smgy = {
        name = "Scarlet Monastery — Graveyard",
        levelMin = 30, levelMax = 38,
        instanceIDs = {189},
        names = {"scarlet monastery"},
        lastBosses = {"Bloodmage Thalnos", "Thalnos"},
        lastNpc = {4543},
        bosses = {
            {n="Interrogator Vishas", id=3983},
            {n="Bloodmage Thalnos", id=4543},
        },
        wing = "gy",
    },
    smlib = {
        name = "Scarlet Monastery — Library",
        levelMin = 33, levelMax = 41,
        instanceIDs = {189, 1001},
        names = {"scarlet monastery"},
        lastBosses = {"Arcanist Doan", "Doan"},
        lastNpc = {6487},
        bosses = {
            {n="Houndmaster Loksey", id=3974},
            {n="Arcanist Doan", id=6487},
        },
        wing = "lib",
    },
    smarm = {
        name = "Scarlet Monastery — Armory",
        levelMin = 36, levelMax = 44,
        instanceIDs = {189, 1004},
        names = {"scarlet monastery"},
        lastBosses = {"Herod"},
        lastNpc = {3975},
        bosses = {
            {n="Herod", id=3975},
        },
        wing = "arm",
    },
    smcath = {
        name = "Scarlet Monastery — Cathedral",
        levelMin = 38, levelMax = 46,
        instanceIDs = {189, 1004},
        names = {"scarlet monastery"},
        lastBosses = {"High Inquisitor Whitemane", "Whitemane"},
        lastNpc = {3977},
        bosses = {
            {n="Scarlet Commander Mograine", id=3976},
            {n="High Inquisitor Whitemane", id=3977},
        },
        wing = "cath",
    },
    drowned = {
        name = "The Drowned City",
        levelMin = 35, levelMax = 40,
        instanceIDs = {},
        names = {"the drowned city", "drowned city"},
        lastBosses = {"Min'loth the Serpent", "Min'loth"},
        lastNpc = {},
        bosses = {
            {n="Zul'Alai"},
            {n="Zin'aka"},
            {n="Deathless Marrow"},
            {n="Min'loth the Serpent"},
        },
    },
    rfd = {
        name = "Razorfen Downs",
        levelMin = 37, levelMax = 46,
        instanceIDs = {129},
        names = {"razorfen downs"},
        lastBosses = {"Amnennar the Coldbringer", "Amnennar"},
        lastNpc = {7358},
        bosses = {
            {n="Tuten'kash", id=7355},
            {n="Mordresh Fire Eye", id=7357},
            {n="Glutton", id=8567},
            {n="Amnennar the Coldbringer", id=7358},
        },
    },
    kroldok = {
        name = "Krol'dok Stronghold",
        levelMin = 40, levelMax = 45,
        instanceIDs = {},
        names = {"krol'dok stronghold", "kroldok stronghold", "krol'dok"},
        lastBosses = {"Overlord Mugg"},
        lastNpc = {258968},
        bosses = {
            {n="Overlord Mugg", id=258968},
        },
    },
    ulda = {
        name = "Uldaman",
        levelMin = 41, levelMax = 51,
        instanceIDs = {70},
        names = {"uldaman"},
        lastBosses = {"Archaedas"},
        lastNpc = {2748},
        bosses = {
            {n="Revelosh", id=6910},
            {n="Ironaya", id=7228},
            {n="Obsidian Sentinel", id=7023},
            {n="Ancient Stone Keeper", id=7206},
            {n="Galgann Firehammer", id=7291},
            {n="Grimlok", id=4854},
            {n="Archaedas", id=2748},
        },
    },
    zf = {
        name = "Zul'Farrak",
        levelMin = 44, levelMax = 54,
        instanceIDs = {209},
        names = {"zul'farrak", "zulfarrak"},
        lastBosses = {"Chief Ukorz Sandscalp", "Ukorz Sandscalp", "Ukorz"},
        lastNpc = {7267},
        bosses = {
            {n="Antu'sul", id=8127},
            {n="Theka the Martyr", id=7272},
            {n="Witch Doctor Zum'rah", id=7271},
            {n="Nekrum Gutchewer", id=7796},
            {n="Shadowpriest Sezz'ziz", id=7275},
            {n="Sergeant Bly", id=7604},
            {n="Hydromancer Velratha", id=7795},
            {n="Gahz'rilla", id=7273},
            {n="Chief Ukorz Sandscalp", id=7267},
        },
    },
    mara = {
        name = "Maraudon",
        levelMin = 46, levelMax = 55,
        instanceIDs = {349},
        names = {"maraudon"},
        lastBosses = {"Princess Theradras", "Theradras"},
        lastNpc = {12201},
        bosses = {
            {n="Noxxion", id=13282},
            {n="Razorlash", id=12258},
            {n="Lord Vyletongue", id=12236},
            {n="Celebras the Cursed", id=12225},
            {n="Landslide", id=12203},
            {n="Tinkerer Gizlock", id=13601},
            {n="Rotgrip", id=13596},
            {n="Princess Theradras", id=12201},
        },
    },
    alcaz = {
        name = "Alcaz Prison",
        levelMin = 48, levelMax = 53,
        instanceIDs = {},
        names = {"alcaz prison", "alcaz island prison", "alcaz island"},
        lastBosses = {"Blazeroar"},
        lastNpc = {},
        bosses = {
            {n="Blazeroar"},
        },
    },
    st = {
        name = "The Temple of Atal'Hakkar",
        levelMin = 50, levelMax = 60,
        instanceIDs = {109},
        names = {"the temple of atal'hakkar", "sunken temple", "atal'hakkar"},
        lastBosses = {"Shade of Eranikus", "Eranikus"},
        lastNpc = {5709},
        bosses = {
            {n="Atal'alarion", id=8580},
            {n="Jammal'an the Prophet", id=5710},
            {n="Ogom the Wretched", id=5711},
            {n="Dreamscythe", id=5721},
            {n="Weaver", id=5720},
            {n="Hazzas", id=5722},
            {n="Morphaz", id=5719},
            {n="Shade of Eranikus", id=5709},
        },
    },
    brd = {
        name = "Blackrock Depths",
        levelMin = 52, levelMax = 60,
        instanceIDs = {230},
        names = {"blackrock depths"},
        lastBosses = {"Emperor Dagran Thaurissan", "Dagran Thaurissan", "Thaurissan"},
        lastNpc = {9019},
        bosses = {
            {n="High Interrogator Gerstahn", id=9018},
            {n="Lord Roccor", id=9025},
            {n="Houndmaster Grebmar", id=9319},
            {n="Pyromancer Loregrain", id=9024},
            {n="Lord Incendius", id=9017},
            {n="Fineous Darkvire", id=9056},
            {n="Bael'Gar", id=9016},
            {n="General Angerforge", id=9033},
            {n="Golem Lord Argelmach", id=8983},
            {n="Ambassador Flamelash", id=9156},
            {n="Magmus", id=9938},
            {n="Emperor Dagran Thaurissan", id=9019},
        },
    },
    dme = {
        name = "Dire Maul — East",
        levelMin = 54, levelMax = 60,
        instanceIDs = {429},
        names = {"dire maul"},
        lastBosses = {"Alzzin the Wildshaper", "Alzzin"},
        lastNpc = {11492},
        bosses = {
            {n="Zevrim Thornhoof", id=11490},
            {n="Hydrospawn", id=13280},
            {n="Lethtendris", id=14327},
            {n="Alzzin the Wildshaper", id=11492},
        },
        wing = "east",
    },
    dmw = {
        name = "Dire Maul — West",
        levelMin = 56, levelMax = 60,
        instanceIDs = {429},
        names = {"dire maul"},
        lastBosses = {"Prince Tortheldrin", "Tortheldrin"},
        lastNpc = {11486},
        bosses = {
            {n="Tendris Warpwood", id=11489},
            {n="Illyanna Ravenoak", id=11488},
            {n="Magister Kalendris", id=11487},
            {n="Immol'thar", id=11496},
            {n="Prince Tortheldrin", id=11486},
        },
        wing = "west",
    },
    dmn = {
        name = "Dire Maul — North",
        levelMin = 56, levelMax = 60,
        instanceIDs = {429},
        names = {"dire maul"},
        lastBosses = {"King Gordok", "Gordok"},
        lastNpc = {11501},
        bosses = {
            {n="Guard Mol'dar", id=14326},
            {n="Stomper Kreeg", id=14322},
            {n="Guard Fengus", id=14321},
            {n="Guard Slip'kik", id=14323},
            {n="Captain Kromcrush", id=14325},
            {n="Cho'Rush the Observer", id=14324},
            {n="King Gordok", id=11501},
        },
        wing = "north",
    },
    lbrs = {
        name = "Lower Blackrock Spire",
        levelMin = 55, levelMax = 60,
        instanceIDs = {229},
        names = {"blackrock spire", "lower blackrock spire"},
        lastBosses = {"Overlord Wyrmthalak", "Wyrmthalak"},
        lastNpc = {9568},
        bosses = {
            {n="Highlord Omokk", id=9196},
            {n="Shadow Hunter Vosh'gajin", id=9236},
            {n="War Master Voone", id=9237},
            {n="Mother Smolderweb", id=10596},
            {n="Urok Doomhowl", id=10584},
            {n="Quartermaster Zigris", id=9736},
            {n="Halycon", id=10220},
            {n="Gizrul the Slavener", id=10268},
            {n="Overlord Wyrmthalak", id=9568},
        },
        wing = "lower",
    },
    ubrs = {
        name = "Upper Blackrock Spire",
        levelMin = 59, levelMax = 60,
        instanceIDs = {229},
        names = {"blackrock spire", "upper blackrock spire"},
        lastBosses = {"General Drakkisath", "Drakkisath"},
        lastNpc = {10363},
        bosses = {
            {n="Pyroguard Emberseer", id=9816},
            {n="Solakar Flamewreath", id=10264},
            {n="Goraluk Anvilcrack", id=10899},
            {n="Warchief Rend Blackhand", id=10429},
            {n="The Beast", id=10430},
            {n="General Drakkisath", id=10363},
        },
        wing = "upper",
    },
    blackmaw = {
        name = "Blackmaw Hold",
        levelMin = 55, levelMax = 60,
        instanceIDs = {},
        names = {"blackmaw hold", "blackmaw"},
        lastBosses = {"Varrox Bleakhoof"},
        lastNpc = {},
        bosses = {
            {n="Varrox Bleakhoof"},
        },
    },
    scholo = {
        name = "Scholomance",
        levelMin = 58, levelMax = 60,
        instanceIDs = {289, 1007},
        names = {"scholomance"},
        lastBosses = {"Darkmaster Gandling", "Gandling"},
        lastNpc = {1853},
        bosses = {
            {n="Kirtonos the Herald", id=10506},
            {n="Jandice Barov", id=10503},
            {n="Rattlegore", id=11622},
            {n="Ras Frostwhisper", id=10508},
            {n="Instructor Malicia", id=10505},
            {n="Doctor Theolen Krastinov", id=11261},
            {n="Lorekeeper Polkelt", id=10901},
            {n="The Ravenian", id=10507},
            {n="Lord Alexei Barov", id=10504},
            {n="Lady Illucia Barov", id=10502},
            {n="Darkmaster Gandling", id=1853},
        },
    },
    shapers = {
        name = "Shaper's Terrace",
        levelMin = 58, levelMax = 60,
        instanceIDs = {},
        names = {"shaper's terrace", "shapers terrace"},
        lastBosses = {},
        lastNpc = {},
        bosses = {
        },
        manual = true,
    },
    stratlive = {
        name = "Stratholme — Main Gate",
        levelMin = 58, levelMax = 60,
        instanceIDs = {329},
        names = {"stratholme"},
        lastBosses = {"Balnazzar"},
        lastNpc = {10813},
        bosses = {
            {n="The Unforgiven", id=10516},
            {n="Timmy the Cruel", id=10808},
            {n="Malor the Zealous", id=11032},
            {n="Cannon Master Willey", id=10997},
            {n="Archivist Galford", id=10811},
            {n="Balnazzar", id=10813},
        },
        wing = "live",
    },
    stratdead = {
        name = "Stratholme — Service Gate",
        levelMin = 58, levelMax = 60,
        instanceIDs = {329},
        names = {"stratholme"},
        lastBosses = {"Baron Rivendare", "Rivendare"},
        lastNpc = {10440},
        bosses = {
            {n="Magistrate Barthilas", id=10435},
            {n="Baroness Anastari", id=10436},
            {n="Nerub'enkan", id=10437},
            {n="Maleki the Pallid", id=10438},
            {n="Ramstein the Gorger", id=10439},
            {n="Baron Rivendare", id=10440},
        },
        wing = "undead",
    },
}

ns.ID_TO_KEYS = {}
ns.NAME_TO_KEYS = {}
ns.NPC_TO_KEY = {}
ns.BOSSNAME_TO_KEY = {}

function ns.IsSecret(v)
    if not issecretvalue then return false end
    local ok, hidden = pcall(issecretvalue, v)
    return not ok or hidden
end
function ns.SafeRead(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ...)
    if not ok or ns.IsSecret(value) then return nil end
    return value
end
function ns.SafeInstance()
    if not GetInstanceInfo then return nil end
    local ok, name, kind, _, _, _, _, _, id = pcall(GetInstanceInfo)
    if not ok or ns.IsSecret(name) or ns.IsSecret(kind) or ns.IsSecret(id) then return nil end
    if type(kind) ~= "string" or (name ~= nil and type(name) ~= "string") or (id ~= nil and type(id) ~= "number") then return nil end
    return {name=name, instanceType=kind, instanceID=id}
end
local function Fold(s)
    if ns.IsSecret(s) or type(s) ~= "string" then return "" end
    s = s:lower()
    s = s:gsub("['’`]", "")
    s = s:gsub("[^%w]+", " ")
    s = s:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " ")
    return s
end
ns.Fold = Fold

for key, d in pairs(ns.DUNGEONS) do
    d.key = key
    for i = 1, #(d.instanceIDs or {}) do
        local id = d.instanceIDs[i]
        ns.ID_TO_KEYS[id] = ns.ID_TO_KEYS[id] or {}
        table.insert(ns.ID_TO_KEYS[id], key)
    end
    for i = 1, #(d.names or {}) do
        local n = Fold(d.names[i])
        ns.NAME_TO_KEYS[n] = ns.NAME_TO_KEYS[n] or {}
        table.insert(ns.NAME_TO_KEYS[n], key)
    end
    for i = 1, #(d.lastNpc or {}) do
        ns.NPC_TO_KEY[d.lastNpc[i]] = key
    end
    for i = 1, #(d.lastBosses or {}) do
        ns.BOSSNAME_TO_KEY[Fold(d.lastBosses[i])] = key
    end
    for i = 1, #(d.bosses or {}) do
        local b = d.bosses[i]
        if b.id then ns.NPC_TO_KEY[b.id] = key end
        if b.n then ns.BOSSNAME_TO_KEY[Fold(b.n)] = key end
    end
end

function ns.AreSiblingDungeons(a, b)
    if not a or not b then return false end
    for _,id in ipairs(a.instanceIDs or {}) do
        for _,other in ipairs(b.instanceIDs or {}) do if id == other then return true end end
    end
    return false
end
function ns.DungeonByKey(key)
    return ns.DUNGEONS[key]
end

function ns.ChestForTime(sec)
    if not sec then return 0 end
    if sec <= ns.PLUS3 then return 3 end
    if sec <= ns.PLUS2 then return 2 end
    if sec <= ns.PLUS1 then return 1 end
    return 0
end

function ns.FormatTime(sec)
    if not sec or sec < 0 then sec = 0 end
    local sign = ""
    -- elapsed display is always unsigned; overtime is handled by caller
    local s = math.floor(sec + 0.5)
    local h = math.floor(s / 3600)
    local m = math.floor((s % 3600) / 60)
    local r = s % 60
    if h > 0 then
        return string.format("%d:%02d:%02d", h, m, r)
    end
    return string.format("%d:%02d", m, r)
end

function ns.FormatClock(sec, limit)
    limit = limit or ns.LIMIT
    if sec <= limit then
        local left = limit - sec
        return ns.FormatTime(left), false
    end
    return "+" .. ns.FormatTime(sec - limit), true
end

local function ZoneBlob()
    local a = ""
    local inst = ns.SafeInstance()
    if inst and type(inst.name) == "string" then a = inst.name end
    local b = ns.SafeRead(GetRealZoneText) or ""
    local c = ns.SafeRead(GetSubZoneText) or ""
    local d = ns.SafeRead(GetMinimapZoneText) or ""
    if type(b) ~= "string" then b = "" end
    if type(c) ~= "string" then c = "" end
    if type(d) ~= "string" then d = "" end
    return Fold(a .. " " .. b .. " " .. c .. " " .. d)
end

function ns.ResolveDungeon()
    local inst = ns.SafeInstance()
    if not inst then return nil end
    local name, instanceType, instanceID = inst.name, inst.instanceType, inst.instanceID
    if instanceType ~= "party" then
        return nil
    end

    local keys
    if instanceID and ns.ID_TO_KEYS[instanceID] then
        keys = ns.ID_TO_KEYS[instanceID]
    end

    if not keys then
        local folded = Fold(name)
        keys = ns.NAME_TO_KEYS[folded]

    end

    if not keys or #keys == 0 then
        -- Unknown 5-man: still time it, keyed by instance id or name.
        local fallback = "id:" .. tostring(instanceID or 0)
        if name and name ~= "" then
            fallback = "name:" .. Fold(name)
        end
        return {
            key = fallback,
            name = name or "Dungeon",
            lastBosses = {},
            lastNpc = {},
            bosses = {},
            unknown = true,
            instanceID = instanceID,
        }
    end

    if #keys == 1 then
        local d = ns.DUNGEONS[keys[1]]
        return d, 2
    end

    -- Multi-wing maps: pick by subzone, else return a parent stand-in (first key)
    -- until a last-boss kill upgrades the key.
    local blob = ZoneBlob()
    local function has(s) return blob:find(s, 1, true) end

    if instanceID == 189 or (Fold(name):find("scarlet")) then
        if has("library") or has("gallery") or has("doan") then return ns.DUNGEONS.smlib, 2 end
        if has("armory") or has("hunter") or has("herod") then return ns.DUNGEONS.smarm, 2 end
        if has("cathedral") or has("chapel") or has("whitemane") or has("mograine") then return ns.DUNGEONS.smcath, 2 end
        if has("grave") or has("thalnos") or has("vishas") then return ns.DUNGEONS.smgy, 2 end
        return ns.DUNGEONS.smgy, 0
    end

    if instanceID == 429 or Fold(name):find("dire maul") then
        if has("gordok") or has("north") or has("commons") then return ns.DUNGEONS.dmn, 2 end
        if has("capital") or has("west") or has("conservatory") then return ns.DUNGEONS.dmw, 2 end
        if has("warpwood") or has("east") then return ns.DUNGEONS.dme, 2 end
        return ns.DUNGEONS.dme, 0
    end

    if instanceID == 229 or Fold(name):find("blackrock spire") then
        if has("upper") or has("hall of blackhand") or has("spire throne") or has("the rookery") then
            return ns.DUNGEONS.ubrs, 2
        end
        if has("lower") or has("hordemar") or has("skitterweb") then
            return ns.DUNGEONS.lbrs, 2
        end
        return ns.DUNGEONS.lbrs, 0
    end

    if instanceID == 329 or Fold(name):find("stratholme") then
        if has("service") or has("slaughter") or has("gauntlet") or has("undead") then
            return ns.DUNGEONS.stratdead, 2
        end
        return ns.DUNGEONS.stratlive, 0
    end

    return ns.DUNGEONS[keys[1]]
end

local function NameHits(folded, n)
    return n ~= "" and folded ~= "" and folded == n
end
ns.NameHits = NameHits

function ns.KeyFromKill(npcId, bossName)
    if ns.IsSecret(npcId) then return nil end
    if npcId ~= nil then return ns.NPC_TO_KEY[npcId] end
    local folded = Fold(bossName)
    if folded == "" then return nil end
    if ns.BOSSNAME_TO_KEY[folded] then
        return ns.BOSSNAME_TO_KEY[folded]
    end
    for name, key in pairs(ns.BOSSNAME_TO_KEY) do
        if NameHits(folded, name) then
            return key
        end
    end
    return nil
end

function ns.IsLastBossOf(dungeon, npcId, bossName)
    if not dungeon or ns.IsSecret(npcId) then return false end
    if npcId and dungeon.lastNpc then
        for i = 1, #dungeon.lastNpc do
            if dungeon.lastNpc[i] == npcId then return true end
        end
    end
    if npcId ~= nil then
        local via = ns.KeyFromKill(npcId)
        if via and via ~= dungeon.key and ns.AreSiblingDungeons(dungeon, ns.DUNGEONS[via]) then return false, via end
        return false
    end
    local folded = Fold(bossName)
    if folded == "" then return false end
    for i = 1, #(dungeon.lastBosses or {}) do
        local n = Fold(dungeon.lastBosses[i])
        if NameHits(folded, n) then
            return true
        end
    end
    -- Kill of a last boss that belongs to a sibling wing of this instance.
    local via = ns.KeyFromKill(npcId, bossName)
    if via and ns.DUNGEONS[via] then
        local a, b = dungeon.instanceIDs or {}, ns.DUNGEONS[via].instanceIDs or {}
        for i = 1, #a do
            for j = 1, #b do
                if a[i] == b[j] then return true, via end
            end
        end
        -- same display name family
        if dungeon.names and ns.DUNGEONS[via].names then
            for i = 1, #dungeon.names do
                for j = 1, #ns.DUNGEONS[via].names do
                    if dungeon.names[i] == ns.DUNGEONS[via].names[j] then
                        return true, via
                    end
                end
            end
        end
    end
    return false
end

function ns.MatchRequiredBoss(dungeon, npcId, bossName)
    if not dungeon or ns.IsSecret(npcId) then return nil end
    local list = dungeon.bosses or {}
    local folded = Fold(bossName)
    for i = 1, #list do
        local b = list[i]
        if npcId and b.id and npcId == b.id then
            return i, b
        end
        if folded ~= "" and (npcId == nil or b.id == nil) then
            if b.n and NameHits(folded, Fold(b.n)) then return i, b end
            -- Declared final-boss aliases belong only to the canonical final boss.
            if b.n and Fold(b.n) == Fold((dungeon.lastBosses or {})[1]) then
                for _, alias in ipairs(dungeon.lastBosses or {}) do
                    if NameHits(folded, Fold(alias)) then return i, b end
                end
            end
            for _, alias in ipairs(b.aliases or {}) do
                if NameHits(folded, Fold(alias)) then return i, b end
            end
        end
    end
    return nil
end

function ns.IsBossMarked(run, b)
    if not run or not run.bossDown or not b then return false end
    if b.id and run.bossDown["id:" .. b.id] then return true end
    if b.n and run.bossDown["n:" .. Fold(b.n)] then return true end
    return false
end

function ns.MarkBoss(run, b, npcId, name)
    if not run then return end
    run.bossDown = run.bossDown or {}
    if b and b.id then run.bossDown["id:" .. b.id] = true end
    if b and b.n then run.bossDown["n:" .. Fold(b.n)] = true end
    -- Store only the matched roster identity. An observed name can disagree
    -- with an authoritative NPC ID and must not credit a second roster boss.
end

function ns.CountBossesDown(run)
    if not run then return 0, 0 end
    local list = (run.dungeon and run.dungeon.bosses) or {}
    local down, total = 0, #list
    for i = 1, total do
        if ns.IsBossMarked(run, list[i]) then
            down = down + 1
        end
    end
    return down, total
end

function ns.AllBossesDown(run)
    local down, total = ns.CountBossesDown(run)
    return total > 0 and run.dungeon and not run.dungeon.manual and not run.dungeon.unknown and down >= total
end

function ns.ForcesPercent(run)
    if not run then return 0 end
    local pct = (run.kills or 0) * (ns.FORCE_PER_KILL or 2)
    if pct > 100 then return 100 end
    return pct
end

function ns.ObjectivesMet(run)
    if not run then return false end
    if ns.ForcesPercent(run) < 100 then return false end
    return ns.AllBossesDown(run)
end
