local nlui = {}
nlui.__index = nlui
nlui.version = "1.0.0"

local draw, color = draw, color
if type(draw) ~= "table" or type(color) ~= "table" then
  error("nlui: the draw and color APIs must exist before loading the library")
end

local floor, max, min = math.floor, math.max, math.min
local ssub, sfind, slower, supper, sformat, sgsub = string.sub, string.find, string.lower, string.upper, string.format, string.gsub
local insert, remove, concat, sort = table.insert, table.remove, table.concat, table.sort
local unpack = unpack or table.unpack
local loadfn = loadstring or load
local clock = (os and os.clock) or nil

local function rgb(r, g, b) return color.rgba(r, g, b, 255) end

local theme = {
  font = "Verdana",
  menuBg = rgb(15, 16, 20),
  card = rgb(22, 23, 28),
  rowHover = rgb(28, 29, 35),
  control = rgb(37, 39, 46),
  controlHover = rgb(45, 47, 55),
  text = rgb(227, 228, 232),
  navText = rgb(200, 202, 208),
  muted = rgb(139, 141, 149),
  icon = rgb(154, 156, 164),
  chev = rgb(213, 214, 218),
  blue = rgb(63, 126, 247),
  white = rgb(255, 255, 255),
  black = rgb(0, 0, 0),
  toggleTrack = rgb(13, 14, 18),
  toggleKnob = rgb(227, 228, 232),
  logoBg = rgb(255, 255, 255),
  logoFg = rgb(20, 22, 51),
  activeItem = rgb(34, 36, 42),
  popup = rgb(30, 32, 38),
  danger = rgb(224, 107, 107),
  avatar = rgb(179, 37, 44),
  avatarDark = rgb(42, 20, 22),
  lineAlpha = 9,
  borderAlpha = 11,
  popupBorderAlpha = 18,
  hoverAlpha = 8,
  shadowAlpha = 110,
}
nlui.theme = theme

