os.loadAPI("/save")

function open()
  local modemSide
  local monitorSide

  for _,side in pairs(redstone.getSides()) do
    if peripheral.getType(side) == "modem" and not modemSide then
      modemSide = side
    elseif peripheral.getType(side) == "monitor" and not monitorSide then
      monitorSide = side
    end
  end

  local mod = peripheral.wrap(modemSide)
  for k,v in pairs(robot_list) do
    mod.open(v+1)
  end

  local mon = peripheral.wrap(monitorSide)
  --term.redirect(mon)

  return mod, mon
end

function reset_colors()
  monitor.setTextColor(colors.white)
  monitor.setBackgroundColor(colors.black)
end

function button(x1, y1, x2, y2, func, is_cond, remove_after)
  current_button_id = current_button_id + 1

  --A button is conditional if only clickable with no outgoing messages

  local obj = {
    start = {
      x = x1,
      y = y1
    },
    stop = {
      x = x2,
      y = y2
    },
    width = x2 - x1,
    height = y2 - y1,
    onclick = func,
    conditional = is_cond,
    remove = remove_after,
    id = current_button_id
  }

  table.insert(buttons, obj)
end

function change_robot()
  robot_index = robot_index + 1
  if robot_index > #robot_list then
    robot_index = 1
  end

  show_robot()
end

function text_button(x, y, text, func, is_cond, remove_after, leading_text)
  leading_text = leading_text or ""

  monitor.setCursorPos(x, y)

  monitor.write(leading_text)

  local buttonStartX, buttonStartY = monitor.getCursorPos()

  monitor.setTextColor(colors.black)
  monitor.setBackgroundColor(colors.white)
  monitor.write(text)

  local buttonEndX, buttonEndY = monitor.getCursorPos()

  button(buttonStartX, buttonStartY, buttonEndX, buttonEndY, func, is_cond, remove_after)

  reset_colors()
end

function show_status()
  monitor.setCursorPos(18, 4)
  monitor.write("Status:")

  monitor.setCursorPos(18, 5)
  if current_msgs[robot_list[robot_index]] then
    monitor.setTextColor(colors.red)
    monitor.write("Sending...")
  else
    monitor.setTextColor(colors.green)
    monitor.write("Ready     ")
  end

  reset_colors()
end

function show_robot()
  text_button(2, 1, robot_list[robot_index], change_robot, false, true, "Robot Frequency: ")
  monitor.write("                 ")
end

function click_button(button)
  button.onclick()

  if button.remove then
    for k,b in pairs(buttons) do
      if b == button then
        table.remove(buttons, k)
        return
      end
    end
  end
end

function handle_buttons(x, y)
  for _,b in ipairs(buttons) do
    if x >= b.start.x and x <= b.stop.x and y >= b.start.y and y <= b.stop.y then
      if b.conditional then
        if current_msgs[robot_list[robot_index]] == nil then
          click_button(b)
        end
      else
        click_button(b)
      end
    end
  end
end

function exit()
  running = false
end

function send_messages()
  for f,m in pairs(current_msgs) do
    modem.transmit(f, f + 1, m)
  end
  os.sleep(settings.send_wait)
end

function events()
  os.startTimer(settings.receive_wait)

  local event, param1, param2, param3, param4, param5 = os.pullEventRaw()

  if event == "terminate" then
    running = false
  elseif event == "monitor_touch" then
    local xPos, yPos = param2, param3
    handle_buttons(xPos, yPos)
  elseif event == "modem_message" then
    local side, frequency, replyFrequency, message, distance = param1, param2, param3, param4, param5

    if message == "RECEIVED" and current_msgs[replyFrequency] then
      current_msgs[replyFrequency] = nil
      show_status()
    end
  end
end

function cancel()
  current_msgs[robot_list[robot_index]] = nil
  show_status()
end

messages = {
  pause = function()
    current_msgs[robot_list[robot_index]] = "PAUSE"
    show_status()
  end,
  unpause = function()
    current_msgs[robot_list[robot_index]] = "UNPAUSE"
    show_status()
  end,
  ret = function()
    current_msgs[robot_list[robot_index]] = "RETURN"
    show_status()
  end,
  ret_stop = function()
    current_msgs[robot_list[robot_index]] = "RETURN_STOP"
    show_status()
  end,
  cancel_return = function()
    current_msgs[robot_list[robot_index]] = "CANCEL_RETURN"
    show_status()
  end,
  stop = function()
    current_msgs[robot_list[robot_index]] = "STOP"
    show_status()
  end
}

robot_list = save.read_list("/data/robot_list", true)
settings = save.read_standard_file("/data/settings")

robot_index = 1

modem, monitor = open()

reset_colors()
monitor.setTextScale(1)
monitor.clear()

buttons = {}
current_button_id = 0

show_robot()

--text_button(x, y, text, func, is_cond, remove_after, leading_text)
text_button(2, 3, "Pause", messages.pause, true, false)
text_button(2, 5, "Resume", messages.unpause, true, false)
text_button(2, 7, "Return", messages.ret, true, false)
text_button(2, 9, "Return then Pause", messages.ret_stop, true, false)
text_button(2, 11, "Cancel Return", messages.cancel_return, true, false)
text_button(9, 7, "Cancel Last Message", cancel, false, false)
--text_button(10, 5, "OFF", exit, false, false)

current_msgs = {}

show_status()

running = true
while running do
  parallel.waitForAll(events, send_messages)
end

monitor.setBackgroundColor(colors.black)
monitor.clear()