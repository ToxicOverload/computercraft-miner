os.loadAPI("/save")
os.loadAPI("/pathfinding")

function table_remove_vector_val(table, val)
  local tmp = table
  for k,v in pairs(tmp) do
    if vector_equals(v, val) then
      table.remove(tmp, k)
      break
    end
  end

  return tmp
end

function distance_check()
  local v_diff = data["coords"] - settings["dropoff_location"]
  local dist = math.sqrt(v_diff.x ^ 2 + v_diff.z ^ 2)

  if dist >= settings["max_dist"] then
    return_to_dropoff(true)
  end
end

function inv_check()
  local full = true
  for i = 1,16 do
    if turtle.getItemCount(i) == 0 then
      full = false
    end
  end

  if full then
    return_to_dropoff()
  end
end

function open()
  local modemSide

  for _,side in pairs(redstone.getSides()) do
    if peripheral.getType(side) == "modem" then
      modemSide = side
      break
    end
  end

  local m = peripheral.wrap(modemSide)
  m.open(settings["message_frequency"])

  return m
end

function refuel()
  if turtle.refuel(1) then
    return true
  else
    local success = false
    for i = 1, 16 do
      if turtle.getItemDetail(i) ~= nil and turtle.getItemDetail(i).name == "minecraft:coal" then
        turtle.select(i)
        turtle.refuel(1)
        success = true
        break
      end
    end

    return success
  end
end

function contains_key(table, key)
  return table[key] ~= nil
end

function contains_val(table, val)
  for _,v in pairs(table) do
    if v == val then
      return true
    end
  end

  return false
end

function can_mine(direction)
  local bool, dat
  if direction == 0 then
    bool, dat = turtle.inspect()
  elseif direction == 1 then
    bool, dat = turtle.inspectUp()
  elseif direction == -1 then
    bool, dat = turtle.inspectDown()
  end

  if bool then
    return contains_val(ores, dat.name) or contains_val(whitelist, dat.name)
  else
    return true
  end
end

function turn_to(direction)
  while (data["heading"] - direction) % 4 >= 2 do
    turnRight()
  end
  if (data["heading"] - direction) % 4 == 1 then
    turnLeft()
  end
end

function turnRight()
  turtle.turnRight()
  data["heading"] = data["heading"] + 1
  data["heading"] = data["heading"] % 4

  save.write_standard_file("/data/data", data)
end

function turnLeft()
  turtle.turnLeft()
  data["heading"] = data["heading"] + 3
  data["heading"] = data["heading"] % 4

  save.write_standard_file("/data/data", data)
end

function forward()
  if can_mine(0) then
    if can_mine(0) and turtle.dig() then
      inv_check()
    end
  else
    return_to_dropoff(true)
  end

  if turtle.forward() then
    data["coords"] = data["coords"] + heading_to_transform[data["heading"]]
    save.write_standard_file("/data/data", data)

    inspect_all()
    distance_check()
    return true
  elseif turtle.getFuelLevel() == 0 and not refuel() then
    print("OUT OF FUEL!")
  end
  return false
end

function up()
  if can_mine(1) then
    if can_mine(1) and turtle.digUp() then
      inv_check()
    end
  else
    return_to_dropoff(true)
  end

  if turtle.up() then
    data["coords"] = data["coords"] + vector.new(0, 1, 0)
    save.write_standard_file("/data/data", data)

    inspect_all()
    distance_check()
    return true
  elseif turtle.getFuelLevel() == 0 and not refuel() then
    print("OUT OF FUEL!")
  end
  return false
end

function down()
  if can_mine(-1) then
    if can_mine(-1) and turtle.digDown() then
      inv_check()
    end
  else
    return_to_dropoff(true)
  end

  if turtle.down() then
    data["coords"] = data["coords"] + vector.new(0, -1, 0)
    save.write_standard_file("/data/data", data)

    inspect_all()
    distance_check()
    return true
  elseif turtle.getFuelLevel() == 0 and not refuel() then
    print("OUT OF FUEL!")
  end
  return false
end

function move_towards(coords, update_path)
  local move_result
  if coords.y > data["coords"].y then
    move_result = up()
  elseif coords.y < data["coords"].y then
    move_result = down()
  elseif coords.z < data["coords"].z then
    turn_to(0)
    move_result = forward()
  elseif coords.x > data["coords"].x then
    turn_to(1)
    move_result = forward()
  elseif coords.z > data["coords"].z then
    turn_to(2)
    move_result = forward()
  elseif coords.x < data["coords"].x then
    turn_to(3)
    move_result = forward()
  end

  if move_result and update_path and vector_equals(data["return_path"][1], data["coords"]) then
    table.remove(data["return_path"], 1)
  end
end

function vector_equals(v1, v2)
  return v1.x == v2.x and v1.y == v2.y and v1.z == v2.z
end

function map_remove(m, coords)
  if m[coords.x] and m[coords.x][coords.y] then
    m[coords.x][coords.y][coords.z] = nil
  end
