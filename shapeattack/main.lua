local player = {}
local bullets = {}
local enemyBullets = {}
local enemies = {}
local enemySpawnTimer = 0
local scoreTimer = 0 
local bulletSpeed = 500
local score = 0
local enemiesDefeated = 0
local bossActive = false

-- Debug Console State
local isPaused = false
local commandBuffer = ""
local isMuted = false
local godMode = false
local showHitboxes = false 

-- Images
local playerImage 
local enemyImage
local enemy2Image
local enemy3Image
local bulletImage

-- Audio handles
local hitSound    -- Bullet Firing
local struckSound -- Bullet Impacting something
local bgMusic 

-- AUDIO LIMITER VARIABLES
local hitSoundTimer = 0
local struckSoundTimer = 0

-- Separate cooldowns: 
-- Increase 'struckCooldown' to make impacts less frequent
local hitCooldown = 0.05    
local struckCooldown = 0.15 

-----------------------------------------------------------
-- COLLISION LOGIC
-----------------------------------------------------------

local function isPointInRotatedRect(px, py, rx, ry, rw, rh, rangle)
    local dx = px - rx
    local dy = py - ry
    local cosA = math.cos(-rangle)
    local sinA = math.sin(-rangle)
    local tx = cosA * dx - sinA * dy
    local ty = sinA * dx + cosA * dy
    return math.abs(tx) < rw / 2 and math.abs(ty) < rh / 2
end

local function checkCollision(x1, y1, w1, h1, a1, x2, y2, w2, h2, a2)
    local function getCorners(x, y, w, h, angle)
        local cosA = math.cos(angle)
        local sinA = math.sin(angle)
        local hw, hh = w/2, h/2
        return {
            {x = x + (hw*cosA - hh*sinA), y = y + (hw*sinA + hh*cosA)},
            {x = x + (-hw*cosA - hh*sinA), y = y + (-hw*sinA + hh*cosA)},
            {x = x + (hw*cosA - -hh*sinA), y = y + (hw*sinA + -hh*cosA)},
            {x = x + (-hw*cosA - -hh*sinA), y = y + (-hw*sinA + -hh*cosA)}
        }
    end
    local corners1 = getCorners(x1, y1, w1, h1, a1)
    for _, p in ipairs(corners1) do
        if isPointInRotatedRect(p.x, p.y, x2, y2, w2, h2, a2) then return true end
    end
    local corners2 = getCorners(x2, y2, w2, h2, a2)
    for _, p in ipairs(corners2) do
        if isPointInRotatedRect(p.x, p.y, x1, y1, w1, h1, a1) then return true end
    end
    return false
end

-- HELPER: This function plays the sound AND returns the new timer value
local function playLimitedSound(source, currentTimer, cooldownValue)
    if not isMuted and currentTimer <= 0 then
        source:clone():play()
        return cooldownValue -- Start the cooldown
    end
    return currentTimer -- Keep the current timer counting down
end

local function clamp(val, min, max)
    return math.max(min, math.min(val, max))
end

local function distance(x1, y1, x2, y2)
    return math.sqrt((x2 - x1)^2 + (y2 - y1)^2)
end

function resetGame()
    player.x = love.graphics.getWidth() / 2
    player.y = love.graphics.getHeight() / 2
    player.w = 45 
    player.h = 45 
    player.angle = 0
    player.speed = 200
    player.rotSpeed = 5
    player.health = 2
    player.maxHealth = 2 
    player.shootTimer = 0      
    player.shootCooldown = 1.5 
    score = 0
    scoreTimer = 0 
    enemiesDefeated = 0
    bossActive = false
    godMode = false
    showHitboxes = false
    
    bullets = {}
    enemyBullets = {}
    enemies = {}
    enemySpawnTimer = 0
    hitSoundTimer = 0
    struckSoundTimer = 0

    if bgMusic then
        bgMusic:stop()
        if not isMuted then bgMusic:play() end
    end
end

function love.load()
    playerImage = love.graphics.newImage("player.png")
    enemyImage = love.graphics.newImage("enemy.png")
    enemy2Image = love.graphics.newImage("enemy2.png")
    enemy3Image = love.graphics.newImage("enemy3.png")
    bulletImage = love.graphics.newImage("bullet1.png")
    
    hitSound = love.audio.newSource("Hit.wav", "static")
    struckSound = love.audio.newSource("Struck.wav", "static")
    
    -- Set base volumes lower to prevent clipping
    hitSound:setVolume(0.5)
    struckSound:setVolume(0.4) -- Struck is often "sharper," so we keep it lower
    
    bgMusic = love.audio.newSource("voltost.mp3", "stream")
    bgMusic:setLooping(true)
    bgMusic:setVolume(0.6)
    
    resetGame()
end

