chatfilter = {
    version = "0.1.0",
    author = "ChimneySwift"
}

-- Initialize bad word list (add to the bottom of list.txt for more words)
chatfilter.badwords = {}
local file = minetest.get_modpath("chatfilter").."/list.txt"

for line in io.lines(file) do
    line = string.gsub(line, '[ \t]+%f[\r\n%z]', '') -- Remove trailing spaces
    if line then
        table.insert(chatfilter.badwords, line)
    end
end

-- Default random isn't random enough for rapid readings as the seed changes every second, this is every ms
math.randomseed(os.clock())

-- For skyflashing
local ps = {}
local function revertsky()
    for key, entry in pairs(ps) do
        local sky = entry.sky
        entry.p:set_sky(sky.bgcolor, sky.type, sky.textures)
    end

    ps = {}
end

-- Based off lighting mod
-- -> pos:      the position of the strike
-- -> texture:  the texture name to use
-- -> sound:    the sound name to use (no sound if nil)
-- -> skyflash: whether to make the sky flash
-- -> explode:  whether to make a TNT explosion at the strike point
function chatfilter.strike(pos, texture, sound, skyflash, explode)
    pos.y = pos.y-0.5
    local size = 100

    minetest.add_particlespawner({
        amount = 1,
        time = 0.2,
        -- make it hit the top of a block exactly with the bottom
        minpos = {x = pos.x, y = pos.y + (size / 2) + 1/2, z = pos.z },
        maxpos = {x = pos.x, y = pos.y + (size / 2) + 1/2, z = pos.z },
        minvel = {x = 0, y = 0, z = 0},
        maxvel = {x = 0, y = 0, z = 0},
        minacc = {x = 0, y = 0, z = 0},
        maxacc = {x = 0, y = 0, z = 0},
        minexptime = 0.2,
        maxexptime = 0.2,
        minsize = size * 10,
        maxsize = size * 10,
        collisiondetection = true,
        vertical = true,
        texture = texture,
        glow = 14,
    })

    if sound then
        minetest.sound_play(sound, {
            pos = pos,
            max_hear_distance = 5000,
        })
    end

    if skyflash then
        local playerlist = minetest.get_connected_players()
        for i, p in pairs(playerlist) do
            -- Do sky
            local sky = {}
            sky.bgcolor, sky.type, sky.textures = p:get_sky()

            local name = p:get_player_name()
            if ps[name] == nil then
                ps[name] = {p = p, sky = sky}
                p:set_sky(0xffffff, "plain", {})
            end
        end
        minetest.after(0.2, revertsky)
    end

    if explode then
        tnt.boom(pos, {radius = 3, damage_radius = 1})
    end
end

-- Inventory exploding
local function get_random_trajectory()
    -- get random number to 2 decimal places
    local function ran(a,b)
        return math.random(a*100, b*100)/100
    end
    return {x=ran(-8,8), y=ran(6,8), z=ran(-8,8)}
end

-- Clear the inventory of a player by exploding their items everywhere
local inventory_save = {}
function chatfilter.clearinv(player)
    local pos = player:get_pos()
    local inv = player:get_inventory()
    local lists = inv:get_lists()

    inventory_save[player:get_player_name()] = table.copy(lists)

    for i,l in pairs(lists) do
        -- Clear list
        inv:set_list(i, {})
        for _,item in pairs(l) do
            local i_ent = minetest.add_item(pos, item)
            if i_ent then
                local vel = get_random_trajectory()
                i_ent:set_velocity(vel)
            end
        end
    end
end

chatfilter.img_cmd_pairs = {
    laser = {sound = "laser", skyflash = false},
    ice = {sound = "laser", skyflash = false},
    lightning = {sound = "lightning", skyflash = false},
}
-- Priv nuke
minetest.register_priv("nuke", "LeTs YoU nUkE tHiNgZ") 

