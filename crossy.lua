-- CROSSY LILKA — Frogger для Lilka у ~100 рядках коду.
-- Курча переходить дороги до фінішу й збирає монетки. ← ↑ → ↓ рух, D пауза, B вихід.
-- Налаштування
local W, H, CELL, COLS, HUD = display.width, display.height, 24, 10, 24
local KEY = display.color565(255, 0, 255)            -- магента = прозорість

-- Рівні: читаємо ЗЛІВА НАПРАВО = від старту до фінішу.
-- G старт/трава, R дорога→, L дорога←, C монетка, F фініш. Після R/L цифра 1..5 = швидкість.
local LEVELS = { "GR1GL1GR1GGF", "GCR2L2GR2GL2F", "GR3L2GR3L3GGF", "GCR3L4GR2L4GF", "GR4L4GR3L5GGF", "GCR5L4R5L5R5GF" }

-- Спрайти (load_image повертає {width, height, pointer})
local function img(n) return resources.load_image("assets/" .. n .. ".png", KEY) end
local HERO, COIN, HEART = img("hero_down"), img("coin"), img("heart")
local CARS = { img("car_blue"), img("car_orange"), img("car_green"), img("car_purple") }
local CARS_R = {}                                    -- дзеркальні — для смуг, що їдуть →
for i, c in ipairs(CARS) do CARS_R[i] = resources.flip_image_x(c) end

-- Кольори (трава, дорога, темний, білий)
local GRASS, ROAD, DARK, WHITE = display.color565(126,200,80), display.color565(70,74,90), display.color565(33,36,57), display.color565(255,255,255)

-- Стан
local rows, N, hx, hy, lives, score, level, paused, over, won

local function buildLevel(str)
  local list, i = {}, 1                              -- читаємо зліва→направо (старт → фініш)
  while i <= #str do
    local ch, row = str:sub(i, i), { kind = "grass" }
    if ch == "R" or ch == "L" then
      local tier = tonumber(str:sub(i + 1, i + 1)) or 3; i = i + 1  -- цифра після дороги = швидкість 1..5
      row.kind, row.dir, row.speed, row.cars = "road", (ch == "R") and 1 or -1, 30 + tier * 15, {}
      for k = 1, 3 do                                -- 3 машини, різні спрайти, рівна відстань
        row.cars[k] = { x = (k - 1) * (W / 3), img = ((#list + k) % #CARS) + 1 }
      end
    elseif ch == "F" then row.kind = "finish"
    elseif ch == "C" then row.coin = math.random(0, COLS - 1)
    end
    list[#list + 1] = row; i = i + 1
  end
  rows, N = {}, #list                                -- list[1] = низ; перевертаємо, щоб rows[1] = верх
  for k = 1, N do rows[k] = list[N - k + 1] end; hx, hy = math.floor(COLS / 2), N  -- старт унизу
end

local function startGame()
  level, lives, score, paused, over, won = 1, 3, 0, false, false, false
  buildLevel(LEVELS[1])
end

-- Стрибок героя в сусідню клітинку
local function move(dx, dy)
  local nx, ny = hx + dx, hy + dy
  if nx < 0 or nx >= COLS or ny < 1 or ny > N then return end
  hx, hy = nx, ny
  local row = rows[hy]
  if row.coin == hx then row.coin, score = nil, score + 10 end
  if row.kind == "finish" then                       -- перейшов усі дороги!
    score = score + 50
    if level >= #LEVELS then over, won = true, true
    else level = level + 1; buildLevel(LEVELS[level]) end  -- одразу наступний рівень
  end
end

function lilka.init() startGame() end

function lilka.update(delta)
  local c = controller.get_state()
  if c.b.just_pressed then util.exit() end                      -- B вихід
  if c.d.just_pressed then paused = not paused end               -- D пауза
  if over then if c.d.just_pressed then startGame() end return end
  if paused then return end
  if     c.up.just_pressed    then move(0, -1)
  elseif c.down.just_pressed  then move(0,  1)
  elseif c.left.just_pressed  then move(-1, 0)
  elseif c.right.just_pressed then move(1,  0) end
  for i = 1, N do                                     -- рух машин + зіткнення
    local row = rows[i]
    if row.kind == "road" then
      for _, car in ipairs(row.cars) do
        car.x = car.x + row.dir * row.speed * delta
        local s = (row.dir == 1 and CARS_R or CARS)[car.img]
        if car.x > W then car.x = -s.width elseif car.x + s.width < 0 then car.x = W end
        if i == hy and hx * CELL + 20 > car.x and hx * CELL + 4 < car.x + s.width then
          lives = lives - 1
          if lives <= 0 then over = true else hx, hy = math.floor(COLS / 2), N end
        end
      end
    end
  end
end

local function banner(txt)
  display.fill_rect(0, H / 2 - 16, W, 30, DARK)
  display.set_font("6x13"); display.set_text_color(WHITE)
  display.set_cursor(14, H / 2 + 3); display.print(txt)
end

function lilka.draw()
  display.fill_rect(0, HUD, W, H - HUD, GRASS)         -- трава на все поле
  local TOP = H - N * CELL                             -- прив'язка поля до низу екрана
  for i = 1, N do
    local row, y = rows[i], TOP + (i - 1) * CELL
    if row.kind == "finish" then                       -- шахова фінішна лінія
      display.fill_rect(0, y, W, CELL, WHITE)
      for xx = 0, W - 1, 12 do display.fill_rect(xx, y + (xx % 24 == 0 and 0 or 12), 12, 12, DARK) end
    elseif row.kind == "road" then display.fill_rect(0, y, W, CELL, ROAD) end
    if row.coin then display.draw_image(COIN, row.coin * CELL + 2, y + 1) end
    if row.cars then
      for _, car in ipairs(row.cars) do
        local s = (row.dir == 1 and CARS_R or CARS)[car.img]
        display.draw_image(s, math.floor(car.x), y + (CELL - s.height) / 2)
      end
    end
  end
  display.draw_image(HERO, hx * CELL + (CELL - HERO.width) / 2, (H - N * CELL) + (hy - 1) * CELL + 1); display.fill_rect(0, 0, W, HUD, DARK)  -- герой, потім панель HUD
  for k = 1, lives do display.draw_image(HEART, 10 + (k - 1) * 22, 2) end
  display.set_font("6x13"); display.set_text_color(WHITE)
  display.set_cursor(92, 16); display.print("рiвень ", level, "  бали ", score)
  if won then banner("ПЕРЕМОГА! бали " .. score .. "   D - знову")
  elseif over then banner("КIНЕЦЬ, бали " .. score .. "   D - знову")
  elseif paused then banner("ПАУЗА") end
end