end

function map_exists(m, coords)
  return m[coords.x] and m[coords.x][coords.y] and m[coords.x][coords.y][coords.z]
end

function inspect_all(end_heading)
  end_heading = end_heading or data["heading"]

  --Just a shortcut
  local x, y, z = data["coords"].x, data["coords"].y, data["coords"].z

  map = push_to_map(map, data["coords"], "minecraft:air")

  if not map_exists(map, vector.new(x, y+1, z)) then
    push_to_map_from_raw_inspect_output(1)
  end
  if not map_exists(map, vector.new(x, y-1, z)) then
    push_to_map_from_raw_inspect_output(-1)
  end

  for h=0,3 do
    local transform = heading_to_transform[h]
    if not map_exists(map, vector.new(x + transform.x, y, z + transform.z)) then
      turn_to(h)
      push_to_map_from_raw_inspect_output(0)
    end
  end

  turn_to(end_heading)
end

function push_to_map_from_raw_inspect_output(direction)
  local bool, blockdat, coords
  if direction == 0 then
    bool, blockdat = turtle.inspect()
    coords = data["coords"] + heading_to_transform[data["heading"]]
  elseif direction == 1 then
    bool, blockdat = turtle.inspectUp()
    coords = data["coords"] + vector.new(0, 1, 0)
  elseif direction == -1 then
    bool, blockdat = turtle.inspectDown()
    coords = data["coords"] + vector.new(0, -1, 0)
  end

  if bool then    
    map = push_to_map(map, coords, blockdat.name)

    if contains_val(ores, blockdat.name) and (data["mode"] == 0 or data["mode"] == 1 or data["mode"] == 2 or data["mode"] == 5) then
      current_vein = push_to_map(current_vein, coords, blockdat.name)
      data["next_ore_location"] = coords

      data["mode"] = 1
    end
  else
    map = push_to_map(map, coords, "minecraft:air")
  end

  save.write_map("/data/map", map)
  save.write_map("/data/current_vein", current_vein)
end

function push_to_map(map_obj, coords, blockname)
  local temp_obj = map_obj

  if not temp_obj[coords.x] then
    temp_obj[coords.x] = {}
  end
  if not temp_obj[coords.x][coords.y] then
    temp_obj[coords.x][coords.y] = {}
  end

  temp_obj[coords.x][coords.y][coords.z] = blockname

  return temp_obj
end

function vein_tick()
  --Save the location of the next ore
  local next_loc = data["next_ore_location"]

  move_towards(data["next_ore_location"])

  if data["mode"] == 1 and vector_equals(data["coords"], next_loc) then
    map_remove(current_vein, next_loc)

    local closest
    local closest_dist
    for x in pairs(current_vein) do
      for y in pairs(current_vein[x]) do
        for z in pairs(current_vein[x][y]) do
          local dist = math.abs(data["coords"].x - x) + math.abs(data["coords"].y - y) + math.abs(data["coords"].z - z)
          if (not closest) or closest_dist > dist then
            closest_dist = dist
            closest = vector.new(x, y, z)
          end
        end
      end
    end

    if not closest then
      data["mode"] = 2
      calculate_return(data["last_strip_point"])
    else
      data["next_ore_location"] = closest
    end
  end
end

function return_tick()
  if #data["return_path"] == 0 then
    return true
  end

  local next = data["return_path"][1]

  move_towards(next, true)

  return false
end

--NEEDS DEBUGGING
function dropoff()
  local coal_slot
  for i = 1,16 do
    local data = turtle.getItemDetail(i)

    if data then
      turtle.select(i)
      if data.name == "minecraft:coal" then
        if not coal_slot then
          coal_slot = i
        else
          turtle.transferTo(coal_slot)
        end
      end

      data = turtle.getItemDetail()
      if data and (data.name ~= "minecraft:coal" or coal_slot ~= i) then
        turtle.dropDown()
      end
    end
  end
end

function strip_tick()
  if data["strip_dist"] < data["total_strip_dist"] then
    if forward() then
      data["strip_dist"] = data["strip_dist"] + 1
    end
  else
    calculate_strip()
  end
  data["last_strip_point"] = data["coords"]
end