-- Chatcommand
minetest.register_chatcommand("laser", {
    params = "<playername> [intensity] [type]",
    description = "Zap playername with a laser of type lighting, ice or laser (default: lightning), with intensity 0 = just zap, 1 =  zap and hurt, 2 = zap and kill, 3 = zap, kill, clear inventory (default: 1)", -- Full description
    privs = {nuke=true},
    func = function(name, params)
        local split = string.split(params, " ")
        local target_name, intensity, type = (split[1] or ""), (tonumber(split[2]) or 1), (split[3] or "lightning")
        target = minetest.get_player_by_name(target_name)
        

        if not target then
            return false, "Player does not exist"
        else
            -- Clear inv first otherwise bone mods screw with it
            if intensity >= 4 then
                chatfilter.clearinv(target)
            end

            if intensity == 1 then
                target:set_hp(math.floor(target:get_hp()/2))
            elseif intensity >= 2 then
                target:set_hp(0)
            end

            chatfilter.strike(target:get_pos(), type..".png", chatfilter.img_cmd_pairs[type].sound, chatfilter.img_cmd_pairs[type].skyflash, true)
        end
    end,
})

minetest.register_chatcommand("nukerestore", {
    params = "<playername>",
    description = "Restore the inventory of a player after they've been lasored", -- Full description
    privs = {nuke=true},
    func = function(name, param)
        target = minetest.get_player_by_name(param)

        if not target then
            return false, "Player does not exist"
        else
            player:get_inventory():set_lists(inventory_save[player:get_player_name()]) -- Seems legit
                
        end
    end,
})

local replace_chars = {
    "!",
    "%?",
    "%.",
    ",",
    "'",
    "\"",
    "%)",
    "%(",
    "%[",
    "%]",
    "-",
    "_",
    "œ",
    "∑",
    "´",
    "®",
    "†",
    "¥",
    "¨",
    "ˆ",
    "ø",
    "π"
    "Œ",
    "„",
    "‰",
    "ˇ",
    "Ø",
    "∏",
    "˝",
    "",
    "Æ",
    "ß",
    "˙",
    "˙",
    "∆",
    "¬",
    "æ",
    "§",
    "¶",
    "•",
    "ª",
    "º",
    "√",
    "µ",
    "˜",
    "ç",
    "≈",
    "Ω",
    
}
function chatfilter.contains_bad_words(message)
    -- Remove special characters
    for _, char in pairs(replace_chars) do
        message = message:gsub(char, " ")
    end

    -- Remove duplicate spaces
    message = message:gsub("%s+", " ")

    -- Lowercase
    message = message:lower()

    -- Don't miss words on the end of the string
    message = " "..message.." "

    for _, word in pairs(chatfilter.badwords) do
        if message:find(" "..word.." ") then
            return true
        end
    end
end

-- Minetest side
minetest.register_on_chat_message(function(name, message)
    if chatfilter.contains_bad_words(message) then
        target = minetest.get_player_by_name(name)
        if target then
            target:set_hp(0)
            chatfilter.strike(target:get_pos(), "lightning.png", "lightning", true, false)
            minetest.chat_send_player(name, "Please do not swear in this server OR GET NUKED.")
            minetest.log("action", "[chatfilter] Message from "..name.." not sent for innapropriate content: "..message)
        end
        return true
    end
end)

-- IRC side, override the send local function, otherwise we can't catch the message to stop it getting to minetest
-- We will run this after the server has loaded so that we can have this mod load before the IRC mod,
-- otherwise the callback above won't stop the message being sent to IRC
minetest.after(1, function()
    function irc.sendLocal(message)
        if chatfilter.contains_bad_words(message) then
            irc.logChat("[chatfilter] Bad message not sent to Minetest: "..message)

            -- Extract name and message
            local name, message = message:match("%*? ?([^>]+)@IRC (.*)")

            if name then
                -- kick the user
                irc.send("KICK "..irc.config.channel.." "..name.." Please do not swear in this channel. OR FEEL MY SHARP BOOT")
            end
        else
            minetest.chat_send_all(message)
            irc.logChat(message)
        end
    end
end)
