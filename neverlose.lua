local nlui = {}
nlui.__index = nlui
nlui.version = "2.0.0"
nlui.dropdownMax = 6

local draw, color = draw, color
if type(draw) ~= "table" or type(color) ~= "table" then
  error("nlui: the draw and color APIs must exist before loading the library")
end

local floor, max, min, abs, exp, sin, cos, rad = math.floor, math.max, math.min, math.abs, math.exp, math.sin, math.cos, math.rad
local ssub, sfind, slower, supper, sformat, sgsub = string.sub, string.find, string.lower, string.upper, string.format, string.gsub
local insert, remove, concat, sort = table.insert, table.remove, table.concat, table.sort
local unpack = unpack or table.unpack
local loadfn = loadstring or load
local G = _G or _ENV or {}

local function now()
  local t = rawget(G, "time")
  if type(t) == "table" and type(t.now) == "function" then
    local ok, v = pcall(t.now)
    if ok and type(v) == "number" then return v end
  end
  local o = rawget(G, "os")
  if type(o) == "table" and type(o.clock) == "function" then return o.clock() end
  return nil
end

local function screenSize()
  local ok, w, h = pcall(draw.GetScreenSize)
  if ok and type(w) == "number" and type(h) == "number" then return w, h end
  return 1920, 1080
end

local function fileApi()
  local f = rawget(G, "file")
  if type(f) == "table" and type(f.read) == "function" and type(f.write) == "function" then return f end
  return nil
end

local function clamp(v, a, b)
  if v < a then return a elseif v > b then return b end
  return v
end

local function rgb(r, g, b) return color.rgba(r, g, b, 255) end

local theme = {
  font = "Verdana",
  menuBg = rgb(15, 16, 20),
  bgAlpha = 234,
  sheenAlpha = 7,
  card = rgb(22, 23, 28),
  cardAlpha = 244,
  rowHover = rgb(28, 29, 35),
  control = rgb(37, 39, 46),
  controlHover = rgb(45, 47, 55),
  text = rgb(227, 228, 232),
  navText = rgb(200, 202, 208),
  muted = rgb(139, 141, 149),
  icon = rgb(154, 156, 164),
  chev = rgb(213, 214, 218),
  blue = rgb(63, 126, 247),
  green = rgb(78, 214, 120),
  red = rgb(226, 72, 72),
  white = rgb(255, 255, 255),
  black = rgb(0, 0, 0),
  toggleTrack = rgb(13, 14, 18),
  toggleKnob = rgb(227, 228, 232),
  logoBg = rgb(255, 255, 255),
  logoFg = rgb(20, 22, 51),
  activeItem = rgb(34, 36, 42),
  popup = rgb(30, 32, 38),
  popupAlpha = 250,
  danger = rgb(224, 107, 107),
  avatar = rgb(179, 37, 44),
  avatarDark = rgb(42, 20, 22),
  panelBg = rgb(17, 18, 23),
  panelAlpha = 236,
  espTop = rgb(28, 31, 42),
  espBottom = rgb(15, 16, 22),
  figure = rgb(58, 64, 82),
  figureLight = rgb(84, 92, 116),
  lineAlpha = 9,
  borderAlpha = 11,
  popupBorderAlpha = 18,
  hoverAlpha = 8,
}
nlui.theme = theme

nlui.keymap = {}
nlui.input = {
  mouse = function() return -1, -1 end,
  down = function(button) return false end,
  key = function(name) return false end,
  wheel = function() return 0 end,
}

function nlui.bind(adapter)
  for k, v in pairs(adapter) do nlui.input[k] = v end
end

local function probe(tbl, names)
  for _, n in ipairs(names) do
    local ok, f = pcall(function() return tbl[n] end)
    if ok and type(f) == "function" then return f end
  end
end

local EVE_BUTTONS = { [1] = "left", [2] = "right", [3] = "middle", [4] = "x1", [5] = "x2" }
local EVE_KEYS = { Space = "space", Backspace = "backspace", Enter = "enter", Escape = "escape", Tab = "tab", Shift = "shift", Ctrl = "ctrl", Alt = "alt", Insert = "insert", Delete = "delete", Home = "home", End = "end", Up = 38, Down = 40, Left = 37, Right = 39, ["."] = 190, ["-"] = 189 }

function nlui.autobind()
  local mouseApi, kb = rawget(G, "mouse"), rawget(G, "keyboard")
  if type(mouseApi) == "table" and type(kb) == "table" and type(mouseApi.GetPosition) == "function" and type(kb.IsPressed) == "function" then
    nlui.input.mouse = function() return mouseApi.GetPosition() end
    nlui.input.down = function(b)
      local n = EVE_BUTTONS[b]
      if not n then return false end
      return mouseApi.IsPressed(n) == true
    end
    nlui.input.key = function(k)
      local n = EVE_KEYS[k]
      if n == nil then n = type(k) == "string" and slower(k) or k end
      return kb.IsPressed(n) == true
    end
    if type(mouseApi.GetWheelDelta) == "function" then
      nlui.input.wheel = function()
        local v = mouseApi.GetWheelDelta()
        return type(v) == "number" and v or 0
      end
    end
    nlui.bound = "eve"
    return true
  end
  local inp = rawget(G, "input") or rawget(G, "Input")
  if type(inp) ~= "table" then return false end
  local m = probe(inp, { "GetMousePos", "GetCursorPos", "get_mouse_pos", "mouse_position", "GetMousePosition" })
  local d = probe(inp, { "IsMouseDown", "IsButtonDown", "is_mouse_down", "mouse_down", "IsMouseButtonDown" })
  local k = probe(inp, { "IsKeyDown", "is_key_down", "key_down", "IsKeyPressed" })
  if m then nlui.input.mouse = function() return m() end end
  if d then nlui.input.down = function(b) return d(b) end end
  if k then nlui.input.key = function(n) return k(n) end end
  if m then nlui.bound = "input" end
  return m ~= nil
end

function nlui.menuState()
  local c = rawget(G, "cheat")
  if type(c) == "table" and type(c.GetMenuState) == "function" then
    local ok, v = pcall(c.GetMenuState)
    if ok and type(v) == "boolean" then return v end
  end
  local u = rawget(G, "ui")
  if type(u) == "table" and type(u.menu_open) == "function" then
    local ok, v = pcall(u.menu_open)
    if ok and type(v) == "boolean" then return v end
  end
  return nil
end

