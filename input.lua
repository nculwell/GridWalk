-- vim: nu et ts=2 sts=2 sw=2

local module = {}

local pl = {}
pl.pretty = require("pl.pretty")
pldump = pl.pretty.dump

local moveKeys = {}
local joystick1 = nil
local joystick1Conf = nil

function module.load()
    local joysticks = love.joystick.getJoysticks()
    joystick1 = joysticks[1]
    if joystick1 then
      print("Found joystick: "..joystick1:getID())
      if joystick1:isGamepad() then
        print("Joystick1 is a gamepad.")
      else
        print("Joystick1 is not a gamepad.")
        printf("Joystick1 counts: hats=%d, axes=%d, buttons=%d",
          joystick1:getHatCount(), joystick1:getAxisCount(),
          joystick1:getButtonCount())
        joystick1Conf = {}
        local guid = joystick1:getGUID()
        print("Joystick GUID: "..guid)
        if guid == "79001100000000000000504944564944" then
          print("GUID recognized: SNES style.")
          joystick1Conf = {
            axisLR = 1, axisUD = 5,
            buttonA = 2, buttonB = 3, buttonX = 1, buttonY = 4,
            buttonR = 6, buttonL = 5, buttonStart = 10, buttonSelect = 9,
          }
        end
      end
    else
      print("No joystick found.")
    end
end

function module.keypressed(key)
  if key == "q" then
    print("QUITTING")
    love.event.quit()
  elseif key == "space" then
    paused = not paused
  elseif key == "f" then
    toggleFullscreen()
  elseif key == "up" or key == "down" or key == "left" or key == "right" then
    moveKeys[key] = true
  end
end

function module.gamepadpressed(eventJoystick, eventButton)
  print("JB")
  -- Only pay attention to joystick1.
  if eventJoystick:getID() == joystick1:getID() then
    if eventButton == "dpleft" or eventButton == "dpright"
        or eventButton == "dpup" or eventButton == "dpdown" then
      local direction = strsub(eventButton, 3)
      moveKeys[direction] = true
    end
  end
end

function module.gamepadpressed(eventJoystick, eventButton)
  printf("GamepadPressed: %s %s", eventJoystick, eventButton)
end

function module.joystickpressed(eventJoystick, eventButton)
  printf("JoystickPressed: %s %s", eventJoystick, eventButton)
  local code = ""
  if eventButton == joystick1Conf.buttonA then code = "a"
  elseif eventButton == joystick1Conf.buttonB then code = "b"
  elseif eventButton == joystick1Conf.buttonX then code = "x"
  elseif eventButton == joystick1Conf.buttonY then code = "y"
  elseif eventButton == joystick1Conf.buttonL then code = "l"
  elseif eventButton == joystick1Conf.buttonR then code = "r"
  elseif eventButton == joystick1Conf.buttonSelect then code = "select"
  elseif eventButton == joystick1Conf.buttonStart then code = "start"
  end
  if code ~= "" then
    print("Joystick button: "..code)
  end
end

function module.getMovementCommand()
  local h, w = 0, 0
  local m = moveKeys
  moveKeys = {}
  if love.keyboard.isDown("left") then m["left"] = true end
  if love.keyboard.isDown("right") then m["right"] = true end
  if love.keyboard.isDown("up") then m["up"] = true end
  if love.keyboard.isDown("down") then m["down"] = true end
  if joystick1 then
    if joystick1:isGamepad() then
      if joystick1:isGamepadDown("dpleft") then m["left"] = true end
      if joystick1:isGamepadDown("dpright") then m["right"] = true end
      if joystick1:isGamepadDown("dpup") then m["up"] = true end
      if joystick1:isGamepadDown("dpdown") then m["down"] = true end
    else
      -- TODO: For loop over hats (if any)
      local hatDir = joystick1:getHat(1)
      if hatDir and hatDir ~= "" then
        if hatDir == "l" then m["left"] = true
        elseif hatDir == "r" then m["right"] = true
        elseif hatDir == "u" then m["up"] = true
        elseif hatDir == "d" then m["down"] = true
        elseif hatDir == "lu" then m["left"] = true; m["up"] = true
        elseif hatDir == "ld" then m["left"] = true; m["down"] = true
        elseif hatDir == "ru" then m["right"] = true; m["up"] = true
        elseif hatDir == "rd" then m["right"] = true; m["down"] = true
        elseif hatDir == "c" then
          -- do nothing if hat is centered
        else print("Hat direction unknown: "..hatDir)
        end
      end
      if joystick1Conf and joystick1Conf.axisLR and joystick1Conf.axisUD then
        axisLR = joystick1:getAxis(joystick1Conf.axisLR)
        axisUD = joystick1:getAxis(joystick1Conf.axisUD)
        if axisLR == -1 then m["left"] = true end
        if axisLR ==  1 then m["right"] = true end
        if axisUD == -1 then m["up"] = true end
        if axisUD ==  1 then m["down"] = true end
      end
    end
  end
  if m["left"] then w = w - 1 end
  if m["right"] then w = w + 1 end
  if m["up"] then h = h - 1 end
  if m["down"] then h = h + 1 end
  local moveCmd = {
    dst = CxSize(w, h),
    isMoved = not (w == 0 and h == 0),
  }
  return moveCmd
end

return module