function processCommand(cmd)
    local cleanCmd = cmd:lower():gsub("%s+", "")
    if cleanCmd == "20" then
        enemiesDefeated = 20
        enemies = {} 
    elseif cleanCmd == "mute" then
        isMuted = not isMuted
        if isMuted then love.audio.setVolume(0) else love.audio.setVolume(1) end
    elseif cleanCmd == "god" then
        godMode = not godMode
    elseif cleanCmd == "boxes" then
        showHitboxes = not showHitboxes
    end
end

function love.textinput(t)
    if isPaused and t ~= "`" then
        commandBuffer = commandBuffer .. t
    end
end

function love.keypressed(key)
    if key == "`" then
        isPaused = not isPaused
        if not isPaused then commandBuffer = "" end
        return
    end

    if isPaused then
        if key == "backspace" then
            commandBuffer = commandBuffer:sub(1, -2)
        elseif key == "return" then
            processCommand(commandBuffer)
            commandBuffer = ""
            isPaused = false
        end
        return 
    end

    if key == "space" then
        if player.health <= 0 then
            resetGame()
        elseif player.shootTimer <= 0 then 
            table.insert(bullets, {x = player.x, y = player.y, w = 12, h = 12, angle = player.angle})
            player.shootTimer = player.shootCooldown 
            -- Player firing sound
            hitSoundTimer = playLimitedSound(hitSound, hitSoundTimer, hitCooldown)
        end
    end
end

function love.update(dt)
    if isPaused or player.health <= 0 then return end

    -- Countdown timers
    if hitSoundTimer > 0 then hitSoundTimer = hitSoundTimer - dt end
    if struckSoundTimer > 0 then struckSoundTimer = struckSoundTimer - dt end

    scoreTimer = scoreTimer + dt
    if scoreTimer >= 1 then
        score = score + 1
        scoreTimer = scoreTimer - 1 
    end

    if player.shootTimer > 0 then
        player.shootTimer = player.shootTimer - dt
    end

    if love.keyboard.isDown("a") then player.angle = player.angle - player.rotSpeed * dt end
    if love.keyboard.isDown("d") then player.angle = player.angle + player.rotSpeed * dt end
    if love.keyboard.isDown("w") then
        player.x = player.x + math.cos(player.angle) * player.speed * dt
        player.y = player.y + math.sin(player.angle) * player.speed * dt
    end
    if love.keyboard.isDown("s") then
        player.x = player.x - math.cos(player.angle) * player.speed * dt
        player.y = player.y - math.sin(player.angle) * player.speed * dt
    end

    player.x = clamp(player.x, 25, love.graphics.getWidth() - 25)
    player.y = clamp(player.y, 25, love.graphics.getHeight() - 25)

    -- Update Player Bullets
    for i = #bullets, 1, -1 do
        local b = bullets[i]
        b.x = b.x + math.cos(b.angle) * bulletSpeed * dt
        b.y = b.y + math.sin(b.angle) * bulletSpeed * dt

        local removed = false
        for j = #enemyBullets, 1, -1 do
            local eb = enemyBullets[j]
            if checkCollision(b.x, b.y, b.w, b.h, b.angle, eb.x, eb.y, eb.w, eb.h, eb.angle) then
                table.remove(bullets, i)
                table.remove(enemyBullets, j)
                removed = true
                break
            end
        end

        if not removed then
            for j = #enemies, 1, -1 do
                local e = enemies[j]
                local eAngle = math.atan2(player.y - e.y, player.x - e.x)
                if checkCollision(b.x, b.y, b.w, b.h, b.angle, e.x, e.y, e.w, e.h, eAngle) then
                    e.health = e.health - 1
                    table.remove(bullets, i)
                    -- IMPACT LIMITER
                    struckSoundTimer = playLimitedSound(struckSound, struckSoundTimer, struckCooldown)
                    if e.health <= 0 then
                        if e.isBoss then bossActive = false end
                        table.remove(enemies, j)
                        score = score + 1 
                        enemiesDefeated = enemiesDefeated + 1
                    end
                    removed = true
                    break 
                end
            end
        end
    end

    -- Update Enemy Bullets
    for i = #enemyBullets, 1, -1 do
        local eb = enemyBullets[i]
        eb.x = eb.x + math.cos(eb.angle) * (bulletSpeed * 0.6) * dt
        eb.y = eb.y + math.sin(eb.angle) * (bulletSpeed * 0.6) * dt

        if checkCollision(eb.x, eb.y, eb.w, eb.h, eb.angle, player.x, player.y, player.w, player.h, player.angle) then
            if not godMode then player.health = player.health - 1 end
            table.remove(enemyBullets, i)
            -- IMPACT LIMITER (Shared timer with enemy hits)
            struckSoundTimer = playLimitedSound(struckSound, struckSoundTimer, struckCooldown)
        end
    end

    -- Spawning
    enemySpawnTimer = enemySpawnTimer + dt
    if not bossActive then
        if enemiesDefeated >= 20 then
            table.insert(enemies, {x = 400, y = -50, w = 70, h = 70, speed = player.speed * 0.4, shootTimer = 0, health = 4, isBoss = true, img = enemy2Image})
            bossActive = true
            enemiesDefeated = 0
        elseif enemySpawnTimer > 3 then
            local side = love.math.random(1, 4)
            local ex, ey
            if side == 1 then ex, ey = -50, love.math.random(0, 600)
            elseif side == 2 then ex, ey = 850, love.math.random(0, 600)
            elseif side == 3 then ex, ey = love.math.random(0, 800), -50
            else ex, ey = love.math.random(0, 800), 650 end
            table.insert(enemies, {x = ex, y = ey, w = 45, h = 45, speed = player.speed * 0.5, shootTimer = 0, health = 1, isBoss = false, img = enemyImage})
            enemySpawnTimer = 0
        end
    end

    -- Enemy AI & Shooting
    for i = #enemies, 1, -1 do
        local e = enemies[i]
        local angleToPlayer = math.atan2(player.y - e.y, player.x - e.x)
        if distance(e.x, e.y, player.x, player.y) > 250 then
            e.x = e.x + math.cos(angleToPlayer) * e.speed * dt
            e.y = e.y + math.sin(angleToPlayer) * e.speed * dt
        end
        e.shootTimer = e.shootTimer + dt
        if e.shootTimer > 2 then
            table.insert(enemyBullets, {x = e.x, y = e.y, w = 12, h = 12, angle = angleToPlayer})
            e.shootTimer = 0
            -- Enemy firing sound
            hitSoundTimer = playLimitedSound(hitSound, hitSoundTimer, hitCooldown)
        end
    end