function calculate_strip()
  --Absolute value of distance between current and start, always positive and rotated 90 degrees if strip_direction is East/West
  --In my journal, dh is |c_z-s_z| and dw is |c_x-s_x|
  local dh, dw
  if settings["strip_direction"] % 2 == 0 then
    dh = math.abs(data["coords"].z - settings["dropoff_location"].z)
    dw = math.abs(data["coords"].x - settings["dropoff_location"].x)
  else
    dh = math.abs(data["coords"].x - settings["dropoff_location"].x)
    dw = math.abs(data["coords"].z - settings["dropoff_location"].z)
  end

  --In my notebook, (2w+2)
  local mod_base = 2 * settings["strip_width"] + 2
  
  --Calculate which part of the strip it's on
  local strip_section
  if dh < settings["strip_length"] + settings["start_dist"] and dw % mod_base == 0 then
    strip_section = 0
    data["strip_dist"] = dh - settings["start_dist"]
    data["total_strip_dist"] = settings["strip_length"]
  elseif (dh == settings["strip_length"] + settings["start_dist"] and dw % mod_base <= settings["strip_width"]) or (dh == 1 + settings["start_dist"] and dw % mod_base > settings["strip_width"]) then
    strip_section = 1
    data["strip_dist"] = dw % (settings["strip_width"] + 1)
    data["total_strip_dist"] = settings["strip_width"] + 1
  elseif dh > 1 + settings["start_dist"] and dw % mod_base == settings["strip_width"] + 1 then
    strip_section = 2
    data["strip_dist"] = settings["strip_length"] - dh + 1 + settings["start_dist"]
    data["total_strip_dist"] = settings["strip_length"]
  end

  turn_to(settings["strip_direction"] + strip_section * settings["turn_direction"])
end

function calculate_return(coords)
  data["return_path"] = pathfinding.path(data["coords"], coords, map, walkable)
  save.write_standard_file("/data/data", data)
end

function unpause()
  data["active"] = true

  if data["mode"] == 0 then
    calculate_strip()
  elseif data["mode"] == 1 then

  elseif data["mode"] == 2 then
    calculate_return(data["last_strip_point"])
  elseif data["mode"] == 3 then
    calculate_return(settings["dropoff_location"])
  end
end

function pause()
  data["active"] = false
end

function save_all()
  save.write_standard_file("/data/data", data)
  save.write_map("/data/map", map)
  save.write_map("/data/current_vein", current_vein)
end

function finish_return(at_dropoff)
  if at_dropoff then
    dropoff()
  end

  if data["last_mode"] == 0 then
    data["mode"] = 2
    calculate_return(data["last_strip_point"])
  elseif data["last_mode"] == 1 then
    data["mode"] = 5
    calculate_return(data["next_ore_location"])
  end
  
  if data["pause_after_return"] and at_dropoff then
    pause()
  end
  data["pause_after_return"] = false

  save.write_standard_file("/data/data", data)
end

function return_to_dropoff(pause)
  if data["mode"] == 0 or data["mode"] == 1 or data["mode"] == 2 or data["mode"] == 5 then
    data["pause_after_return"] = pause

    if data["mode"] == 0 or data["mode"] == 1 then
      data["last_mode"] = data["mode"]
    end

    if data["mode"] == 2 then
      data["last_mode"] = 0
    end

    if data["mode"] == 5 then
      data["last_mode"] = 1
    end

    data["mode"] = 3
    calculate_return(settings["dropoff_location"])
  end
end

heading_to_transform = {
  [0] = vector.new(0, 0, -1),
  [1] = vector.new(1, 0, 0),
  [2] = vector.new(0, 0, 1),
  [3] = vector.new(-1, 0, 0)
}

--4 is top, 5 is bottom
side_to_transform = heading_to_transform
side_to_transform[4] = vector.new(0, 1, 0)
side_to_transform[5] = vector.new(0, -1, 0)

ores = save.read_list("/data/ores")
whitelist = save.read_list("/data/whitelist")
walkable = save.read_list("/data/walkable")

--A 3D array referenced by map[x][y][z]
map = save.read_map("/data/map")
current_vein = save.read_map("/data/current_vein")

data = save.read_standard_file("/data/data")
settings = save.read_standard_file("/data/settings")

modem = open()

if gps.locate() then
  data["coords"] = vector.new(gps.locate())
end

if data["active"] then
  unpause()
end

inspect_all()

while true do
  os.startTimer(settings["tick_wait"])

  local event, param1, param2, param3, param4, param5 = os.pullEventRaw()
  if event == "modem_message" then
    local side, frequency, replyFrequency, message, distance = param1, param2, param3, param4, param5
    if frequency == settings["message_frequency"] then
      if message == "PAUSE" and data["active"] then
        pause()
      elseif message == "UNPAUSE" and not data["active"] then
        unpause()
      elseif message == "RETURN" then
        return_to_dropoff(false)
      elseif message == "RETURN_STOP" then
        return_to_dropoff(true)
      elseif message == "CANCEL_RETURN" and data["mode"] == 3 then
        finish_return(false)
      elseif message == "STOP" then
        break
      end
    end

    modem.transmit(replyFrequency, frequency, "RECEIVED")
  elseif event == "terminate" then
    break
  end

  if data["active"] then
    if data["mode"] == 0 then
      strip_tick()
    elseif data["mode"] == 1 then
      vein_tick()
    elseif data["mode"] == 2 then
      if return_tick() then
        calculate_strip()
        data["mode"] = 0
      end
    elseif data["mode"] == 3 then
      if return_tick() then
        data["mode"] = 4
      end
    elseif data["mode"] == 4 then
      finish_return(true)
    elseif data["mode"] == 5 then
      if return_tick() then
        data["mode"] = 1
      end
    end
  end

  save_all()
end

save_all()