nlui.keymap = {}
nlui.input = {
  mouse = function() return -1, -1 end,
  down = function(button) return false end,
  key = function(name) return false end,
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

function nlui.autobind()
  local g = _G or {}
  local inp = rawget(g, "input") or rawget(g, "Input")
  if type(inp) ~= "table" then return false end
  local m = probe(inp, { "GetMousePos", "GetCursorPos", "get_mouse_pos", "mouse_position", "GetMousePosition" })
  local d = probe(inp, { "IsMouseDown", "IsButtonDown", "is_mouse_down", "mouse_down", "IsMouseButtonDown" })
  local k = probe(inp, { "IsKeyDown", "is_key_down", "key_down", "IsKeyPressed" })
  if m then nlui.input.mouse = function() return m() end end
  if d then nlui.input.down = function(b) return d(b) end end
  if k then nlui.input.key = function(n) return k(n) end end
  return m ~= nil
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

local function text(t, x, y, col, size, a)
  if draw.text then
    draw.text(t, floor(x), floor(y), col, floor(size + 0.5), a or 255)
  else
    draw.Text(t, floor(x), floor(y), col, theme.font, a or 255)
  end
end

local function textC(t, x, cy, col, size, a)
  local _, h = measure(t, size)
  text(t, x, cy - h / 2, col, size, a)
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
  draw.RectFilled(floor(x), floor(y), floor(w + 0.5), floor(h + 0.5), col, r or 0, a or 255)
end

local function outline(x, y, w, h, col, r, a, t)
  draw.Rect(floor(x), floor(y), floor(w + 0.5), floor(h + 0.5), col, t or 1, r or 0, a or 255)
end

local function line(x1, y1, x2, y2, col, t, a)
  draw.Line(x1, y1, x2, y2, col, t or 1, a or 255)
end

local function circle(x, y, r, col, a)
  draw.CircleFilled(x, y, r, col, 0, a or 255)
end

local function ring(x, y, r, col, t, a)
  draw.Circle(x, y, r, col, t or 1, 0, a or 255)
end

local function poly(points, col, closed, t, a)
  draw.Polyline(points, col, closed or false, t or 1, a or 255)
end

local function copy(v)
  if type(v) ~= "table" then return v end
  local t = {}
  for k, x in pairs(v) do t[k] = copy(x) end
  return t
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
  if up then h = -h end
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

local FULL = { rowH = 63, font = 20, ctrlW = 219, ddH = 40, ddR = 10, ddFont = 19, ddPadL = 10, ddPadR = 12, chev = 16, togW = 55, togH = 28, knob = 24, sKnob = 22, sGap = 17, valH = 34, valPad = 13, valFont = 16, valR = 8, keyH = 40, keyMin = 96, keyPad = 12, keyFont = 17, keyR = 10, sw = 40, swR = 10, dots = 16, dotsGap = 20, itemH = 39, itemFont = 17, itemPad = 10, itemR = 7, padL = 22, padR = 23 }
local COMPACT = { rowH = 48, font = 16, ctrlW = 150, ddH = 34, ddR = 8, ddFont = 15, ddPadL = 9, ddPadR = 9, chev = 14, togW = 44, togH = 24, knob = 20, sKnob = 16, sGap = 10, valH = 28, valPad = 9, valFont = 14, valR = 6, keyH = 34, keyMin = 80, keyPad = 10, keyFont = 15, keyR = 8, sw = 34, swR = 8, dots = 14, dotsGap = 14, itemH = 32, itemFont = 14, itemPad = 8, itemR = 6, padL = 14, padR = 14 }

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

local function newItem(c, t, id, label, default, fields)
  if c.menu.items[id] then error("nlui: duplicate item id '" .. tostring(id) .. "'") end
  local item = { t = t, id = id, label = label, v = default, menu = c.menu }
  if fields then for k, v in pairs(fields) do item[k] = v end end
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
  return newItem(self, "multi", id, label, default or { options[1] }, { options = options })
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
  m.scale = opts.scale or 1
  m.title = opts.title or "Neverlose"
  m.subtitle = opts.subtitle or "Counter-Strike 2"
  m.logo = opts.logo or "NL"
  m.user = opts.user or "User"
  m.userSub = opts.userSub or ""
  m.toggleKey = opts.toggleKey or "Insert"
  m.visible = opts.visible ~= false
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
  m.onLoad = opts.onLoad
  m.mx, m.my = -1, -1
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
  local tab = setmetatable({ name = name, icon = icon or "circle", id = slower(name), columns = { {}, {} }, menu = self }, Tab)
  g.tabs[#g.tabs + 1] = tab
  if not self.tab then self.tab = tab end
  return tab
end

function nlui:selectTab(name)
  for _, g in ipairs(self.groups) do
    for _, t in ipairs(g.tabs) do
      if t.name == name or t.id == name then self.tab = t return t end
    end
  end
end

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

function nlui:packedColor(id)
  local c = self:get(id)
  if type(c) ~= "table" then return theme.white end
  return color.rgba(c[1], c[2], c[3], c[4] or 255)
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
  self.popups = {}
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
  self.popups = {}
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
  return "return " .. ser({ version = nlui.version, config = self.config, group = self.group, configs = self.configs })
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
  self:bucket()
  return true
end

function nlui:save()
  self.saveFlash = self.frame + 25
  self:toast("Saved " .. self.config)
  if self.onSave then
    local ok, err = pcall(self.onSave, self.config, self:serialize(), self)
    if not ok then self:toast("Save hook failed") end
  end
end

function nlui:toast(msg)
  self.toastText = msg
  if clock then self.toastUntil = clock() + 1.6 else self.toastFrames = 120 end
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

function nlui:closeFrom(idx)
  while #self.popups >= idx do remove(self.popups) end
end

function nlui:pushPopup(p, left, top, layer)
  local s, X, Y = self.scale, self.x, self.y
  self:closeFrom(layer + 1)
  if left + p.w > X + 1290 * s then left = X + 1290 * s - p.w end
  if left < X + 10 * s then left = X + 10 * s end
  if p.flipUp or top + p.h > Y + 975 * s then top = (p.anchorTop or top) - p.h - (p.flipGap or 10 * s) end
  if top < Y + 10 * s then top = Y + 10 * s end
  p.x, p.y = left, top
  self.popups[#self.popups + 1] = p
  return p
end

function nlui:openDropdown(it, x, y, w, h, C, layer)
  if self.justClosed[it] then return end
  local s = self.scale
  local ph = 12 * s + #it.options * C.itemH
  self:pushPopup({ kind = "dd", item = it, w = w, h = ph, C = C, anchorTop = y, flipGap = 6 * s }, x, y + h + 6 * s, layer)
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
  n = max(e.min, min(e.max, n))
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
  local prev, now, pressed, set = self.keyPrev, {}, {}, {}
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
    now[k] = v
    if v and not prev[k] then pressed[#pressed + 1] = k set[k] = true end
  end
  self.keyPrev, self.keyNow, self.pressedKeys, self.pressedSet = now, now, pressed, set
  local typed = {}
  for i = 1, #pressed do
    local k = pressed[i]
    if #k == 1 then
      if sfind(k, "%a") then typed[#typed + 1] = now.Shift and k or slower(k) else typed[#typed + 1] = k end
    elseif k == "Space" then
      typed[#typed + 1] = " "
    end
  end
  self.typed = concat(typed)
end

function nlui:updateState()
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
        self.popups = {}
        self.clickLayer = -1
      else
        while #self.popups > top do
          local p = remove(self.popups)
          if p.item then self.justClosed[p.item] = true end
        end
        self.clickLayer = top
      end
    else
      self.clickLayer = 0
    end
  else
    self.clickLayer = -1
  end
  if not self.ldown then self.drag = nil end
  local X, Y = self.x, self.y
  if self.dragWin then
    if self.ldown then self.x, self.y = self.mx - self.dragWin[1], self.my - self.dragWin[2] else self.dragWin = nil end
  elseif self.clickLayer == 0 and self.lpressed and self:hover(X, Y, 275 * s, 90 * s) then
    self.dragWin = { self.mx - X, self.my - Y }
    self.clickUsed = true
    self.popups = {}
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
  circle(cx, cy, r, theme.avatar)
  circle(cx, cy - r * 0.22, r * 0.36, theme.avatarDark)
  local pts = {}
  pts[#pts + 1] = { cx - r * 0.62, cy + r * 0.34 }
  pts[#pts + 1] = { cx - r * 0.36, cy + r * 0.16 }
  pts[#pts + 1] = { cx + r * 0.36, cy + r * 0.16 }
  pts[#pts + 1] = { cx + r * 0.62, cy + r * 0.34 }
  for a = 30, 150, 12 do
    local rad = math.rad(a)
    pts[#pts + 1] = { cx + math.cos(rad) * r * 0.97, cy + math.sin(rad) * r * 0.97 }
  end
  draw.ConvexPolyFilled(pts, theme.avatarDark, 255)
end

function nlui:popupFrame(p)
  local s = self.scale
  rect(p.x + 2 * s, p.y + 8 * s, p.w, p.h, theme.black, 12 * s, theme.shadowAlpha)
  rect(p.x, p.y, p.w, p.h, theme.popup, 10 * s)
  outline(p.x, p.y, p.w, p.h, theme.white, 10 * s, theme.popupBorderAlpha)
end

function nlui:toggleCtl(it, right, cy, C, layer)
  local x, y, w, h = right - C.togW, cy - C.togH / 2, C.togW, C.togH
  local on = self:get(it.id) and true or false
  rect(x, y, w, h, on and theme.blue or theme.toggleTrack, h / 2)
  local pad = (h - C.knob) / 2
  local kx = on and (x + w - pad - C.knob / 2) or (x + pad + C.knob / 2)
  circle(kx, cy, C.knob / 2, on and theme.white or theme.toggleKnob)
  if self:click(x, y, w, h, layer) then self:set(it.id, not on) end
end

function nlui:dropdownCtl(it, x, cy, w, C, layer)
  local s = self.scale
  local h = C.ddH
  local y = cy - h / 2
  local open = self:popupFor(it) ~= nil
  local hov = self.hoverLayer == layer and self:hover(x, y, w, h)
  rect(x, y, w, h, (hov or open) and theme.controlHover or theme.control, C.ddR)
  local v = self:get(it.id)
  local label = (it.t == "multi") and concat(v, ", ") or tostring(v)
  local maxW = w - C.ddPadL - C.ddPadR - C.chev - 6 * s
  textC(fit(label, maxW, C.ddFont), x + C.ddPadL, cy, theme.text, C.ddFont)
  self:drawIcon("chevron_down", x + w - C.ddPadR - C.chev / 2, cy, C.chev, theme.text, open)
  if self:click(x, y, w, h, layer) then self:openDropdown(it, x, y, w, h, C, layer) end
end

function nlui:sliderValue(mn, mx, trackX, usable, knob)
  local p = (self.mx - trackX - knob / 2) / max(1, usable)
  p = max(0, min(1, p))
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
  local p = max(0, min(1, (v - mn) / range))
  local kx = trackX + C.sKnob / 2 + p * usable
  rect(trackX, trackY, kx - trackX, 4 * s, theme.blue, 2 * s)
  circle(kx, cy + 1, C.sKnob / 2 + 1, theme.black, 70)
  circle(kx, cy, C.sKnob / 2, theme.white)
  local vhov = self.hoverLayer == layer and self:hover(vx, vy, vw, vh)
  rect(vx, vy, vw, vh, (editing or vhov) and theme.controlHover or theme.control, C.valR)
  if editing then
    outline(vx, vy, vw, vh, theme.blue, C.valR, 255)
    editing.rect = { vx, vy, vw, vh }
    local ex = vx + vw / 2 - tw / 2
    textC(shown, ex, cy, theme.text, C.valFont)
    if self.frame % 60 < 30 then rect(ex + tw + 1, cy - C.valFont * 0.55, max(1, s), C.valFont * 1.1, theme.text) end
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
  rect(x, y, w, h, hov and theme.controlHover or theme.control, C.keyR)
  if cap then outline(x, y, w, h, theme.blue, C.keyR, 255) end
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
  rect(x, y, w, w, color.rgba(v[1], v[2], v[3], 255), C.swR)
  outline(x, y, w, w, theme.white, C.swR, 36, 2)
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
  if hov then
    if layer == 0 then self:hoverRect(x, y, w, h, r, first, last, theme.rowHover, 255)
    else rect(x, y, w, h, theme.white, 0, theme.hoverAlpha) end
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
    self:drawIcon("dots", dx, cy, C.dots, (dh or open) and theme.text or theme.muted)
    if self:click(hx, hy, hs, hs, layer) then self:openExtra(it, hx, hy, hs, hs, layer) end
    labelLimit = hx
  end
  textC(fit(it.label, labelLimit - left - 8 * s, C.font), left, cy, theme.text, C.font)
  self:drawControl(it, ctrlX, right, cy, ctrlW, C, layer)
end

function nlui:drawSidebar()
  local s, X, Y = self.scale, self.x, self.y
  rect(X + 25 * s, Y + 20 * s, 50 * s, 50 * s, theme.logoBg, 12 * s)
  local lw, lh = measure(self.logo, 24 * s)
  text(self.logo, X + 50 * s - lw / 2, Y + 45 * s - lh / 2, theme.logoFg, 24 * s)
  textC(self.title, X + 98 * s, Y + 37 * s, theme.white, 22 * s)
  textC(self.subtitle, X + 98 * s, Y + 58 * s, theme.muted, 13 * s)
  rect(X + 15 * s, Y + 91 * s, 245 * s, 1, theme.white, 0, theme.lineAlpha)
  local y = Y + 110 * s
  for _, g in ipairs(self.groups) do
    textC(supper(g.name), X + 33 * s, y + 7 * s, theme.muted, 14 * s)
    y = y + 26 * s
    for _, tab in ipairs(g.tabs) do
      local ix, iy, iw, ih = X + 17 * s, y, 241 * s, 55 * s
      local active = tab == self.tab
      local hov = self.hoverLayer == 0 and self:hover(ix, iy, iw, ih)
      if active then rect(ix, iy, iw, ih, theme.activeItem, 12 * s)
      elseif hov then rect(ix, iy, iw, ih, theme.white, 12 * s, theme.hoverAlpha) end
      self:drawIcon(tab.icon, X + 43 * s, y + 27.5 * s, 22 * s, active and theme.blue or theme.icon)
      textC(tab.name, X + 72 * s, y + 27.5 * s, active and theme.white or theme.navText, 20 * s)
      if self:click(ix, iy, iw, ih, 0) then
        self.tab = tab
        self.popups = {}
        self.editing = nil
      end
      y = y + 60 * s
    end
    y = y + 29 * s
  end
  rect(X + 15 * s, Y + 900 * s, 245 * s, 1, theme.white, 0, theme.lineAlpha)
  local ux, uy, uw, uh = X + 15 * s, Y + 915 * s, 245 * s, 55 * s
  if self.hoverLayer == 0 and self:hover(ux, uy, uw, uh) then rect(ux, uy, uw, uh, theme.white, 12 * s, theme.hoverAlpha) end
  self:drawAvatar(X + 52.5 * s, Y + 942.5 * s, 27.5 * s)
  textC(fit(self.user, 120 * s, 20 * s), X + 98 * s, Y + 931 * s, theme.white, 20 * s)
  textC(fit(self.userSub, 120 * s, 15 * s), X + 98 * s, Y + 957 * s, theme.muted, 15 * s)
  self:drawIcon("chevron_right", X + 243 * s, Y + 942.5 * s, 16 * s, theme.chev)
  if self:click(ux, uy, uw, uh, 0) then self:openAccount(ux, uy, uw, uh) end
end

function nlui:drawTopbar()
  local s, X, Y = self.scale, self.x, self.y
  local px, py, pw, ph = X + 293 * s, Y + 20 * s, 302 * s, 50 * s
  rect(px, py, pw, ph, theme.card, 10 * s)
  outline(px, py, pw, ph, theme.white, 10 * s, theme.borderAlpha)
  local sw = 50 * s
  if self.hoverLayer == 0 and self:hover(px, py, sw, ph) then rect(px, py, sw, ph, theme.white, 10 * s, theme.hoverAlpha) end
  rect(px + sw, py + 8 * s, 1, ph - 16 * s, theme.white, 0, 15)
  self:drawIcon("save", px + 25 * s, py + 25 * s, 20 * s, (self.saveFlash and self.saveFlash > self.frame) and theme.blue or theme.white)
  if self:click(px, py, sw, ph, 0) then self:save() end
  local cx, cw = px + sw + 1, pw - sw - 1
  local cfgOpen = self:popupOpen("config")
  if cfgOpen or (self.hoverLayer == 0 and self:hover(cx, py, cw, ph)) then rect(cx, py, cw, ph, theme.white, 10 * s, theme.hoverAlpha) end
  self:drawIcon("note", px + 82 * s, py + 25 * s, 22 * s, theme.white)
  textC(fit(self.config, 150 * s, 20 * s), px + 106 * s, py + 25 * s, theme.text, 20 * s)
  self:drawIcon("chevron_down", px + 276 * s, py + 25 * s, 16 * s, theme.chev, cfgOpen)
  if self:click(cx, py, cw, ph, 0) then self:openConfigMenu(px, py, pw, ph) end
  local gx, gw = X + 620 * s, 142 * s
  rect(gx, py, gw, ph, theme.card, 10 * s)
  outline(gx, py, gw, ph, theme.white, 10 * s, theme.borderAlpha)
  local grpOpen = self:popupOpen("group")
  if grpOpen or (self.hoverLayer == 0 and self:hover(gx, py, gw, ph)) then rect(gx, py, gw, ph, theme.white, 10 * s, theme.hoverAlpha) end
  textC(fit(self.group, 86 * s, 20 * s), gx + 20 * s, py + 25 * s, theme.text, 20 * s)
  self:drawIcon("chevron_down", gx + 113 * s, py + 25 * s, 16 * s, theme.chev, grpOpen)
  if self:click(gx, py, gw, ph, 0) then self:openGroupMenu(gx, py, gw, ph) end
  local ix, iy = X + 1240 * s, py + 25 * s
  local hx, hy, hs = ix - 16 * s, iy - 16 * s, 32 * s
  local hot = self.searchOpen or (self.hoverLayer == 0 and self:hover(hx, hy, hs, hs))
  self:drawIcon("search", ix, iy, 24 * s, hot and theme.white or theme.chev)
  if self:click(hx, hy, hs, hs, 0) then
    if self.searchOpen then
      self.searchOpen = false
      self.search = ""
    else
      self.searchOpen = true
      self.popups = {}
      self.editing = nil
      self.capturing = nil
    end
  end
  if self.searchOpen then
    local bw = 280 * s
    local bx = ix - 28 * s - bw
    rect(bx, py, bw, ph, theme.card, 10 * s)
    outline(bx, py, bw, ph, theme.white, 10 * s, 30)
    if self.search == "" then
      textC("Search settings", bx + 16 * s, py + 25 * s, theme.muted, 19 * s)
    else
      local shown = fit(self.search, bw - 36 * s, 19 * s)
      textC(shown, bx + 16 * s, py + 25 * s, theme.text, 19 * s)
    end
    if self.frame % 60 < 30 then
      local tw = measure(self.search, 19 * s)
      rect(bx + 16 * s + min(tw, bw - 36 * s) + 2, py + 15 * s, max(1, s), 20 * s, theme.text)
    end
  end
end

function nlui:drawContent()
  local s, X, Y = self.scale, self.x, self.y
  local tab = self.tab
  local F = self.C.full
  local q = slower(self.search)
  local cols = { { x = X + 293 * s, w = 482 * s, ctrlW = 219 * s }, { x = X + 793 * s, w = 475 * s, ctrlW = 215 * s } }
  local hasContent, matched = false, 0
  if tab then
    for ci = 1, 2 do
      local col = cols[ci]
      local y = Y + 110 * s
      for _, sec in ipairs(tab.columns[ci]) do
        hasContent = true
        local visible = {}
        for _, it in ipairs(sec.items) do
          if q == "" or sfind(slower(it.label), q, 1, true) then visible[#visible + 1] = it end
        end
        if #visible > 0 then
          matched = matched + #visible
          textC(supper(sec.title), col.x + 22 * s, y + 7 * s, theme.muted, 14 * s)
          y = y + 30 * s
          local rowH = sec.single and 60 * s or 63 * s
          local ch = rowH * #visible
          rect(col.x, y, col.w, ch, theme.card, 14 * s)
          outline(col.x, y, col.w, ch, theme.white, 14 * s, theme.borderAlpha)
          for i, it in ipairs(visible) do
            local ry = y + (i - 1) * rowH
            if i > 1 then rect(col.x, ry, col.w, 1, theme.white, 0, theme.lineAlpha) end
            self:drawRow(it, col.x, ry, col.w, rowH, col.ctrlW, F, 0, i == 1, i == #visible, 13 * s)
          end
          y = y + ch + 33 * s
        end
      end
    end
  end
  if not hasContent then
    local ex, ey, ew, eh = X + 293 * s, Y + 110 * s, 975 * s, 220 * s
    rect(ex, ey, ew, eh, theme.card, 14 * s)
    outline(ex, ey, ew, eh, theme.white, 14 * s, theme.borderAlpha)
    local t = "No settings on this tab yet"
    local tw, th = measure(t, 18 * s)
    text(t, ex + ew / 2 - tw / 2, ey + eh / 2 - th / 2, theme.muted, 18 * s)
  elseif q ~= "" and matched == 0 then
    textC("No settings match your search", X + 315 * s, Y + 117 * s, theme.muted, 18 * s)
  end
end

function nlui:drawDropdownPopup(p, idx)
  local s, C, it = self.scale, p.C, p.item
  self:popupFrame(p)
  local v = self:get(it.id)
  local multi = it.t == "multi"
  local sel = {}
  if multi then for _, o in ipairs(v) do sel[o] = true end else sel[v] = true end
  for i, o in ipairs(it.options) do
    local ix, iy, iw, ih = p.x + 6 * s, p.y + 6 * s + (i - 1) * C.itemH, p.w - 12 * s, C.itemH
    local hov = self.hoverLayer == idx and self:hover(ix, iy, iw, ih)
    if hov then rect(ix, iy, iw, ih, theme.controlHover, C.itemR) end
    local tx = ix + C.itemPad
    if multi then
      local bs = 16 * s
      local bx, by = tx, iy + ih / 2 - bs / 2
      if sel[o] then
        rect(bx, by, bs, bs, theme.blue, 4 * s)
        self:drawIcon("check", bx + bs / 2, by + bs / 2, 11 * s, theme.white)
      else
        outline(bx, by, bs, bs, theme.white, 4 * s, 64, 1.5)
      end
      tx = tx + bs + 10 * s
    end
    textC(fit(o, ix + iw - tx - C.itemPad, C.itemFont), tx, iy + ih / 2, (sel[o] or hov) and theme.white or theme.navText, C.itemFont)
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
          for _, x in ipairs(it.options) do if sel[x] or x == o then nv[#nv + 1] = x end end
        end
        self:set(it.id, nv)
      else
        self:set(it.id, o)
        self:closeFrom(idx)
      end
    end
  end
end

function nlui:drawExtraPopup(p, idx)
  local s, C = self.scale, p.C
  self:popupFrame(p)
  textC(supper(p.item.label), p.x + 16 * s, p.y + 20 * s, theme.muted, 13 * s)
  local y = p.y + 34 * s
  for _, sub in ipairs(p.item.sub.items) do
    self:drawRow(sub, p.x, y, p.w, 48 * s, C.ctrlW, C, idx, false, false, 0)
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
    if hov then rect(p.x, y, p.w, 48 * s, theme.white, 0, theme.hoverAlpha) end
    textC(names[i], p.x + C.padL, cy, theme.text, C.font)
    local right = p.x + p.w - C.padR
    local key = it.id .. ":" .. i
    local cur = v[i] or 255
    local nv = self:sliderCtl(key, cur, 0, 255, right - C.ctrlW, right, cy, C, idx,
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

function nlui:menuItem(p, idx, y, label, selected, danger)
  local s, C = self.scale, p.C
  local ix, iw, ih = p.x + 6 * s, p.w - 12 * s, C.itemH
  local hov = self.hoverLayer == idx and self:hover(ix, y, iw, ih)
  if hov then rect(ix, y, iw, ih, theme.controlHover, C.itemR) end
  local tx = ix + C.itemPad
  if selected then
    circle(tx + 3 * s, y + ih / 2, 3 * s, theme.blue)
    tx = tx + 16 * s
  end
  local col = danger and theme.danger or ((selected or hov) and theme.white or theme.navText)
  textC(fit(label, ix + iw - tx - C.itemPad, C.itemFont), tx, y + ih / 2, col, C.itemFont)
  return self:click(ix, y, iw, ih, idx)
end

function nlui:drawConfigPopup(p, idx)
  local s, C = self.scale, p.C
  self:popupFrame(p)
  local y = p.y + 6 * s
  local names = self:configNames()
  for _, name in ipairs(names) do
    if self:menuItem(p, idx, y, name, name == self.config) then self:switchConfig(name) end
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
    if self.frame % 60 < 30 then
      local tw = measure(e.text, 16 * s)
      rect(ix + 10 * s + min(tw, iw - 24 * s) + 1, iy + 9 * s, max(1, s), ih - 18 * s, theme.text)
    end
    if self:click(ix, iy, iw, ih, idx) then end
  else
    if self:menuItem(p, idx, y, "New config", false) then
      self.editing = { kind = "config", text = "", rect = { p.x, y, p.w, C.itemH } }
    end
  end
  y = y + C.itemH
  if self:menuItem(p, idx, y, "Duplicate current", false) then self:duplicateConfig() end
  y = y + C.itemH
  if #names > 1 then
    if self:menuItem(p, idx, y, "Delete current", false, true) then self:deleteConfig() end
  end
end

function nlui:drawGroupPopup(p, idx)
  local s, C = self.scale, p.C
  self:popupFrame(p)
  local y = p.y + 6 * s
  for _, g in ipairs(self.weaponGroups) do
    if self:menuItem(p, idx, y, g, g == self.group) then self:setGroup(g) end
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

function nlui:drawPopups()
  local i = 1
  while i <= #self.popups do
    local p = self.popups[i]
    if p.kind == "dd" then self:drawDropdownPopup(p, i)
    elseif p.kind == "pop" then self:drawExtraPopup(p, i)
    elseif p.kind == "color" then self:drawColorPopup(p, i)
    elseif p.kind == "config" then self:drawConfigPopup(p, i)
    elseif p.kind == "group" then self:drawGroupPopup(p, i)
    elseif p.kind == "account" then self:drawAccountPopup(p, i) end
    i = i + 1
  end
end

function nlui:drawToast()
  if not self.toastText then return end
  local alive
  if clock then alive = clock() < (self.toastUntil or 0)
  else
    self.toastFrames = (self.toastFrames or 0) - 1
    alive = self.toastFrames > 0
  end
  if not alive then self.toastText = nil return end
  local s, X, Y = self.scale, self.x, self.y
  local tw, th = measure(self.toastText, 16 * s)
  local w, h = tw + 36 * s, 40 * s
  local x, y = X + 650 * s - w / 2, Y + 985 * s - 22 * s - h
  rect(x + 2 * s, y + 6 * s, w, h, theme.black, 10 * s, theme.shadowAlpha)
  rect(x, y, w, h, theme.popup, 10 * s)
  outline(x, y, w, h, theme.white, 10 * s, theme.popupBorderAlpha)
  text(self.toastText, x + 18 * s, y + h / 2 - th / 2, theme.white, 16 * s)
end

function nlui:drawWindow()
  local s, X, Y = self.scale, self.x, self.y
  local W, H = 1300 * s, 985 * s
  rect(X - 6 * s, Y + 4 * s, W + 12 * s, H + 12 * s, theme.black, 26 * s, 60)
  rect(X + 2 * s, Y + 12 * s, W, H, theme.black, 22 * s, theme.shadowAlpha)
  rect(X, Y, W, H, theme.menuBg, 22 * s)
  outline(X, Y, W, H, theme.white, 22 * s, 13)
  self:drawSidebar()
  self:drawTopbar()
  self:drawContent()
  if self.inputError then
    textC("nlui input error: " .. fit(self.inputError, 900 * s, 14 * s), X + 293 * s, Y + H - 14 * s, theme.danger, 14 * s)
  end
end

function nlui:render()
  self.frame = self.frame + 1
  self:beginFrame()
  if self.pressedSet[self.toggleKey] then self.visible = not self.visible end
  if not self.visible then
    self.popups = {}
    self.editing = nil
    self.capturing = nil
    self.drag = nil
    self.dragWin = nil
    self.searchOpen = false
    self.search = ""
    return
  end
  if self.scale ~= self.cachedScale then self:rescale() end
  self:updateState()
  self:drawWindow()
  self:drawPopups()
  self:drawToast()
end

nlui.autobind()

return nlui
