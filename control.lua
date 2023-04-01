local scan_interval = 60*2.5
local suppress_time = 60*30
local suppress_distance = 64

function on_init()
    global.q = nil
    global.qpos = nil
    global.radars = {}
    global.suppress = {}
    global.last_scan = 0

    -- Prepopulate radars by scanning all surfaces. This is a slow operation so
    -- we only do it once
    for _, s in pairs(game.surfaces) do
        for _, e in pairs(s.find_entities_filtered({ type = "radar" })) do
            global.radars[e.unit_number] = e
        end
    end
end

function start_scan()
    if global.qpos then
        return -- already scanning!
    end

    local q = {}
    for k, e in pairs(global.radars) do
        if e.valid then
            table.insert(q, e)
        else
            global.radars[k] = nil
        end
    end

    global.q = q
    global.qpos = 1
    global.last_scan = game.tick
end

function scan_at_radar(e)
    if not e.valid then
        return -- oops
    end

    if e.energy < e.prototype.energy_usage then
        return -- can't see shit, captain
    end

    -- upper left corner of radar's chunk
    local x = 32*math.floor(e.position.x / 32)
    local y = 32*math.floor(e.position.y / 32)
    local range = 32 * e.prototype.max_distance_of_nearby_sector_revealed

    local enemies = e.surface.find_units({
        area = {
            left_top = { x - range, y - range },
            right_bottom = { x + range + 32, y + range + 32 },
        },
        force = e.force,
        condition = "enemy",
    })
    for _, enemy in pairs(enemies) do
        if not suppressed(enemy) then
            show_alert(e.force, enemy)
        end
    end
end

function show_alert(force, e)
    local msg = {
        "RadarAlerts.detected",
        {
            "RadarAlerts.generic",
            e.name,
        },
        {
            "RadarAlerts.gps",
            math.floor(e.position.x),
            math.floor(e.position.y),
            e.surface.name,
        },
    }
    if settings.global["RadarAlerts-species"].value then
        msg[2][1] = "RadarAlerts.species"
    end
    if #game.surfaces > 1 then
        msg[3][1] = "RadarAlerts.gps_surface"
    end

    if settings.global["RadarAlerts-alert"].value then
        for _, p in pairs(force.players) do
            p.add_custom_alert(e, { type = "item", name = "radar" }, msg, true)
        end
    end
    if settings.global["RadarAlerts-console"].value then
        force.print(msg)
    end
    if settings.global["RadarAlerts-sound"].value then
        force.play_sound({ path = "RadarAlerts-alert" })
    end

    table.insert(global.suppress, {
        x = e.position.x,
        y = e.position.y,
        name = e.name,
        tick = game.tick,
    })
end

function suppressed(e)
    local epx = e.position.x
    local epy = e.position.y
    local sd2 = suppress_distance ^ 2
    local check_name = settings.global["RadarAlerts-species"].value
    for _, s in pairs(global.suppress) do
        if (not check_name or e.name == s.name) and (s.x - epx)^2 + (s.y - epy)^2 < sd2 then
            return true
        end
    end
    return false
end

function prune_suppress()
    local new = {}
    for _, s in pairs(global.suppress) do
        if game.tick - s.tick < suppress_time then
            table.insert(new, s)
        end
    end
    global.suppress = new
end

function on_tick(event)
    if global.qpos then
        local e = global.q[global.qpos]
        if e then
            scan_at_radar(e)
            global.qpos = global.qpos + 1
        else
            global.q = nil
            global.qpos = nil
            prune_suppress()
        end
    end

    if game.tick - global.last_scan >= scan_interval then
        start_scan()
    end
end

function on_sector_scanned(event)
    global.radars[event.radar.unit_number] = event.radar
end

function on_any_built_entity(event)
    local e = event.created_entity
    if e.type == "radar" then
        global.radars[e.unit_number] = e
    end
end

script.on_init(on_init)
script.on_event(defines.events.on_tick, on_tick)
script.on_event(defines.events.on_sector_scanned, on_sector_scanned)
script.on_event(defines.events.on_built_entity, on_any_built_entity, {{ filter = "type", type = "radar" }})
script.on_event(defines.events.on_robot_built_entity, on_any_built_entity, {{ filter = "type", type = "radar" }})