end

function love.draw()
    -- DRAW GRID
    love.graphics.clear(0.1, 0.3, 0.1) 
    love.graphics.setColor(0.12, 0.35, 0.12)
    for x = 0, love.graphics.getWidth(), 50 do
        for y = 0, love.graphics.getHeight(), 50 do
            if (x + y) % 100 == 0 then love.graphics.rectangle("fill", x, y, 50, 50) end
        end
    end

    -- DRAW UI
    love.graphics.setColor(1, 1, 1)
    local displayHP = godMode and "GOD" or math.max(0, (player.health / player.maxHealth) * 100)
    love.graphics.print("HP: " .. displayHP .. (godMode and "" or "%"), 10, 10)
    love.graphics.printf("Score: " .. score, 0, 10, love.graphics.getWidth() - 10, "right")
    
    if player.health > 0 then
        local barX = (love.graphics.getWidth() / 2) - 100
        love.graphics.setColor(0.3, 0.3, 0.3)
        love.graphics.rectangle("line", barX, 20, 200, 15)
        love.graphics.setColor(player.shootTimer <= 0 and {0, 1, 0} or {1, 1, 0})
        love.graphics.rectangle("fill", barX, 20, math.max(0, (1 - (player.shootTimer / player.shootCooldown)) * 200), 15)
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("COOLDOWN", 0, 38, love.graphics.getWidth(), "center")
    else
        love.graphics.printf("GAME OVER\nFinal Score: "..score.."\nSPACE to Restart", 0, love.graphics.getHeight()/2 - 30, love.graphics.getWidth(), "center")
        return
    end

    -- DRAW BULLETS
    for _, b in ipairs(bullets) do
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(bulletImage, b.x, b.y, b.angle + math.pi/2, 1, 1, bulletImage:getWidth()/2, bulletImage:getHeight()/2)
    end
    for _, eb in ipairs(enemyBullets) do
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(bulletImage, eb.x, eb.y, eb.angle + math.pi/2, 1, 1, bulletImage:getWidth()/2, bulletImage:getHeight()/2)
    end

    -- DRAW ENEMIES
    for _, e in ipairs(enemies) do
        local eAngle = math.atan2(player.y - e.y, player.x - e.x)
        love.graphics.setColor(1, 1, 1)
        love.graphics.push()
        love.graphics.translate(e.x, e.y)
        love.graphics.rotate(eAngle + math.pi / 2)
        love.graphics.draw(e.img, 0, 0, 0, 1, 1, e.img:getWidth()/2, e.img:getHeight()/2)
        love.graphics.pop()
    end

    -- DRAW PLAYER
    love.graphics.push()
    love.graphics.translate(player.x, player.y)
    love.graphics.rotate(player.angle + math.pi / 2) 
    love.graphics.draw(playerImage, 0, 0, 0, 1, 1, playerImage:getWidth()/2, playerImage:getHeight()/2)
    love.graphics.pop()

    if isPaused then
        love.graphics.setColor(0, 0, 0, 0.8)
        love.graphics.rectangle("fill", 0, love.graphics.getHeight() - 40, love.graphics.getWidth(), 40)
        love.graphics.setColor(0, 1, 0)
        love.graphics.print("> " .. commandBuffer .. "_", 10, love.graphics.getHeight() - 30)
    end
end