nlui.pollKeys = {}
do
  local letters, digits = "ABCDEFGHIJKLMNOPQRSTUVWXYZ", "0123456789"
  for i = 1, #letters do nlui.pollKeys[#nlui.pollKeys + 1] = ssub(letters, i, i) end
  for i = 1, #digits do nlui.pollKeys[#nlui.pollKeys + 1] = ssub(digits, i, i) end
  local rest = { ".", "-", "Space", "Backspace", "Enter", "Escape", "Tab", "Shift", "Ctrl", "Alt", "Insert", "Delete", "Home", "End", "Up", "Down", "Left", "Right",
    "Mouse1", "Mouse2", "Mouse3", "Mouse4", "Mouse5", "F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12" }
  for _, k in ipairs(rest) do nlui.pollKeys[#nlui.pollKeys + 1] = k end
end

local baseH
local mcache, mcount = {}, 0
local function measure(t, size)
  if not baseH then
    local ok, w, h = pcall(draw.GetTextSize, "Ag", theme.font)
    baseH = (ok and type(h) == "number" and h > 0) and h or 13
  end
  local key = t .. "\1" .. size
  local c = mcache[key]
  if c then return c[1], c[2] end
  local ok, w, h = pcall(draw.GetTextSize, t, theme.font)
  if not ok or type(w) ~= "number" then w, h = #t * baseH * 0.55, baseH end
  local k = size / baseH
  if mcount > 4000 then mcache, mcount = {}, 0 end
  mcache[key] = { w * k, (h or baseH) * k }
  mcount = mcount + 1
  return w * k, (h or baseH) * k
end
nlui.measure = measure

local galpha = 1
local function A(a)
  return floor((a or 255) * galpha + 0.5)
end

local function easeOut(p)
  p = 1 - p
  return 1 - p * p * p
end

local mixCache = {}
local function mix(c1, c2, t)
  if t <= 0.001 then return c1 end
  if t >= 0.999 then return c2 end
  if type(color.unpack) ~= "function" then return t < 0.5 and c1 or c2 end
  local q = floor(t * 32 + 0.5)
  local key = c1 .. "|" .. c2 .. "|" .. q
  local c = mixCache[key]
  if c then return c end
  local r1, g1, b1 = color.unpack(c1)
  local r2, g2, b2 = color.unpack(c2)
  local f = q / 32
  c = color.rgba(floor(r1 + (r2 - r1) * f + 0.5), floor(g1 + (g2 - g1) * f + 0.5), floor(b1 + (b2 - b1) * f + 0.5), 255)
  mixCache[key] = c
  return c
end
nlui.mix = mix

local function text(t, x, y, col, size, a)
  local al = A(a)
  if al <= 0 then return end
  if draw.text then
    draw.text(t, floor(x), floor(y), col, floor(size + 0.5), al)
  else
    draw.Text(t, floor(x), floor(y), col, theme.font, al)
  end
end

local function textC(t, x, cy, col, size, a)
  local _, h = measure(t, size)
  text(t, x, cy - h / 2, col, size, a)
end

local function textShadow(t, x, cy, col, size, a)
  textC(t, x + 1, cy + 1, theme.black, size, (a or 255) * 0.8)
  textC(t, x, cy, col, size, a)
end

local function fit(t, maxW, size)
  if measure(t, size) <= maxW then return t end
  local n = #t
  while n > 0 do
    n = n - 1
    local sub = ssub(t, 1, n)
    if measure(sub, size) <= maxW then return sub end
  end
  return ""
end

local function rect(x, y, w, h, col, r, a)
  local al = A(a)
  if al <= 0 or w <= 0 or h <= 0 then return end
  draw.RectFilled(floor(x), floor(y), floor(w + 0.5), floor(h + 0.5), col, r or 0, al)
end

local function outline(x, y, w, h, col, r, a, t)
  local al = A(a)
  if al <= 0 or w <= 0 or h <= 0 then return end
  draw.Rect(floor(x), floor(y), floor(w + 0.5), floor(h + 0.5), col, t or 1, r or 0, al)
end

local function line(x1, y1, x2, y2, col, t, a)
  local al = A(a)
  if al <= 0 then return end
  draw.Line(x1, y1, x2, y2, col, t or 1, al)
end

local function circle(x, y, r, col, a)
  local al = A(a)
  if al <= 0 or r <= 0 then return end
  draw.CircleFilled(x, y, r, col, 0, al)
end

local function ring(x, y, r, col, t, a)
  local al = A(a)
  if al <= 0 or r <= 0 then return end
  draw.Circle(x, y, r, col, t or 1, 0, al)
end

local function poly(points, col, closed, t, a)
  local al = A(a)
  if al <= 0 then return end
  draw.Polyline(points, col, closed or false, t or 1, al)
end

local function polyFill(points, col, a)
  local al = A(a)
  if al <= 0 then return end
  draw.ConvexPolyFilled(points, col, al)
end

local function gradient(x, y, w, h, c1, c2, horizontal, a1, a2)
  if type(draw.Gradient) ~= "function" then
    rect(x, y, w, h, c1, 0, a1)
    return
  end
  local al1, al2 = A(a1), A(a2)
  if (al1 <= 0 and al2 <= 0) or w <= 0 or h <= 0 then return end
  pcall(draw.Gradient, floor(x), floor(y), floor(w + 0.5), floor(h + 0.5), c1, c2, horizontal or false, al1, al2)
end

local function shadow(x, y, w, h, r, strength)
  strength = strength or 1
  for i = 6, 1, -1 do
    local sp = i * 3
    rect(x - sp, y - sp + i * 1.5, w + sp * 2, h + sp * 2, theme.black, r + sp, (19 - i * 2) * strength)
  end
end

local function copy(v)
  if type(v) ~= "table" then return v end
  local t = {}
  for k, x in pairs(v) do t[k] = copy(x) end
  return t
end

function nlui.loadImage(src)
  local holder = { id = nil, src = src }
  if type(src) == "number" then holder.id = src return holder end
  if type(src) ~= "string" or src == "" then return holder end
  local ut, im = rawget(G, "utility"), rawget(G, "image")
  local decode
  if type(ut) == "table" and type(ut.LoadImage) == "function" then decode = ut.LoadImage
  elseif type(im) == "table" and type(im.load) == "function" then decode = im.load end
  if not decode then return holder end
  local function finish(bytes)
    if type(bytes) ~= "string" or #bytes == 0 then return end
    local ok, id = pcall(decode, bytes)
    if ok and id ~= nil then holder.id = id end
  end
  if sfind(src, "^https?://") then
    local h = rawget(G, "http")
    if type(h) == "table" and type(h.Get) == "function" then
      pcall(h.Get, src, nil, finish)
    end
  else
    local f = fileApi()
    if f then
      local ok, bytes = pcall(f.read, src)
      if ok then finish(bytes) end
    end
  end
  return holder
end

local function imageReady(holder)
  if type(holder) ~= "table" or holder.id == nil then return false end
  local im = rawget(G, "image")
  if type(im) == "table" and type(im.ready) == "function" then
    local ok, r = pcall(im.ready, holder.id)
    return ok and r == true
  end
  return true
end

local function drawImage(holder, x, y, w, h, a)
  local al = A(a)
  if al <= 0 or type(draw.Image) ~= "function" then return end
  pcall(draw.Image, holder.id, floor(x), floor(y), floor(w + 0.5), floor(h + 0.5), 255, 255, 255, al)
end

local icons = {}
nlui.icons = icons

icons.crosshair = function(x, y, sz, col)
  local t = max(1, sz * 0.09)
  ring(x, y, sz * 0.33, col, t)
  line(x, y - sz / 2, x, y - sz * 0.33, col, t)
  line(x, y + sz * 0.33, x, y + sz / 2, col, t)
  line(x - sz / 2, y, x - sz * 0.33, y, col, t)
  line(x + sz * 0.33, y, x + sz / 2, y, col, t)
end

icons.mouse = function(x, y, sz, col)
  local w, h = sz * 0.54, sz * 0.84
  rect(x - w / 2, y - h / 2, w, h, col, w / 2)
  rect(x - sz * 0.04, y - h / 2 + sz * 0.16, sz * 0.08, sz * 0.16, theme.activeItem, sz * 0.04)
end

icons.image = function(x, y, sz, col)
  local t = max(1, sz * 0.09)
  local w = sz * 0.76
  outline(x - w / 2, y - w / 2, w, w, col, sz * 0.12, 255, t)
  circle(x - w / 2 + sz * 0.23, y - w / 2 + sz * 0.23, sz * 0.07, col)
  poly({ { x - w / 2 + sz * 0.08, y + w / 2 - sz * 0.04 }, { x + sz * 0.1, y - sz * 0.06 }, { x + w / 2 - sz * 0.04, y + sz * 0.18 } }, col, false, t)
end

icons.layers = function(x, y, sz, col)
  local t = max(1, sz * 0.09)
  local w, hh = sz * 0.42, sz * 0.2
  local cy = y - sz * 0.2
  poly({ { x - w, cy }, { x, cy - hh }, { x + w, cy }, { x, cy + hh } }, col, true, t)
  poly({ { x - w, y }, { x, y + hh }, { x + w, y } }, col, false, t)
  poly({ { x - w, y + sz * 0.2 }, { x, y + sz * 0.2 + hh }, { x + w, y + sz * 0.2 } }, col, false, t)
end

icons.misc = function(x, y, sz, col)
  local t = max(1, sz * 0.09)
  local w, h = sz * 0.76, sz * 0.66
  outline(x - w / 2, y - h / 2, w, h, col, sz * 0.12, 255, t)
  line(x - sz * 0.2, y - sz * 0.15, x + sz * 0.2, y - sz * 0.15, col, t)
  line(x - sz * 0.2, y, x + sz * 0.2, y, col, t)
  line(x - sz * 0.2, y + sz * 0.15, x + sz * 0.02, y + sz * 0.15, col, t)
end

icons.eye = function(x, y, sz, col)
  local t = max(1, sz * 0.09)
  local pts = {}
  for i = 0, 10 do
    local f = i / 10
    pts[#pts + 1] = { x - sz * 0.45 + f * sz * 0.9, y - sin(f * 3.14159) * sz * 0.28 }
  end
  poly(pts, col, false, t)
  for i = 0, 10 do
    local f = i / 10
    pts[i + 1] = { x - sz * 0.45 + f * sz * 0.9, y + sin(f * 3.14159) * sz * 0.28 }
  end
  poly(pts, col, false, t)
  circle(x, y, sz * 0.12, col)
end

icons.save = function(x, y, sz, col)
  local w = sz * 0.84
  rect(x - w / 2, y - w / 2, w, w, col, sz * 0.08)
  rect(x - sz * 0.22, y - w / 2 + sz * 0.05, sz * 0.4, sz * 0.2, theme.card)
  rect(x - sz * 0.26, y + sz * 0.06, sz * 0.52, sz * 0.26, theme.card, sz * 0.03)
  rect(x + sz * 0.06, y - w / 2 + sz * 0.05, sz * 0.08, sz * 0.14, col)
end

icons.note = function(x, y, sz, col)
  local t = max(1.5, sz * 0.12)
  circle(x - sz * 0.16, y + sz * 0.24, sz * 0.17, col)
  line(x, y + sz * 0.24, x, y - sz * 0.42, col, t)
  poly({ { x, y - sz * 0.42 }, { x + sz * 0.1, y - sz * 0.26 }, { x + sz * 0.3, y - sz * 0.16 } }, col, false, t)
end

icons.chevron_down = function(x, y, sz, col, up)
  local t = max(1.5, sz * 0.13)
  local w, h = sz * 0.3, sz * 0.16
  if type(up) == "number" then h = h * (1 - 2 * up) elseif up then h = -h end
  line(x - w, y - h / 2, x, y + h / 2, col, t)
  line(x, y + h / 2, x + w, y - h / 2, col, t)
end

icons.chevron_right = function(x, y, sz, col)
  local t = max(1.5, sz * 0.13)
  local w, h = sz * 0.16, sz * 0.3
  line(x - w / 2, y - h, x + w / 2, y, col, t)
  line(x + w / 2, y, x - w / 2, y + h, col, t)
end

icons.search = function(x, y, sz, col)
  local t = max(1.5, sz * 0.1)
  ring(x - sz * 0.08, y - sz * 0.08, sz * 0.3, col, t)
  line(x + sz * 0.14, y + sz * 0.14, x + sz * 0.38, y + sz * 0.38, col, t)
end

icons.dots = function(x, y, sz, col)
  local r = sz * 0.14
  circle(x - sz * 0.36, y, r, col)
  circle(x, y, r, col)
  circle(x + sz * 0.36, y, r, col)
end

icons.check = function(x, y, sz, col)
  poly({ { x - sz * 0.32, y }, { x - sz * 0.08, y + sz * 0.26 }, { x + sz * 0.36, y - sz * 0.3 } }, col, false, max(1.5, sz * 0.16))
end

icons.circle = function(x, y, sz, col)
  circle(x, y, sz * 0.34, col)
end

icons.grip = function(x, y, sz, col)
  local t = max(1, sz * 0.09)
  line(x - sz * 0.4, y + sz * 0.4, x + sz * 0.4, y - sz * 0.4, col, t)
  line(x - sz * 0.1, y + sz * 0.4, x + sz * 0.4, y - sz * 0.1, col, t)
  line(x + sz * 0.2, y + sz * 0.4, x + sz * 0.4, y + sz * 0.2, col, t)
end

local FULL = { rowH = 63, font = 20, ddH = 40, ddR = 10, ddFont = 19, ddPadL = 10, ddPadR = 12, chev = 16, togW = 55, togH = 28, knob = 24, sKnob = 22, sGap = 17, valH = 34, valPad = 13, valFont = 16, valR = 8, keyH = 40, keyMin = 96, keyPad = 12, keyFont = 17, keyR = 10, sw = 40, swR = 10, dots = 16, dotsGap = 20, itemH = 39, itemFont = 17, itemPad = 10, itemR = 7, padL = 22, padR = 23 }
local COMPACT = { rowH = 48, font = 16, ddH = 34, ddR = 8, ddFont = 15, ddPadL = 9, ddPadR = 9, chev = 14, togW = 44, togH = 24, knob = 20, sKnob = 16, sGap = 10, valH = 28, valPad = 9, valFont = 14, valR = 6, keyH = 34, keyMin = 80, keyPad = 10, keyFont = 15, keyR = 8, sw = 34, swR = 8, dots = 14, dotsGap = 14, itemH = 32, itemFont = 14, itemPad = 8, itemR = 6, padL = 14, padR = 14 }

local function scaled(tbl, s)
  local out = {}
  for k, v in pairs(tbl) do out[k] = v * s end
  return out
end

local Item = {}
Item.__index = Item

local Container = {}
Container.__index = Container

local Tab = {}
Tab.__index = Tab

local function newContainer(menu, title, single)
  return setmetatable({ menu = menu, title = title, single = single, items = {} }, Container)
end

local function sortedCopy(list)
  local t = {}
  for i, v in ipairs(list) do t[i] = v end
  sort(t, function(a, b) return slower(tostring(a)) < slower(tostring(b)) end)
  return t
end

local function newItem(c, t, id, label, default, fields)
  if c.menu.items[id] then error("nlui: duplicate item id '" .. tostring(id) .. "'") end
  local item = { t = t, id = id, label = label, v = default, menu = c.menu }
  if fields then for k, v in pairs(fields) do item[k] = v end end
  if item.options then item.sorted = sortedCopy(item.options) end
  setmetatable(item, Item)
  c.menu.items[id] = item
  c.items[#c.items + 1] = item
  return item
end

function Item:extra(fn)
  self.sub = self.sub or newContainer(self.menu)
  fn(self.sub)
  return self
end

function Item:get() return self.menu:get(self.id) end
function Item:set(v) return self.menu:set(self.id, v) end
function Item:on(fn) return self.menu:on(self.id, fn) end

function Container:toggle(id, label, default)
  return newItem(self, "toggle", id, label, default and true or false)
end

function Container:dropdown(id, label, options, default)
  return newItem(self, "dropdown", id, label, default or options[1], { options = options })
end

function Container:multiselect(id, label, options, default)
  return newItem(self, "multi", id, label, sortedCopy(default or { options[1] }), { options = options })
end

function Container:slider(id, label, mn, mx, default, unit, zero)
  return newItem(self, "slider", id, label, default or mn, { min = mn, max = mx, unit = unit or "", zero = zero })
end

function Container:keybind(id, label, default)
  return newItem(self, "keybind", id, label, default or "")
end

function Container:color(id, label, default)
  return newItem(self, "color", id, label, default or { 255, 255, 255, 255 })
end

function Tab:section(side, title, single)
  local sec = newContainer(self.menu, title, single)
  local col = (side == "right") and 2 or 1
  local list = self.columns[col]
  list[#list + 1] = sec
  return sec
end

function nlui.new(opts)
  opts = opts or {}
  local m = setmetatable({}, nlui)
  m.x, m.y = opts.x or 25, opts.y or 45
  m.w, m.h = opts.w or 1300, opts.h or 985
  m.minW, m.minH = opts.minW or 900, opts.minH or 620
  m.scale = opts.scale or 1
  m.title = opts.title or "Alpine"
  m.subtitle = opts.subtitle or "Counter-Strike 2"
  m.logo = opts.logo or "A"
  m.logoImage = opts.logoImage
  m.avatarImage = opts.avatarImage
  m.user = opts.user or "User"
  m.userSub = opts.userSub or ""
  m.toggleKey = opts.toggleKey or "M"
  m.open = opts.visible ~= false
  m.visible = m.open
  m.alpha = m.open and 1 or 0
  m.anims, m.closing, m.panels = {}, {}, {}
  m.now, m.dt, m.fps = 0, 1 / 60, 0
  m.fadeSpeed = opts.fadeSpeed or 14
  local found = false
  for _, k in ipairs(nlui.pollKeys) do if k == m.toggleKey then found = true end end
  if not found then nlui.pollKeys[#nlui.pollKeys + 1] = m.toggleKey end
  m.groups, m.items, m.listeners = {}, {}, {}
  m.config = opts.config or "Default"
  m.configs = { [m.config] = { Global = {} } }
  m.weaponGroups = opts.weaponGroups or { "Global", "Pistols", "Heavy Pistols", "SMGs", "Rifles", "Snipers", "Auto Snipers", "Shotguns", "Machine Guns" }
  m.group = "Global"
  m.popups = {}
  m.justClosed = {}
  m.search = ""
  m.frame = 0
  m.keyPrev, m.keyNow, m.pressedKeys, m.pressedSet = {}, {}, {}, {}
  m.onSave = opts.onSave
  m.file = opts.file
  m.followMenu = opts.followMenu == true
  m.mx, m.my = -1, -1
  m.wheel = 0
  return m
end

function nlui:navGroup(name)
  for _, g in ipairs(self.groups) do if g.name == name then return g end end
  local g = { name = name, tabs = {} }
  self.groups[#self.groups + 1] = g
  return g
end

function nlui:tab(groupName, name, icon)
  local g = self:navGroup(groupName)
  local tab = setmetatable({ name = name, icon = icon or "circle", id = slower(name), columns = { {}, {} }, menu = self, scroll = 0, scrollTarget = 0, maxScroll = 0 }, Tab)
  g.tabs[#g.tabs + 1] = tab
  if not self.tab then self.tab = tab end
  return tab
end

function nlui:setTab(tab)
  if self.tab ~= tab then
    self.tab = tab
    self.tabT0 = self.now
    self:closeAll()
    self.editing = nil
  end
  return tab
end

function nlui:selectTab(name)
  for _, g in ipairs(self.groups) do
    for _, t in ipairs(g.tabs) do
      if t.name == name or t.id == name then return self:setTab(t) end
    end
  end
end

function nlui:anim(key, target, speed, init)
  local a = self.anims[key]
  if a == nil then
    a = init
    if a == nil then a = target end
    self.anims[key] = a
    return a
  end
  local k = 1 - exp(-self.dt * (speed or 16))
  a = a + (target - a) * k
  if abs(target - a) < 0.0015 then a = target end
  self.anims[key] = a
  return a
end

function nlui:setOpen(v) self.open = v and true or false end
function nlui:show() self:setOpen(true) end
function nlui:hide() self:setOpen(false) end
function nlui:toggle() self:setOpen(not self.open) end

function nlui:bucket()
  local c = self.configs[self.config]
  if not c then c = { Global = {} } self.configs[self.config] = c end
  if not c.Global then c.Global = {} end
  local g = c[self.group]
  if not g then
    g = copy(c.Global)
    c[self.group] = g
  end
  return g
end

function nlui:get(id)
  local v = self:bucket()[id]
  if v == nil then
    local it = self.items[id]
    if not it then return nil end
    return it.v
  end
  return v
end

function nlui:set(id, v)
  self:bucket()[id] = v
  local l = self.listeners[id]
  if l then for _, fn in ipairs(l) do fn(v, id) end end
end

function nlui:on(id, fn)
  local l = self.listeners[id]
  if not l then l = {} self.listeners[id] = l end
  l[#l + 1] = fn
  return fn
end

function nlui:keyDown(id)
  local k = self:get(id)
  if not k or k == "" then return false end
  return self.keyNow[k] == true
end

function nlui:keyPressed(id)
  local k = self:get(id)
  if not k or k == "" then return false end
  return self.pressedSet[k] == true
end

function nlui:selected(id, option)
  local v = self:get(id)
  if type(v) ~= "table" then return v == option end
  for _, o in ipairs(v) do if o == option then return true end end
  return false
end

function nlui:packedColor(id, fallback)
  local c = self:get(id)
  if type(c) ~= "table" then return fallback or theme.white end
  return color.rgba(c[1], c[2], c[3], 255), c[4] or 255
end

function nlui:configNames()
  local names = {}
  for n in pairs(self.configs) do names[#names + 1] = n end
  sort(names)
  return names
end

function nlui:switchConfig(name)
  if not self.configs[name] then return false end
  self.config = name
  self:bucket()
  self:closeAll()
  return true
end

function nlui:createConfig(name)
  if self.configs[name] then self:toast("A config named " .. name .. " already exists") return false end
  self.configs[name] = { Global = {} }
  self:switchConfig(name)
  self:toast("Created " .. name)
  return true
end

function nlui:duplicateConfig()
  local base = self.config
  local n, i = base .. " copy", 2
  while self.configs[n] do n = base .. " copy " .. i i = i + 1 end
  self.configs[n] = copy(self.configs[base])
  self:switchConfig(n)
  self:toast("Created " .. n)
end

function nlui:deleteConfig()
  local names = self:configNames()
  if #names < 2 then return false end
  local old = self.config
  self.configs[old] = nil
  self:switchConfig(self:configNames()[1])
  self:toast("Deleted " .. old)
  return true
end

function nlui:setGroup(name)
  self.group = name
  self:bucket()
  self:closeAll()
end

local function ser(v)
  local t = type(v)
  if t == "string" then return sformat("%q", v) end
  if t == "number" or t == "boolean" then return tostring(v) end
  if t == "table" then
    local parts = {}
    if #v > 0 then
      for _, x in ipairs(v) do parts[#parts + 1] = ser(x) end
    else
      for k, x in pairs(v) do parts[#parts + 1] = "[" .. sformat("%q", tostring(k)) .. "]=" .. ser(x) end
    end
    return "{" .. concat(parts, ",") .. "}"
  end
  return "nil"
end

function nlui:serialize()
  local panels = {}
  for _, p in ipairs(self.panels) do panels[p.id] = { x = p.x, y = p.y } end
  return "return " .. ser({ version = nlui.version, config = self.config, group = self.group, configs = self.configs, window = { x = self.x, y = self.y, w = self.w, h = self.h }, panels = panels })
end

function nlui:load(str)
  if type(str) ~= "string" or not loadfn then return false end
  local f = loadfn(str)
  if not f then return false end
  local ok, data = pcall(f)
  if not ok or type(data) ~= "table" or type(data.configs) ~= "table" then return false end
  self.configs = data.configs
  if data.config and self.configs[data.config] then self.config = data.config else self.config = self:configNames()[1] or "Default" end
  if data.group then self.group = data.group end
  if type(data.window) == "table" then
    if type(data.window.x) == "number" then self.x = data.window.x end
    if type(data.window.y) == "number" then self.y = data.window.y end
    if type(data.window.w) == "number" then self.w = max(self.minW, data.window.w) end
    if type(data.window.h) == "number" then self.h = max(self.minH, data.window.h) end
  end
  if type(data.panels) == "table" then
    for _, p in ipairs(self.panels) do
      local d = data.panels[p.id]
      if type(d) == "table" and type(d.x) == "number" and type(d.y) == "number" then p.x, p.y = d.x, d.y end
    end
  end
  self:bucket()
  return true
end

function nlui:saveFile(path)
  path = path or self.file
  local f = fileApi()
  if not path or not f then return false end
  local dir = string.match(path, "^(.*)/[^/]+$")
  if dir and type(f.mkdir) == "function" then pcall(f.mkdir, dir) end
  local ok = pcall(f.write, path, self:serialize())
  return ok == true
end

function nlui:loadFile(path)
  path = path or self.file
  local f = fileApi()
  if not path or not f then return false end
  local ok, str = pcall(f.read, path)
  if ok and type(str) == "string" and str ~= "" then return self:load(str) end
  return false
end

function nlui:save()
  self.saveFlash = self.frame + 25
  if self.onSave then
    local ok = pcall(self.onSave, self.config, self:serialize(), self)
    self:toast(ok and ("Saved " .. self.config) or "Save hook failed")
  elseif self.file then
    self:toast(self:saveFile() and ("Saved " .. self.config) or "Could not write config file")
  else
    self:toast("Saved " .. self.config)
  end
end

function nlui:toast(msg)
  self.toastText = msg
  self.toastStart = self.now
  self.toastUntil = self.now + 1.8
end

function nlui:hover(x, y, w, h)
  return self.mx >= x and self.mx < x + w and self.my >= y and self.my < y + h
end

function nlui:click(x, y, w, h, layer)
  if not self.lpressed or self.clickUsed or self.clickLayer ~= layer then return false end
  if self:hover(x, y, w, h) then
    self.clickUsed = true
    return true
  end
  return false
end

function nlui:hoverRect(x, y, w, h, r, first, last, col, a)
  if first and last then rect(x, y, w, h, col, r, a)
  elseif first then rect(x, y, w, h, col, r, a) rect(x, y + h / 2, w, h / 2, col, 0, a)
  elseif last then rect(x, y, w, h, col, r, a) rect(x, y, w, h / 2, col, 0, a)
  else rect(x, y, w, h, col, 0, a) end
end

function nlui:popupFor(item)
  for i, p in ipairs(self.popups) do if p.item == item then return p, i end end
  return nil
end

function nlui:popupOpen(kind)
  for _, p in ipairs(self.popups) do if p.kind == kind then return true end end
  return false
end

function nlui:dropPopup(p)
  p.closeT0 = self.now
  self.closing[#self.closing + 1] = p
end

function nlui:closeFrom(idx)
  while #self.popups >= idx and #self.popups > 0 do self:dropPopup(remove(self.popups)) end
end

function nlui:closeAll()
  self:closeFrom(1)
end

function nlui:pushPopup(p, left, top, layer)
  local s, L = self.scale, self.L
  self:closeFrom(layer + 1)
  local X, Y, W, H = L.X, L.Y, L.W, L.H
  if left + p.w > X + W - 10 * s then left = X + W - 10 * s - p.w end
  if left < X + 10 * s then left = X + 10 * s end
  if p.flipUp or top + p.h > Y + H - 10 * s then top = (p.anchorTop or top) - p.h - (p.flipGap or 10 * s) end
  if top < Y + 10 * s then top = Y + 10 * s end
  p.x, p.y = left, top
  p.t0 = self.now
  p.scroll, p.scrollTarget = 0, 0
  self.popups[#self.popups + 1] = p
  return p
end

function nlui:openDropdown(it, x, y, w, h, C, layer)
  if self.justClosed[it] then return end
  local s = self.scale
  local n = #it.sorted
  local vis = min(n, nlui.dropdownMax)
  local ph = 12 * s + vis * C.itemH
  self:pushPopup({ kind = "dd", item = it, w = w, h = ph, C = C, anchorTop = y, flipGap = 6 * s, n = n, vis = vis, maxScroll = (n - vis) * C.itemH }, x, y + h + 6 * s, layer)
end

function nlui:openExtra(it, ax, ay, aw, ah, layer)
  if self.justClosed[it] then return end
  local s = self.scale
  local h = (6 + 28 + #it.sub.items * 48 + 6) * s
  self:pushPopup({ kind = "pop", item = it, w = 330 * s, h = h, C = self.C.compact, anchorTop = ay }, ax - 8 * s, ay + ah + 10 * s, layer)
end

function nlui:openColor(it, ax, ay, aw, ah, layer)
  if self.justClosed[it] then return end
  local s = self.scale
  local h = (6 + 28 + 26 + 4 * 48 + 6) * s
  self:pushPopup({ kind = "color", item = it, w = 300 * s, h = h, C = self.C.compact, anchorTop = ay }, ax + aw - 300 * s, ay + ah + 10 * s, layer)
end

function nlui:openConfigMenu(px, py, pw, ph)
  local s = self.scale
  local names = self:configNames()
  local extra = 2 + ((#names > 1) and 1 or 0)
  local h = (12 + 13) * s + (#names + extra) * self.C.full.itemH
  self:pushPopup({ kind = "config", w = 251 * s, h = h, C = self.C.full, anchorTop = py, flipGap = 6 * s }, px + 50 * s, py + ph + 6 * s, 0)
end

function nlui:openGroupMenu(gx, gy, gw, gh)
  local s = self.scale
  local h = 12 * s + #self.weaponGroups * self.C.full.itemH
  self:pushPopup({ kind = "group", w = gw, h = h, C = self.C.full, anchorTop = gy, flipGap = 6 * s }, gx, gy + gh + 6 * s, 0)
end

function nlui:openAccount(ux, uy, uw, uh)
  local s = self.scale
  local h = (6 + 28 + 5 * 40 + 6) * s
  self:pushPopup({ kind = "account", w = 330 * s, h = h, C = self.C.compact, anchorTop = uy, flipUp = true }, ux - 8 * s, uy, 0)
end

function nlui:commitEdit()
  local e = self.editing
  if not e then return end
  self.editing = nil
  local t = sgsub(sgsub(e.text, "^%s+", ""), "%s+$", "")
  if e.kind == "config" then
    if t ~= "" then self:createConfig(t) end
    return
  end
  local n
  if t == "" or (e.zero and slower(t) == slower(e.zero)) then n = e.min else n = tonumber(t) end
  if n == nil then return end
  n = clamp(n, e.min, e.max)
  e.apply(floor(n + 0.5))
end

function nlui:beginFrame()
  local inp = nlui.input
  local ok, mx, my = pcall(inp.mouse)
  if not ok then self.inputError = tostring(mx) mx, my = -1, -1 end
  if type(mx) ~= "number" or type(my) ~= "number" then mx, my = -1, -1 end
  self.mx, self.my = mx, my
  local okd, ld = pcall(inp.down, 1)
  if not okd then self.inputError = tostring(ld) ld = false end
  ld = ld == true
  self.lpressed = ld and not self.ldown
  self.lreleased = self.ldown and not ld
  self.ldown = ld
  local okw, wh = pcall(inp.wheel)
  self.wheel = (okw and type(wh) == "number") and wh or 0
  local prev, cur, pressed, set = self.keyPrev, {}, {}, {}
  for i = 1, #nlui.pollKeys do
    local k = nlui.pollKeys[i]
    local okk, v
    if ssub(k, 1, 5) == "Mouse" then
      okk, v = pcall(inp.down, tonumber(ssub(k, 6)) or 0)
    else
      okk, v = pcall(inp.key, nlui.keymap[k] or k)
    end
    if not okk then self.inputError = tostring(v) v = false end
    v = v == true
    cur[k] = v
    if v and not prev[k] then pressed[#pressed + 1] = k set[k] = true end
  end
  self.keyPrev, self.keyNow, self.pressedKeys, self.pressedSet = cur, cur, pressed, set
  local typed = {}
  for i = 1, #pressed do
    local k = pressed[i]
    if #k == 1 then
      if sfind(k, "%a") then typed[#typed + 1] = cur.Shift and k or slower(k) else typed[#typed + 1] = k end
    elseif k == "Space" then
      typed[#typed + 1] = " "
    end
  end
  self.typed = concat(typed)
end

function nlui:layout()
  local s = self.scale
  local L = {}
  L.X, L.Y, L.W, L.H = self.x, self.y, self.w * s, self.h * s
  L.sideW = 275 * s
  L.mainX = L.X + 293 * s
  L.mainR = L.X + L.W - 32 * s
  local avail = L.mainR - L.mainX
  L.gap = 18 * s
  L.colW1 = floor((avail - L.gap) * 482 / 957)
  L.colW2 = avail - L.gap - L.colW1
  L.col1X = L.mainX
  L.col2X = L.mainX + L.colW1 + L.gap
  L.ctrlW1 = min(219 * s, L.colW1 - 150 * s)
  L.ctrlW2 = min(215 * s, L.colW2 - 150 * s)
  L.topY, L.topH = L.Y + 20 * s, 50 * s
  L.contentTop = L.Y + 70 * s
  L.contentBottom = L.Y + L.H - 30 * s
  L.userSep = L.Y + L.H - 85 * s
  L.userY = L.Y + L.H - 70 * s
  L.searchX = L.X + L.W - 60 * s
  L.gripX, L.gripY = L.X + L.W - 22 * s, L.Y + L.H - 22 * s
  return L
end

function nlui:updateState(L)
  local s = self.scale
  self.justClosed = {}
  self.clickUsed = false
  local swallow = false
  if self.capturing then
    if self.frame > (self.captureFrame or 0) then
      local k = self.pressedKeys[1]
      if k then
        self:set(self.capturing, k == "Escape" and "" or k)
        self.capturing = nil
        if ssub(k, 1, 5) == "Mouse" then swallow = true end
      end
    end
  elseif self.editing then
    local e = self.editing
    for _, k in ipairs(self.pressedKeys) do
      if k == "Enter" then self:commitEdit() break
      elseif k == "Escape" then self.editing = nil break
      elseif k == "Backspace" then e.text = ssub(e.text, 1, -2) end
    end
    if self.editing and self.typed ~= "" then e.text = e.text .. self.typed end
  elseif self.searchOpen then
    for _, k in ipairs(self.pressedKeys) do
      if k == "Escape" then self.searchOpen = false self.search = ""
      elseif k == "Backspace" then self.search = ssub(self.search, 1, -2) end
    end
    if self.searchOpen and self.typed ~= "" then self.search = self.search .. self.typed end
  end
  if self.keyNow.Ctrl and self.pressedSet.S and not self.editing and not self.capturing then self:save() end
  if self.lpressed and self.editing and self.editing.rect and not self:hover(unpack(self.editing.rect)) then self:commitEdit() end
  if self.lpressed and self.searchOpen and self.searchRect and not self:hover(unpack(self.searchRect)) then
    self.searchOpen = false
    self.search = ""
  end
  local top = 0
  for i = #self.popups, 1, -1 do
    local p = self.popups[i]
    if self:hover(p.x, p.y, p.w, p.h) then top = i break end
  end
  self.hoverLayer = top
  if self.lpressed and not swallow then
    if #self.popups > 0 then
      if top == 0 then
        for _, p in ipairs(self.popups) do if p.item then self.justClosed[p.item] = true end end
        self:closeAll()
        self.clickLayer = -1
      else
        while #self.popups > top do
          local p = remove(self.popups)
          if p.item then self.justClosed[p.item] = true end
          self:dropPopup(p)
        end
        self.clickLayer = top
      end
    else
      self.clickLayer = 0
    end
  else
    self.clickLayer = -1
  end
  if not self.ldown then self.drag = nil self.resizing = nil self.dragWin = nil self.dragPanel = nil end
  local X, Y = L.X, L.Y
  if self.resizing then
    local r = self.resizing
    local sw, sh = screenSize()
    self.w = clamp(r.w + (self.mx - r.mx) / s, self.minW, (sw - self.x) / s)
    self.h = clamp(r.h + (self.my - r.my) / s, self.minH, (sh - self.y) / s)
    self.clickUsed = true
  elseif self.dragWin then
    self.x, self.y = self.mx - self.dragWin[1], self.my - self.dragWin[2]
    self.clickUsed = true
  elseif self.clickLayer == 0 and self.lpressed then
    if self:hover(L.gripX - 6 * s, L.gripY - 6 * s, 28 * s, 28 * s) then
      self.resizing = { mx = self.mx, my = self.my, w = self.w, h = self.h }
      self.clickUsed = true
      self:closeAll()
    elseif self:hover(X, Y, 275 * s, 90 * s) then
      self.dragWin = { self.mx - X, self.my - Y }
      self.clickUsed = true
      self:closeAll()
    end
  end
  local k = 1 - exp(-self.dt * 18)
  for _, p in ipairs(self.popups) do
    if p.maxScroll and p.maxScroll > 0 then
      p.scrollTarget = clamp(p.scrollTarget or 0, 0, p.maxScroll)
      p.scroll = (p.scroll or 0) + (p.scrollTarget - (p.scroll or 0)) * k
      if abs(p.scrollTarget - p.scroll) < 0.2 then p.scroll = p.scrollTarget end
    end
  end
  local tab = self.tab
  if self.wheel ~= 0 then
    if top > 0 then
      local p = self.popups[top]
      if p.maxScroll and p.maxScroll > 0 then p.scrollTarget = clamp((p.scrollTarget or 0) - self.wheel * p.C.itemH * 1.5, 0, p.maxScroll) end
    elseif tab and self:hover(L.mainX, L.contentTop, L.mainR - L.mainX, L.contentBottom - L.contentTop) and (tab.maxScroll or 0) > 0 then
      tab.scrollTarget = clamp((tab.scrollTarget or 0) - self.wheel * 84 * s, 0, tab.maxScroll)
      self:closeAll()
    end
  end
  if tab then
    tab.scrollTarget = clamp(tab.scrollTarget or 0, 0, tab.maxScroll or 0)
    tab.scroll = (tab.scroll or 0) + (tab.scrollTarget - (tab.scroll or 0)) * k
    if abs(tab.scrollTarget - tab.scroll) < 0.2 then tab.scroll = tab.scrollTarget end
  end
end

function nlui:rescale()
  self.C = { full = scaled(FULL, self.scale), compact = scaled(COMPACT, self.scale) }
  self.cachedScale = self.scale
end

function nlui:drawIcon(name, x, y, sz, col, flag)
  local fn = icons[name]
  if fn then fn(x, y, sz, col, flag) end
end

function nlui:drawAvatar(cx, cy, r)
  if imageReady(self.avatarImage) then
    drawImage(self.avatarImage, cx - r, cy - r, r * 2, r * 2)
    ring(cx, cy, r + r * 0.5, theme.menuBg, r * 1.02, 255)
    ring(cx, cy, r + 0.5, theme.white, 1, 30)
    return
  end
  circle(cx, cy, r, theme.avatar)
  circle(cx, cy - r * 0.22, r * 0.36, theme.avatarDark)
  local pts = {}
  pts[#pts + 1] = { cx - r * 0.62, cy + r * 0.34 }
  pts[#pts + 1] = { cx - r * 0.36, cy + r * 0.16 }
  pts[#pts + 1] = { cx + r * 0.36, cy + r * 0.16 }
  pts[#pts + 1] = { cx + r * 0.62, cy + r * 0.34 }
  for a = 30, 150, 12 do
    local ra = rad(a)
    pts[#pts + 1] = { cx + cos(ra) * r * 0.97, cy + sin(ra) * r * 0.97 }
  end
  polyFill(pts, theme.avatarDark, 255)
end

function nlui:popupFrame(p)
  local s = self.scale
  shadow(p.x, p.y, p.w, p.h, 10 * s, 0.8)
  rect(p.x, p.y, p.w, p.h, theme.popup, 10 * s, theme.popupAlpha)
  outline(p.x, p.y, p.w, p.h, theme.white, 10 * s, theme.popupBorderAlpha)
end

function nlui:toggleCtl(it, right, cy, C, layer)
  local x, y, w, h = right - C.togW, cy - C.togH / 2, C.togW, C.togH
  local on = self:get(it.id) and true or false
  local t = self:anim("tg:" .. it.id, on and 1 or 0, 16)
  rect(x, y, w, h, mix(theme.toggleTrack, theme.blue, t), h / 2)
  local pad = (h - C.knob) / 2
  local kx = x + pad + C.knob / 2 + (w - pad * 2 - C.knob) * t
  local press = self:anim("tp:" .. it.id, (self.ldown and self.hoverLayer == layer and self:hover(x, y, w, h)) and 1 or 0, 20, 0)
  circle(kx, cy, C.knob / 2 - press * 1.5, mix(theme.toggleKnob, theme.white, t))
  if self:click(x, y, w, h, layer) then self:set(it.id, not on) end
end

function nlui:dropdownCtl(it, x, cy, w, C, layer)
  local s = self.scale
  local h = C.ddH
  local y = cy - h / 2
  local open = self:popupFor(it) ~= nil
  local hov = self.hoverLayer == layer and self:hover(x, y, w, h)
  local ha = self:anim("dh:" .. it.id, (hov or open) and 1 or 0, 22, 0)
  rect(x, y, w, h, theme.control, C.ddR)
  if ha > 0.01 then rect(x, y, w, h, theme.white, C.ddR, 12 * ha) end
  local v = self:get(it.id)
  local label = (it.t == "multi") and concat(v, ", ") or tostring(v)
  local maxW = w - C.ddPadL - C.ddPadR - C.chev - 6 * s
  textC(fit(label, maxW, C.ddFont), x + C.ddPadL, cy, theme.text, C.ddFont)
  local rot = self:anim("dc:" .. it.id, open and 1 or 0, 18, 0)
  self:drawIcon("chevron_down", x + w - C.ddPadR - C.chev / 2, cy, C.chev, theme.text, rot)
  if self:click(x, y, w, h, layer) then self:openDropdown(it, x, y, w, h, C, layer) end
end

function nlui:sliderValue(mn, mx, trackX, usable, knob)
  local p = (self.mx - trackX - knob / 2) / max(1, usable)
  p = clamp(p, 0, 1)
  return floor(mn + p * (mx - mn) + 0.5)
end

function nlui:sliderCtl(key, v, mn, mx, x, right, cy, C, layer, fmtFn, zeroWord, apply)
  local s = self.scale
  local txt = fmtFn(v)
  local editing = self.editing
  if not (editing and editing.key == key) then editing = nil end
  local shown = editing and editing.text or txt
  local tw = measure(shown, C.valFont)
  local vw = tw + C.valPad * 2
  if editing then vw = max(vw, 64 * s) end
  local vx, vy, vh = right - vw, cy - C.valH / 2, C.valH
  local trackX, trackW = x, right - vw - C.sGap - x
  local trackY = cy - 2 * s
  rect(trackX, trackY, trackW, 4 * s, theme.control, 2 * s)
  local range = mx - mn
  if range <= 0 then range = 1 end
  local usable = trackW - C.sKnob
  local drag = self.drag
  if drag and drag.key == key then
    if self.ldown then v = self:sliderValue(mn, mx, trackX, usable, C.sKnob) else self.drag = nil end
  elseif self:click(trackX, cy - 16 * s, trackW, 32 * s, layer) then
    self.drag = { key = key }
    v = self:sliderValue(mn, mx, trackX, usable, C.sKnob)
  end
  local p = clamp((v - mn) / range, 0, 1)
  local dragging = self.drag and self.drag.key == key
  local ap
  if dragging then
    self.anims["sp:" .. key] = p
    ap = p
  else
    ap = self:anim("sp:" .. key, p, 26)
  end
  local kx = trackX + C.sKnob / 2 + ap * usable
  rect(trackX, trackY, kx - trackX, 4 * s, theme.blue, 2 * s)
  local kh = self:anim("sk:" .. key, (dragging or (self.hoverLayer == layer and self:hover(trackX, cy - 16 * s, trackW, 32 * s))) and 1 or 0, 20, 0)
  circle(kx, cy + 1, C.sKnob / 2 + 1 + kh * 2 * s, theme.black, 70)
  circle(kx, cy, C.sKnob / 2 + kh * 1.5 * s, theme.white)
  local vhov = self.hoverLayer == layer and self:hover(vx, vy, vw, vh)
  local va = self:anim("sv:" .. key, (editing or vhov) and 1 or 0, 22, 0)
  rect(vx, vy, vw, vh, theme.control, C.valR)
  if va > 0.01 then rect(vx, vy, vw, vh, theme.white, C.valR, 12 * va) end
  if editing then
    outline(vx, vy, vw, vh, theme.blue, C.valR, 255)
    editing.rect = { vx, vy, vw, vh }
    local ex = vx + vw / 2 - tw / 2
    textC(shown, ex, cy, theme.text, C.valFont)
    if (self.now % 1) < 0.5 then rect(ex + tw + 1, cy - C.valFont * 0.55, max(1, s), C.valFont * 1.1, theme.text) end
  else
    textC(txt, vx + vw / 2 - tw / 2, cy, theme.text, C.valFont)
    if self:click(vx, vy, vw, vh, layer) then
      self.editing = { key = key, text = (zeroWord and v == mn) and "" or tostring(floor(v + 0.5)), min = mn, max = mx, zero = zeroWord, rect = { vx, vy, vw, vh }, apply = apply }
    end
  end
  return v
end

function nlui:fmt(it, v)
  if it.zero and v == it.min then return it.zero end
  return tostring(floor(v + 0.5)) .. (it.unit or "")
end

function nlui:keyCtl(it, right, cy, C, layer)
  local cap = self.capturing == it.id
  local v = self:get(it.id)
  local label = cap and "..." or ((v ~= nil and v ~= "") and tostring(v) or "None")
  local tw = measure(label, C.keyFont)
  local w = max(C.keyMin, tw + C.keyPad * 2)
  local x, y, h = right - w, cy - C.keyH / 2, C.keyH
  local hov = self.hoverLayer == layer and self:hover(x, y, w, h)
  local ha = self:anim("kh:" .. it.id, (hov or cap) and 1 or 0, 22, 0)
  rect(x, y, w, h, theme.control, C.keyR)
  if ha > 0.01 then rect(x, y, w, h, theme.white, C.keyR, 12 * ha) end
  if cap then
    local pulse = 0.55 + 0.45 * sin(self.now * 6)
    outline(x, y, w, h, theme.blue, C.keyR, 255 * pulse)
  end
  textC(label, x + w / 2 - tw / 2, cy, cap and theme.blue or theme.text, C.keyFont)
  if not cap and self:click(x, y, w, h, layer) then
    self.capturing = it.id
    self.captureFrame = self.frame
    self.editing = nil
  end
end

function nlui:colorCtl(it, right, cy, C, layer)
  local v = self:get(it.id)
  local x, y, w = right - C.sw, cy - C.sw / 2, C.sw
  local hov = self.hoverLayer == layer and self:hover(x, y, w, w)
  local ha = self:anim("ch:" .. it.id, (hov or self:popupFor(it) ~= nil) and 1 or 0, 22, 0)
  rect(x, y, w, w, color.rgba(v[1], v[2], v[3], 255), C.swR)
  outline(x, y, w, w, theme.white, C.swR, 36 + 60 * ha, 2)
  if self:click(x, y, w, w, layer) then self:openColor(it, x, y, w, w, layer) end
end

function nlui:drawControl(it, ctrlX, right, cy, ctrlW, C, layer)
  if it.t == "toggle" then
    self:toggleCtl(it, right, cy, C, layer)
  elseif it.t == "dropdown" or it.t == "multi" then
    self:dropdownCtl(it, ctrlX, cy, ctrlW, C, layer)
  elseif it.t == "slider" then
    local v = self:get(it.id)
    local nv = self:sliderCtl(it.id, v, it.min, it.max, ctrlX, right, cy, C, layer,
      function(x) return self:fmt(it, x) end, it.zero,
      function(n) self:set(it.id, n) end)
    if nv ~= v then self:set(it.id, nv) end
  elseif it.t == "keybind" then
    self:keyCtl(it, right, cy, C, layer)
  elseif it.t == "color" then
    self:colorCtl(it, right, cy, C, layer)
  end
end

function nlui:drawRow(it, x, y, w, h, ctrlW, C, layer, first, last, r)
  local s = self.scale
  local hov = self.hoverLayer == layer and self:hover(x, y, w, h)
  local ha = self:anim("rh:" .. it.id .. ":" .. layer, hov and 1 or 0, 24, 0)
  if ha > 0.01 then
    if layer == 0 then self:hoverRect(x, y, w, h, r, first, last, theme.rowHover, 255 * ha)
    else rect(x, y, w, h, theme.white, 0, theme.hoverAlpha * ha) end
  end
  local cy = y + h / 2
  local left, right = x + C.padL, x + w - C.padR
  local ctrlX = right - ctrlW
  local ctrlLeft = ctrlX
  if it.t == "toggle" then
    ctrlLeft = right - C.togW
  elseif it.t == "color" then
    ctrlLeft = right - C.sw
  elseif it.t == "keybind" then
    local v = self:get(it.id)
    local label = (self.capturing == it.id) and "..." or ((v ~= nil and v ~= "") and tostring(v) or "None")
    ctrlLeft = right - max(C.keyMin, measure(label, C.keyFont) + C.keyPad * 2)
  end
  local labelLimit = ctrlLeft
  if it.sub then
    local dx = ctrlLeft - C.dotsGap - C.dots / 2
    local hx, hy, hs = dx - C.dots, cy - C.dots, C.dots * 2
    local dh = self.hoverLayer == layer and self:hover(hx, hy, hs, hs)
    local open = self:popupFor(it) ~= nil
    local da = self:anim("da:" .. it.id, (dh or open) and 1 or 0, 24, 0)
    self:drawIcon("dots", dx, cy, C.dots + da * 2 * s, mix(theme.muted, theme.text, da))
    if self:click(hx, hy, hs, hs, layer) then self:openExtra(it, hx, hy, hs, hs, layer) end
    labelLimit = hx
  end
  textC(fit(it.label, labelLimit - left - 8 * s, C.font), left, cy, theme.text, C.font)
  self:drawControl(it, ctrlX, right, cy, ctrlW, C, layer)
end

function nlui:drawSidebar(L)
  local s, X, Y = self.scale, L.X, L.Y
  if imageReady(self.logoImage) then
    drawImage(self.logoImage, X + 25 * s, Y + 20 * s, 50 * s, 50 * s)
  else
    rect(X + 25 * s, Y + 20 * s, 50 * s, 50 * s, theme.logoBg, 12 * s)
    local lw, lh = measure(self.logo, 24 * s)
    text(self.logo, X + 50 * s - lw / 2, Y + 45 * s - lh / 2, theme.logoFg, 24 * s)
  end
  textC(self.title, X + 98 * s, Y + 37 * s, theme.white, 22 * s)
  textC(self.subtitle, X + 98 * s, Y + 58 * s, theme.muted, 13 * s)
  rect(X + 15 * s, Y + 91 * s, 245 * s, 1, theme.white, 0, theme.lineAlpha)
  local y = Y + 110 * s
  local entries, activeY = {}, nil
  for _, g in ipairs(self.groups) do
    entries[#entries + 1] = { label = g.name, y = y }
    y = y + 26 * s
    for _, tab in ipairs(g.tabs) do
      entries[#entries + 1] = { tab = tab, y = y }
      if tab == self.tab then activeY = y end
      y = y + 60 * s
    end
    y = y + 29 * s
  end
  local navBottom = L.userSep - 10 * s
  if activeY then
    local ay = Y + self:anim("navy", activeY - Y, 22)
    if ay + 55 * s <= navBottom then rect(X + 17 * s, ay, 241 * s, 55 * s, theme.activeItem, 12 * s) end
  end
  for _, e in ipairs(entries) do
    if e.label then
      if e.y + 14 * s <= navBottom then textC(supper(e.label), X + 33 * s, e.y + 7 * s, theme.muted, 14 * s) end
    elseif e.y + 55 * s <= navBottom then
      local tab, iy = e.tab, e.y
      local ix, iw, ih = X + 17 * s, 241 * s, 55 * s
      local active = tab == self.tab
      local hov = self.hoverLayer == 0 and self:hover(ix, iy, iw, ih)
      local ha = self:anim("nh:" .. tab.id, (hov and not active) and 1 or 0, 24, 0)
      if ha > 0.01 then rect(ix, iy, iw, ih, theme.white, 12 * s, theme.hoverAlpha * ha) end
      local ta = self:anim("na:" .. tab.id, active and 1 or 0, 20)
      self:drawIcon(tab.icon, X + 43 * s + ha * 2 * s, iy + 27.5 * s, 22 * s, mix(theme.icon, theme.blue, ta))
      textC(tab.name, X + 72 * s + ha * 2 * s, iy + 27.5 * s, mix(theme.navText, theme.white, ta), 20 * s)
      if self:click(ix, iy, iw, ih, 0) then self:setTab(tab) end
    end
  end
  rect(X + 15 * s, L.userSep, 245 * s, 1, theme.white, 0, theme.lineAlpha)
  local ux, uy, uw, uh = X + 15 * s, L.userY, 245 * s, 55 * s
  local uhov = self.hoverLayer == 0 and self:hover(ux, uy, uw, uh)
  local ua = self:anim("uh", (uhov or self:popupOpen("account")) and 1 or 0, 24, 0)
  if ua > 0.01 then rect(ux, uy, uw, uh, theme.white, 12 * s, theme.hoverAlpha * ua) end
  self:drawAvatar(X + 52.5 * s, uy + 27.5 * s, 27.5 * s)
  textC(fit(self.user, 120 * s, 20 * s), X + 98 * s, uy + 16 * s, theme.white, 20 * s)
  textC(fit(self.userSub, 120 * s, 15 * s), X + 98 * s, uy + 42 * s, theme.muted, 15 * s)
  self:drawIcon("chevron_right", X + 243 * s + ua * 3 * s, uy + 27.5 * s, 16 * s, mix(theme.chev, theme.white, ua))
  if self:click(ux, uy, uw, uh, 0) then self:openAccount(ux, uy, uw, uh) end
end

function nlui:drawTopbar(L)
  local s, X, Y = self.scale, L.X, L.Y
  local px, py, pw, ph = L.mainX, L.topY, 302 * s, L.topH
  rect(px, py, pw, ph, theme.card, 10 * s, theme.cardAlpha)
  outline(px, py, pw, ph, theme.white, 10 * s, theme.borderAlpha)
  local sw = 50 * s
  local sa = self:anim("sh", (self.hoverLayer == 0 and self:hover(px, py, sw, ph)) and 1 or 0, 24, 0)
  if sa > 0.01 then rect(px, py, sw, ph, theme.white, 10 * s, theme.hoverAlpha * sa) end
  rect(px + sw, py + 8 * s, 1, ph - 16 * s, theme.white, 0, 15)
  local flash = self:anim("sf", (self.saveFlash and self.saveFlash > self.frame) and 1 or 0, 12)
  self:drawIcon("save", px + 25 * s, py + 25 * s, 20 * s + flash * 2 * s, mix(theme.white, theme.blue, flash))
  if self:click(px, py, sw, ph, 0) then self:save() end
  local cx, cw = px + sw + 1, pw - sw - 1
  local cfgOpen = self:popupOpen("config")
  local ca = self:anim("chov", (cfgOpen or (self.hoverLayer == 0 and self:hover(cx, py, cw, ph))) and 1 or 0, 24, 0)
  if ca > 0.01 then rect(cx, py, cw, ph, theme.white, 10 * s, theme.hoverAlpha * ca) end
  self:drawIcon("note", px + 82 * s, py + 25 * s, 22 * s, theme.white)
  textC(fit(self.config, 150 * s, 20 * s), px + 106 * s, py + 25 * s, theme.text, 20 * s)
  self:drawIcon("chevron_down", px + 276 * s, py + 25 * s, 16 * s, theme.chev, self:anim("cc", cfgOpen and 1 or 0, 18, 0))
  if self:click(cx, py, cw, ph, 0) then self:openConfigMenu(px, py, pw, ph) end
  local gx, gw = px + pw + 25 * s, 142 * s
  rect(gx, py, gw, ph, theme.card, 10 * s, theme.cardAlpha)
  outline(gx, py, gw, ph, theme.white, 10 * s, theme.borderAlpha)
  local grpOpen = self:popupOpen("group")
  local ga = self:anim("gh", (grpOpen or (self.hoverLayer == 0 and self:hover(gx, py, gw, ph))) and 1 or 0, 24, 0)
  if ga > 0.01 then rect(gx, py, gw, ph, theme.white, 10 * s, theme.hoverAlpha * ga) end
  textC(fit(self.group, 86 * s, 20 * s), gx + 20 * s, py + 25 * s, theme.text, 20 * s)
  self:drawIcon("chevron_down", gx + 113 * s, py + 25 * s, 16 * s, theme.chev, self:anim("gc", grpOpen and 1 or 0, 18, 0))
  if self:click(gx, py, gw, ph, 0) then self:openGroupMenu(gx, py, gw, ph) end
  local ix, iy = L.searchX, py + 25 * s
  local hx, hy, hs = ix - 16 * s, iy - 16 * s, 32 * s
  local hot = self.searchOpen or (self.hoverLayer == 0 and self:hover(hx, hy, hs, hs))
  local ia = self:anim("si", hot and 1 or 0, 24, 0)
  self:drawIcon("search", ix, iy, 24 * s + ia * 2 * s, mix(theme.chev, theme.white, ia))
  if self:click(hx, hy, hs, hs, 0) then
    if self.searchOpen then
      self.searchOpen = false
      self.search = ""
    else
      self.searchOpen = true
      self:closeAll()
      self.editing = nil
      self.capturing = nil
    end
  end
  local so = self:anim("so", self.searchOpen and 1 or 0, 20, 0)
  local maxBw = min(280 * s, ix - 28 * s - (px + pw + 12 * s))
  if so > 0.01 and maxBw > 40 * s then
    local e = easeOut(so)
    local bw = maxBw * e
    local bx = ix - 28 * s - bw
    rect(bx, py, bw, ph, theme.card, 10 * s, theme.cardAlpha)
    outline(bx, py, bw, ph, theme.white, 10 * s, 30)
    local ta = max(0, (e - 0.5) * 2) * 255
    if self.search == "" then
      textC("Search settings", bx + 16 * s, py + 25 * s, theme.muted, 19 * s, ta)
    else
      textC(fit(self.search, bw - 36 * s, 19 * s), bx + 16 * s, py + 25 * s, theme.text, 19 * s, ta)
    end
    if self.searchOpen and (self.now % 1) < 0.5 then
      local tw = measure(self.search, 19 * s)
      rect(bx + 16 * s + min(tw, bw - 36 * s) + 2, py + 15 * s, max(1, s), 20 * s, theme.text, ta)
    end
    self.searchRect = { bx, py, ix + 16 * s - bx, ph }
  else
    self.searchRect = { hx, hy, hs, hs }
  end
end

function nlui:drawContent(L)
  local s, X = self.scale, L.X
  local ta = 1
  if self.tabT0 then ta = easeOut(min(1, (self.now - self.tabT0) / 0.2)) end
  local base = galpha
  galpha = base * ta
  local top, bottom = L.contentTop, L.contentBottom
  local viewH = bottom - top
  local q = slower(self.search)
  local tab = self.tab
  local hasContent, matched, maxH = false, 0, 0
  if tab then
    local scroll = tab.scroll or 0
    local slide = (1 - ta) * 10 * s
    local cols = { { x = L.col1X, w = L.colW1, ctrlW = L.ctrlW1 }, { x = L.col2X, w = L.colW2, ctrlW = L.ctrlW2 } }
    for ci = 1, 2 do
      local col = cols[ci]
      local startY = top + 40 * s - scroll + slide
      local y = startY
      local first = true
      for _, sec in ipairs(tab.columns[ci]) do
        hasContent = true
        local visible = {}
        for _, it in ipairs(sec.items) do
          if q == "" or sfind(slower(it.label), q, 1, true) then visible[#visible + 1] = it end
        end
        if #visible > 0 then
          matched = matched + #visible
          if not first then y = y + 33 * s end
          local lcy = y + 7 * s
          if lcy - 7 * s >= top and lcy + 7 * s <= bottom then textC(supper(sec.title), col.x + 22 * s, lcy, theme.muted, 14 * s) end
          y = y + 30 * s
          local rowH = sec.single and 60 * s or 63 * s
          local ch = rowH * #visible
          local c0, c1 = max(y, top), min(y + ch, bottom)
          if c1 - c0 > 1 then
            rect(col.x, c0, col.w, c1 - c0, theme.card, 14 * s, theme.cardAlpha)
            outline(col.x, c0, col.w, c1 - c0, theme.white, 14 * s, theme.borderAlpha)
          end
          for i, it in ipairs(visible) do
            local ry = y + (i - 1) * rowH
            if ry >= top - 0.5 and ry + rowH <= bottom + 0.5 then
              if i > 1 then rect(col.x, ry, col.w, 1, theme.white, 0, theme.lineAlpha) end
              self:drawRow(it, col.x, ry, col.w, rowH, col.ctrlW, self.C.full, 0, i == 1, i == #visible, 13 * s)
            end
          end
          y = y + ch
          first = false
        end
      end
      local colH = y - startY + 40 * s
      if colH > maxH then maxH = colH end
    end
    tab.contentH = maxH
    tab.maxScroll = max(0, maxH + 24 * s - viewH)
    if tab.maxScroll > 0 then
      local moving = abs((tab.scrollTarget or 0) - scroll) > 0.5
      local hovC = self.hoverLayer == 0 and self:hover(L.mainX, top, L.mainR - L.mainX, viewH)
      local sb = self:anim("sb", moving and 1 or (hovC and 0.55 or 0.22), 10, 0)
      local trackX = L.X + L.W - 14 * s
      local thumbH = max(24 * s, viewH * viewH / (maxH + 24 * s))
      local ty = top + (scroll / tab.maxScroll) * (viewH - thumbH)
      rect(trackX, top, 4 * s, viewH, theme.white, 2 * s, 5)
      rect(trackX, ty, 4 * s, thumbH, theme.white, 2 * s, 120 * sb)
    else
      self.anims.sb = 0
    end
  end
  if not hasContent then
    local ex, ey, ew, eh = L.mainX, top + 40 * s, L.mainR - L.mainX, 220 * s
    rect(ex, ey, ew, eh, theme.card, 14 * s, theme.cardAlpha)
    outline(ex, ey, ew, eh, theme.white, 14 * s, theme.borderAlpha)
    local t = "No settings on this tab yet"
    local tw, th = measure(t, 18 * s)
    text(t, ex + ew / 2 - tw / 2, ey + eh / 2 - th / 2, theme.muted, 18 * s)
  elseif q ~= "" and matched == 0 then
    textC("No settings match your search", L.mainX + 22 * s, top + 47 * s, theme.muted, 18 * s)
  end
  galpha = base
end

function nlui:drawDropdownPopup(p, idx)
  local s, C, it = self.scale, p.C, p.item
  self:popupFrame(p)
  local v = self:get(it.id)
  local multi = it.t == "multi"
  local sel = {}
  if multi then for _, o in ipairs(v) do sel[o] = true end else sel[v] = true end
  local innerTop, innerBottom = p.y + 6 * s, p.y + p.h - 6 * s
  local scroll = p.scroll or 0
  local scrollable = (p.maxScroll or 0) > 0
  local iw = p.w - 12 * s - (scrollable and 8 * s or 0)
  for i, o in ipairs(it.sorted) do
    local iy = innerTop + (i - 1) * C.itemH - scroll
    if iy >= innerTop - 0.5 and iy + C.itemH <= innerBottom + 0.5 then
      local ix, ih = p.x + 6 * s, C.itemH
      local hov = self.hoverLayer == idx and self:hover(ix, iy, iw, ih)
      local ha = self:anim("ih:" .. it.id .. ":" .. o, hov and 1 or 0, 26, 0)
      if ha > 0.01 then rect(ix, iy, iw, ih, theme.controlHover, C.itemR, 255 * ha) end
      local tx = ix + C.itemPad
      if multi then
        local bs = 16 * s
        local bx, by = tx, iy + ih / 2 - bs / 2
        local ck = self:anim("ck:" .. it.id .. ":" .. o, sel[o] and 1 or 0, 22)
        outline(bx, by, bs, bs, theme.white, 4 * s, 64 * (1 - ck), 1.5)
        if ck > 0.01 then
          rect(bx, by, bs, bs, theme.blue, 4 * s, 255 * ck)
          self:drawIcon("check", bx + bs / 2, by + bs / 2, 11 * s * ck, theme.white)
        end
        tx = tx + bs + 10 * s
      end
      textC(fit(o, ix + iw - tx - C.itemPad, C.itemFont), tx, iy + ih / 2, mix(theme.navText, theme.white, max(ha, sel[o] and 1 or 0)), C.itemFont)
      if self:click(ix, iy, iw, ih, idx) then
        if multi then
          local nv = {}
          if sel[o] then
            if #v > 1 then
              for _, x in ipairs(v) do if x ~= o then nv[#nv + 1] = x end end
            else
              nv = v
            end
          else
            for _, x in ipairs(it.sorted) do if sel[x] or x == o then nv[#nv + 1] = x end end
          end
          self:set(it.id, nv)
        else
          self:set(it.id, o)
          self:closeFrom(idx)
        end
      end
    end
  end
  if scrollable then
    local trackH = innerBottom - innerTop
    local thumbH = max(16 * s, trackH * (p.vis / p.n))
    local ty = innerTop + (scroll / p.maxScroll) * (trackH - thumbH)
    rect(p.x + p.w - 8 * s, innerTop, 3 * s, trackH, theme.white, 1.5 * s, 6)
    rect(p.x + p.w - 8 * s, ty, 3 * s, thumbH, theme.white, 1.5 * s, 70)
  end
end

function nlui:drawExtraPopup(p, idx)
  local s, C = self.scale, p.C
  self:popupFrame(p)
  textC(supper(p.item.label), p.x + 16 * s, p.y + 20 * s, theme.muted, 13 * s)
  local y = p.y + 34 * s
  for _, sub in ipairs(p.item.sub.items) do
    self:drawRow(sub, p.x, y, p.w, 48 * s, min(150 * s, p.w - 120 * s), C, idx, false, false, 0)
    y = y + 48 * s
  end
end

function nlui:drawColorPopup(p, idx)
  local s, C, it = self.scale, p.C, p.item
  self:popupFrame(p)
  textC(supper(it.label), p.x + 16 * s, p.y + 20 * s, theme.muted, 13 * s)
  local v = self:get(it.id)
  rect(p.x + 14 * s, p.y + 34 * s, p.w - 28 * s, 18 * s, color.rgba(v[1], v[2], v[3], 255), 6 * s, v[4] or 255)
  local y = p.y + 60 * s
  local names = { "Red", "Green", "Blue", "Alpha" }
  for i = 1, 4 do
    local cy = y + 24 * s
    local hov = self.hoverLayer == idx and self:hover(p.x, y, p.w, 48 * s)
    local ha = self:anim("crh:" .. it.id .. i, hov and 1 or 0, 24, 0)
    if ha > 0.01 then rect(p.x, y, p.w, 48 * s, theme.white, 0, theme.hoverAlpha * ha) end
    textC(names[i], p.x + C.padL, cy, theme.text, C.font)
    local right = p.x + p.w - C.padR
    local key = it.id .. ":" .. i
    local cur = v[i] or 255
    local nv = self:sliderCtl(key, cur, 0, 255, right - 150 * s, right, cy, C, idx,
      function(x) return tostring(floor(x + 0.5)) end, nil,
      function(n) local c = copy(self:get(it.id)) c[i] = n self:set(it.id, c) end)
    if nv ~= cur then
      local c = copy(v)
      c[i] = nv
      self:set(it.id, c)
      v = c
    end
    y = y + 48 * s
  end
end

function nlui:menuItem(p, idx, y, label, selected, danger, key)
  local s, C = self.scale, p.C
  local ix, iw, ih = p.x + 6 * s, p.w - 12 * s, C.itemH
  local hov = self.hoverLayer == idx and self:hover(ix, y, iw, ih)
  local ha = self:anim("mi:" .. (key or label), hov and 1 or 0, 26, 0)
  if ha > 0.01 then rect(ix, y, iw, ih, theme.controlHover, C.itemR, 255 * ha) end
  local tx = ix + C.itemPad
  if selected then
    circle(tx + 3 * s, y + ih / 2, 3 * s, theme.blue)
    tx = tx + 16 * s
  end
  local col = danger and theme.danger or mix(theme.navText, theme.white, max(ha, selected and 1 or 0))
  textC(fit(label, ix + iw - tx - C.itemPad, C.itemFont), tx, y + ih / 2, col, C.itemFont)
  return self:click(ix, y, iw, ih, idx)
end

function nlui:drawConfigPopup(p, idx)
  local s, C = self.scale, p.C
  self:popupFrame(p)
  local y = p.y + 6 * s
  local names = self:configNames()
  for _, name in ipairs(names) do
    if self:menuItem(p, idx, y, name, name == self.config, false, "cfg:" .. name) then self:switchConfig(name) end
    y = y + C.itemH
  end
  rect(p.x + 10 * s, y + 6 * s, p.w - 20 * s, 1, theme.white, 0, theme.lineAlpha)
  y = y + 13 * s
  local e = self.editing
  if e and e.kind == "config" then
    local ix, iw, ih = p.x + 12 * s, p.w - 24 * s, 36 * s
    local iy = y + (C.itemH - ih) / 2
    rect(ix, iy, iw, ih, theme.control, 7 * s)
    outline(ix, iy, iw, ih, theme.blue, 7 * s, 255)
    e.rect = { ix, iy, iw, ih }
    if e.text == "" then textC("Config name", ix + 10 * s, iy + ih / 2, theme.muted, 16 * s)
    else textC(fit(e.text, iw - 24 * s, 16 * s), ix + 10 * s, iy + ih / 2, theme.text, 16 * s) end
    if (self.now % 1) < 0.5 then
      local tw = measure(e.text, 16 * s)
      rect(ix + 10 * s + min(tw, iw - 24 * s) + 1, iy + 9 * s, max(1, s), ih - 18 * s, theme.text)
    end
    if self:click(ix, iy, iw, ih, idx) then end
  else
    if self:menuItem(p, idx, y, "New config", false, false, "cfg:new") then
      self.editing = { kind = "config", text = "", rect = { p.x, y, p.w, C.itemH } }
    end
  end
  y = y + C.itemH
  if self:menuItem(p, idx, y, "Duplicate current", false, false, "cfg:dup") then self:duplicateConfig() end
  y = y + C.itemH
  if #names > 1 then
    if self:menuItem(p, idx, y, "Delete current", false, true, "cfg:del") then self:deleteConfig() end
  end
end

function nlui:drawGroupPopup(p, idx)
  local s, C = self.scale, p.C
  self:popupFrame(p)
  local y = p.y + 6 * s
  for _, g in ipairs(self.weaponGroups) do
    if self:menuItem(p, idx, y, g, g == self.group, false, "grp:" .. g) then self:setGroup(g) end
    y = y + C.itemH
  end
end

function nlui:drawAccountPopup(p, idx)
  local s = self.scale
  self:popupFrame(p)
  textC("ACCOUNT", p.x + 16 * s, p.y + 20 * s, theme.muted, 13 * s)
  local rows = {
    { "Username", self.user },
    { "Subscription", self.userSub ~= "" and self.userSub or "-" },
    { "Configs", tostring(#self:configNames()) },
    { "Active config", self.config },
    { "Weapon group", self.group },
  }
  local y = p.y + 34 * s
  for _, r in ipairs(rows) do
    local cy = y + 20 * s
    textC(r[1], p.x + 16 * s, cy, theme.text, 16 * s)
    local vt = fit(r[2], 170 * s, 16 * s)
    local tw = measure(vt, 16 * s)
    textC(vt, p.x + p.w - 16 * s - tw, cy, theme.muted, 16 * s)
    y = y + 40 * s
  end
end

function nlui:drawPopup(p, idx)
  if p.kind == "dd" then self:drawDropdownPopup(p, idx)
  elseif p.kind == "pop" then self:drawExtraPopup(p, idx)
  elseif p.kind == "color" then self:drawColorPopup(p, idx)
  elseif p.kind == "config" then self:drawConfigPopup(p, idx)
  elseif p.kind == "group" then self:drawGroupPopup(p, idx)
  elseif p.kind == "account" then self:drawAccountPopup(p, idx) end
end

function nlui:drawPopups()
  local s = self.scale
  local base = galpha
  local i = 1
  while i <= #self.closing do
    local p = self.closing[i]
    local prog = min(1, (self.now - (p.closeT0 or self.now)) / 0.12)
    if prog >= 1 then
      remove(self.closing, i)
    else
      galpha = base * (1 - prog)
      local oy = p.y
      p.y = p.y - prog * 6 * s
      self:drawPopup(p, -2)
      p.y = oy
      i = i + 1
    end
  end
  for idx, p in ipairs(self.popups) do
    local e = easeOut(min(1, (self.now - (p.t0 or self.now)) / 0.14))
    galpha = base * e
    local oy = p.y
    p.y = p.y - (1 - e) * 8 * s
    self:drawPopup(p, idx)
    p.y = oy
  end
  galpha = base
end

function nlui:drawToast(L)
  if not self.toastText then return end
  local rem = (self.toastUntil or 0) - self.now
  if rem <= 0 then self.toastText = nil return end
  local el = self.now - (self.toastStart or self.now)
  local a = min(1, el / 0.15, rem / 0.2)
  local s = self.scale
  local tw, th = measure(self.toastText, 16 * s)
  local w, h = tw + 36 * s, 40 * s
  local x, y = L.X + L.W / 2 - w / 2, L.Y + L.H - 22 * s - h + (1 - a) * 10 * s
  local base = galpha
  galpha = base * a
  shadow(x, y, w, h, 10 * s, 0.6)
  rect(x, y, w, h, theme.popup, 10 * s, theme.popupAlpha)
  outline(x, y, w, h, theme.white, 10 * s, theme.popupBorderAlpha)
  text(self.toastText, x + 18 * s, y + h / 2 - th / 2, theme.white, 16 * s)
  galpha = base
end

function nlui:addPanel(p)
  p.id = p.id or ("panel" .. (#self.panels + 1))
  self.panels[#self.panels + 1] = p
  return p
end

function nlui:removePanel(id)
  for i, p in ipairs(self.panels) do if p.id == id then remove(self.panels, i) return true end end
  return false
end

function nlui:panelFrame(x, y, w, h, r, accent)
  shadow(x, y, w, h, r, 0.7)
  rect(x, y, w, h, theme.panelBg, r, theme.panelAlpha)
  outline(x, y, w, h, theme.white, r, 16)
  if accent then
    rect(x, y, w, 2, theme.blue, r)
  end
end

function nlui:watermark(opts)
  opts = opts or {}
  return self:addPanel({ id = opts.id or "watermark", kind = "watermark", x = opts.x or 20, y = opts.y or 20, w = 120, h = 32, alwaysVisible = opts.alwaysVisible ~= false, text = opts.text, showUser = opts.showUser ~= false, showFps = opts.showFps ~= false })
end

function nlui:keybindList(opts)
  opts = opts or {}
  return self:addPanel({ id = opts.id or "keybinds", kind = "keybinds", x = opts.x or 20, y = opts.y or 70, w = 200, h = 40, alwaysVisible = opts.alwaysVisible ~= false, title = opts.title or "Keybinds" })
end

function nlui:espPreview(opts)
  opts = opts or {}
  local sw = screenSize()
  return self:addPanel({ id = opts.id or "esp_preview", kind = "esp", x = opts.x or (sw - 310), y = opts.y or 120, w = 280, h = 340, alwaysVisible = opts.alwaysVisible == true, bind = opts, title = opts.title or "ESP Preview" })
end

function nlui:drawWatermark(p, X, Y)
  local s = self.scale
  local parts = { p.text or self.title }
  if p.showUser then parts[#parts + 1] = self.user end
  if p.showFps then parts[#parts + 1] = sformat("%d fps", floor(self.fps + 0.5)) end
  local label = concat(parts, "   |   ")
  local tw = measure(label, 15 * s)
  p.w = (tw + 36 * s) / s
  p.h = 32
  local w, h = p.w * s, p.h * s
  self:panelFrame(X, Y, w, h, 8 * s)
  rect(X, Y + 6 * s, 3 * s, h - 12 * s, theme.blue, 1.5 * s)
  textC(label, X + 18 * s, Y + h / 2, theme.text, 15 * s)
end

function nlui:drawKeybindList(p, X, Y)
  local s = self.scale
  local rows = {}
  for _, it in pairs(self.items) do
    if it.t == "keybind" then
      local k = self:get(it.id)
      if k and k ~= "" then rows[#rows + 1] = { label = it.label, parent = it.parentLabel, key = k, down = self.keyNow[k] == true } end
    end
  end
  sort(rows, function(a, b) return a.label < b.label end)
  if #rows == 0 and not self.open then p.drawn = false return end
  p.w = 210
  p.h = (34 + #rows * 26 + (#rows > 0 and 8 or 4))
  local w, h = p.w * s, p.h * s
  self:panelFrame(X, Y, w, h, 8 * s, true)
  textC(p.title, X + 14 * s, Y + 18 * s, theme.text, 14 * s)
  local y = Y + 34 * s
  for _, r in ipairs(rows) do
    local cy = y + 13 * s
    local on = self:anim("kb:" .. r.label, r.down and 1 or 0, 18)
    circle(X + 16 * s, cy, 3 * s, mix(theme.muted, theme.blue, on))
    textC(fit(r.label, w - 110 * s, 14 * s), X + 26 * s, cy, mix(theme.navText, theme.white, on), 14 * s)
    local kw = measure(r.key, 12 * s) + 12 * s
    rect(X + w - 12 * s - kw, cy - 9 * s, kw, 18 * s, theme.control, 4 * s)
    textC(r.key, X + w - 6 * s - kw, cy, theme.text, 12 * s)
    y = y + 26 * s
  end
end

function nlui:bindOn(bind, key, default)
  if not bind or bind[key] == nil then return default end
  local v = self:get(bind[key])
  if v == nil then return default end
  return v and true or false
end

function nlui:bindColor(bind, key, default)
  if not bind or bind[key] == nil then return default, 255 end
  local c, a = self:packedColor(bind[key], default)
  return c, a
end

function nlui:drawEspPreview(p, X, Y)
  local s = self.scale
  local w, h = p.w * s, p.h * s
  local r = 10 * s
  self:panelFrame(X, Y, w, h, r)
  textC(p.title, X + 14 * s, Y + 18 * s, theme.text, 14 * s)
  local ix, iy, iw, ih = X + 10 * s, Y + 32 * s, w - 20 * s, h - 42 * s
  rect(ix, iy, iw, ih, theme.espBottom, 8 * s)
  gradient(ix + 8 * s, iy, iw - 16 * s, ih, theme.espTop, theme.espBottom, false, 255, 255)
  gradient(ix, iy + 8 * s, iw, ih - 16 * s, theme.espTop, theme.espBottom, false, 255, 255)
  for gx = ix + 20 * s, ix + iw - 8 * s, 20 * s do rect(gx, iy + 6 * s, 1, ih - 12 * s, theme.white, 0, 5) end
  for gy = iy + 20 * s, iy + ih - 8 * s, 20 * s do rect(ix + 6 * s, gy, iw - 12 * s, 1, theme.white, 0, 5) end
  local bind = p.bind
  local enabled = self:bindOn(bind, "enabled", true)
  local fh = ih * 0.6
  local cx = ix + iw / 2
  local ground = iy + ih - 34 * s
  local top = ground - fh
  local headR = fh * 0.078
  local head = { cx, top + headR }
  local neck = { cx, top + headR * 2.1 }
  local shL, shR = { cx - fh * 0.14, top + headR * 2.6 }, { cx + fh * 0.14, top + headR * 2.6 }
  local elL, elR = { cx - fh * 0.2, top + fh * 0.46 }, { cx + fh * 0.2, top + fh * 0.46 }
  local haL, haR = { cx - fh * 0.17, top + fh * 0.63 }, { cx + fh * 0.17, top + fh * 0.63 }
  local hiL, hiR = { cx - fh * 0.08, top + fh * 0.56 }, { cx + fh * 0.08, top + fh * 0.56 }
  local knL, knR = { cx - fh * 0.1, top + fh * 0.79 }, { cx + fh * 0.1, top + fh * 0.79 }
  local ftL, ftR = { cx - fh * 0.11, ground }, { cx + fh * 0.11, ground }
  local limb = fh * 0.075
  circle(cx, ground + 2 * s, fh * 0.22, theme.black, 60)
  local function bone(a, b, col, t)
    line(a[1], a[2], b[1], b[2], col, t)
    circle(a[1], a[2], t / 2, col)
    circle(b[1], b[2], t / 2, col)
  end
  bone(shL, elL, theme.figure, limb) bone(elL, haL, theme.figure, limb)
  bone(shR, elR, theme.figure, limb) bone(elR, haR, theme.figure, limb)
  bone(hiL, knL, theme.figure, limb * 1.15) bone(knL, ftL, theme.figure, limb * 1.15)
  bone(hiR, knR, theme.figure, limb * 1.15) bone(knR, ftR, theme.figure, limb * 1.15)
  polyFill({ { shL[1] - limb * 0.3, shL[2] - limb * 0.2 }, { shR[1] + limb * 0.3, shR[2] - limb * 0.2 }, { hiR[1] + limb * 0.5, hiR[2] + limb * 0.3 }, { hiL[1] - limb * 0.5, hiL[2] + limb * 0.3 } }, theme.figure, 255)
  polyFill({ { shL[1] + limb * 0.2, shL[2] + limb * 0.1 }, { cx, shL[2] + limb * 0.1 }, { cx, hiL[2] }, { hiL[1] - limb * 0.1, hiL[2] } }, theme.figureLight, 70)
  circle(head[1], head[2], headR, theme.figure)
  circle(head[1] - headR * 0.25, head[2] - headR * 0.3, headR * 0.55, theme.figureLight, 60)
  bone(neck, { cx, shL[2] }, theme.figure, limb * 0.9)
  if not enabled then
    textC("ESP disabled", cx - measure("ESP disabled", 14 * s) / 2, iy + ih - 16 * s, theme.muted, 14 * s)
    return
  end
  local bx, by = cx - fh * 0.27, top - headR * 0.35
  local bw, bh = fh * 0.54, ground - by + 4 * s
  local boxCol, boxA = self:bindColor(bind, "boxColor", theme.white)
  if self:bindOn(bind, "box", true) then
    outline(bx - 1, by - 1, bw + 2, bh + 2, theme.black, 0, 160 * boxA / 255, 3)
    outline(bx, by, bw, bh, boxCol, 0, boxA, 1.5)
  end
  if self:bindOn(bind, "health", true) then
    local hx = bx - 8 * s
    rect(hx - 1, by - 1, 5 * s + 2, bh + 2, theme.black, 2 * s, 170)
    local fill = 0.78
    gradient(hx, by + bh * (1 - fill), 5 * s, bh * fill, theme.green, theme.red, false, 255, 255)
    textShadow("78", hx - 4 * s - measure("78", 11 * s), by + bh * (1 - fill), theme.white, 11 * s)
  end
  if self:bindOn(bind, "name", true) then
    local n = "Player"
    textShadow(n, cx - measure(n, 13 * s) / 2, by - 10 * s, theme.white, 13 * s)
  end
  local below = by + bh + 9 * s
  if self:bindOn(bind, "weapon", true) then
    local t = "AK-47"
    textShadow(t, cx - measure(t, 12 * s) / 2, below, theme.text, 12 * s)
    below = below + 14 * s
  end
  if self:bindOn(bind, "distance", true) then
    local t = "24m"
    textShadow(t, cx - measure(t, 12 * s) / 2, below, theme.muted, 12 * s)
  end
  if self:bindOn(bind, "flags", true) then
    local fx, fy = bx + bw + 8 * s, by
    for _, f in ipairs({ "armor", "scoped", "defusing" }) do
      textShadow(f, fx, fy + 6 * s, theme.text, 11 * s)
      fy = fy + 13 * s
    end
  end
  if self:bindOn(bind, "skeleton", false) then
    local sc, sa = self:bindColor(bind, "skeletonColor", theme.white)
    local t = max(1, 1.5 * s)
    local function seg(a, b) line(a[1], a[2], b[1], b[2], sc, t, sa) end
    seg(head, neck) seg(neck, shL) seg(neck, shR) seg(shL, elL) seg(elL, haL) seg(shR, elR) seg(elR, haR)
    seg(neck, { cx, hiL[2] }) seg({ cx, hiL[2] }, hiL) seg({ cx, hiL[2] }, hiR) seg(hiL, knL) seg(knL, ftL) seg(hiR, knR) seg(knR, ftR)
    for _, j in ipairs({ head, neck, shL, shR, elL, elR, haL, haR, hiL, hiR, knL, knR, ftL, ftR }) do circle(j[1], j[2], 2 * s, sc, sa) end
  end
end

function nlui:drawPanels(menuOpen, L)
  local s = self.scale
  local base = galpha
  for _, p in ipairs(self.panels) do
    local want = (menuOpen or p.alwaysVisible) and not p.hidden
    if p.kind == "keybinds" and not menuOpen then
      local any = false
      for _, it in pairs(self.items) do
        if it.t == "keybind" then
          local k = self:get(it.id)
          if k and k ~= "" then any = true break end
        end
      end
      want = want and any
    end
    local pa = self:anim("pn:" .. p.id, want and 1 or 0, 14, 0)
    if pa > 0.01 then
      galpha = pa
      local X, Y = p.x, p.y + (1 - pa) * 8
      if p.kind == "watermark" then self:drawWatermark(p, X, Y)
      elseif p.kind == "keybinds" then self:drawKeybindList(p, X, Y)
      elseif p.kind == "esp" then self:drawEspPreview(p, X, Y)
      elseif type(p.draw) == "function" then p.draw(self, p, X, Y) end
      galpha = base
    end
  end
  if not menuOpen or not L then return end
  if self.dragPanel then
    local d = self.dragPanel
    d.p.x, d.p.y = self.mx - d.dx, self.my - d.dy
    return
  end
  if self.lpressed and not self.clickUsed and self.clickLayer == 0 and not self:hover(L.X, L.Y, L.W, L.H) then
    for i = #self.panels, 1, -1 do
      local p = self.panels[i]
      if self:hover(p.x, p.y, p.w * s, p.h * s) then
        self.dragPanel = { p = p, dx = self.mx - p.x, dy = self.my - p.y }
        self.clickUsed = true
        return
      end
    end
  end
end

function nlui:drawWindow(L)
  local s, X, Y, W, H = self.scale, L.X, L.Y, L.W, L.H
  local r = 22 * s
  shadow(X, Y, W, H, r, 1)
  rect(X, Y, W, H, theme.menuBg, r, theme.bgAlpha)
  gradient(X + r, Y, W - r * 2, H * 0.5, theme.white, theme.white, false, theme.sheenAlpha, 0)
  outline(X, Y, W, H, theme.white, r, 13)
  self:drawContent(L)
  self:drawSidebar(L)
  self:drawTopbar(L)
  local ga = self:anim("grip", (self.resizing or (self.hoverLayer == 0 and self:hover(L.gripX - 6 * s, L.gripY - 6 * s, 28 * s, 28 * s))) and 1 or 0, 20, 0)
  self:drawIcon("grip", L.gripX + 6 * s, L.gripY + 6 * s, 14 * s, mix(theme.muted, theme.white, ga), nil)
  if self.inputError then
    textC("nlui input error: " .. fit(self.inputError, (W - 400) * s, 14 * s), L.mainX, Y + H - 14 * s, theme.danger, 14 * s)
  end
end

function nlui:render()
  local ok, err = pcall(self.renderInner, self)
  if not ok then
    if self.lastError ~= err then
      self.lastError = err
      if print then print("nlui error: " .. tostring(err)) end
    end
    galpha = 1
    pcall(text, "nlui error: " .. tostring(err), self.x, self.y - 20, theme.danger, 14)
  end
end

function nlui:renderInner()
  self.frame = self.frame + 1
  local t = now()
  if t == nil then t = self.frame / 60 end
  if self.lastNow then
    self.dt = clamp(t - self.lastNow, 0.0005, 0.1)
  else
    self.dt = 1 / 60
  end
  self.lastNow, self.now = t, t
  self.fps = self:anim("fps", 1 / self.dt, 3)
  self:beginFrame()
  if self.followMenu then
    local st = nlui.menuState()
    if st ~= nil then self.open = st end
  elseif self.pressedSet[self.toggleKey] and not self.editing and not self.searchOpen and not self.capturing then
    self.open = not self.open
  end
  local alpha = self:anim("menu", self.open and 1 or 0, self.fadeSpeed)
  self.alpha = alpha
  self.visible = alpha > 0.005
  if self.scale ~= self.cachedScale then self:rescale() end
  local s = self.scale
  if not self.visible then
    self.popups, self.closing = {}, {}
    self.editing = nil
    self.capturing = nil
    self.drag = nil
    self.dragWin = nil
    self.resizing = nil
    self.dragPanel = nil
    self.searchOpen = false
    self.search = ""
    self.anims.so = 0
    galpha = 1
    self:drawPanels(false, nil)
    return
  end
  local oy = self.y
  self.y = oy + (1 - alpha) * 14 * s
  local L = self:layout()
  self.L = L
  if self.open then
    self:updateState(L)
  else
    self.hoverLayer, self.clickLayer, self.clickUsed = -1, -1, true
    if not self.ldown then self.drag = nil end
    self.dragWin, self.resizing, self.dragPanel = nil, nil, nil
  end
  galpha = 1
  self:drawPanels(self.open, L)
  galpha = alpha
  self:drawWindow(L)
  self:drawPopups()
  self:drawToast(L)
  galpha = 1
  self.y = oy
end

nlui.autobind()

return nlui
