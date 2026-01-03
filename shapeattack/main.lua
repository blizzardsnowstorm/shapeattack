local player = {}
local bullets = {}
local enemyBullets = {}
local enemies = {}
local enemySpawnTimer = 0
local scoreTimer = 0 
local bulletSpeed = 500
local score = 0
local playerImage 
local enemyImage

-- Audio handles
local hitSound
local struckSound
local bgMusic 

local function clamp(val, min, max)
    return math.max(min, math.min(val, max))
end

function resetGame()
    player.x = love.graphics.getWidth() / 2
    player.y = love.graphics.getHeight() / 2
    player.angle = 0
    player.speed = 200
    player.rotSpeed = 5
    player.health = 2
    player.maxHealth = 2 -- Added to calculate percentage
    player.shootTimer = 0      
    player.shootCooldown = 1.5 
    score = 0
    scoreTimer = 0 
    
    bullets = {}
    enemyBullets = {}
    enemies = {}
    enemySpawnTimer = 0

    if bgMusic then
        bgMusic:stop()
        bgMusic:play()
    end
end

function love.load()
    playerImage = love.graphics.newImage("player.png")
    enemyImage = love.graphics.newImage("enemy.png")
    
    hitSound = love.audio.newSource("Hit.wav", "static")
    struckSound = love.audio.newSource("Struck.wav", "static")
    
    bgMusic = love.audio.newSource("voltost.mp3", "stream")
    bgMusic:setLooping(true)
    bgMusic:setVolume(0.6)
    
    resetGame()
end

local function distance(x1, y1, x2, y2)
    return math.sqrt((x2 - x1)^2 + (y2 - y1)^2)
end

function love.update(dt)
    if player.health <= 0 then return end

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
            if distance(b.x, b.y, eb.x, eb.y) < 10 then
                table.remove(bullets, i)
                table.remove(enemyBullets, j)
                removed = true
                break
            end
        end

        if not removed then
            for j = #enemies, 1, -1 do
                local e = enemies[j]
                if distance(b.x, b.y, e.x, e.y) < 30 then
                    table.remove(enemies, j)
                    table.remove(bullets, i)
                    score = score + 1 
                    struckSound:clone():play()
                    break 
                end
            end
        end
    end

    -- Update Enemy Bullets
    for i = #enemyBullets, 1, -1 do
        local eb1 = enemyBullets[i]
        if eb1 then
            eb1.x = eb1.x + math.cos(eb1.angle) * (bulletSpeed * 0.6) * dt
            eb1.y = eb1.y + math.sin(eb1.angle) * (bulletSpeed * 0.6) * dt

            local ebRemoved = false
            for j = #enemyBullets, 1, -1 do
                if i ~= j then
                    local eb2 = enemyBullets[j]
                    if eb2 and distance(eb1.x, eb1.y, eb2.x, eb2.y) < 10 then
                        table.remove(enemyBullets, math.max(i, j))
                        table.remove(enemyBullets, math.min(i, j))
                        ebRemoved = true
                        break
                    end
                end
            end

            if not ebRemoved then
                for j = #enemies, 1, -1 do
                    local e = enemies[j]
                    if distance(eb1.x, eb1.y, e.x, e.y) < 30 then
                        table.remove(enemies, j)
                        table.remove(enemyBullets, i)
                        struckSound:clone():play()
                        ebRemoved = true
                        break
                    end
                end
            end

            if not ebRemoved then
                if distance(eb1.x, eb1.y, player.x, player.y) < 25 then
                    player.health = player.health - 1
                    table.remove(enemyBullets, i)
                    struckSound:clone():play()
                end
            end
        end
    end

    -- Enemy Spawning
    enemySpawnTimer = enemySpawnTimer + dt
    if enemySpawnTimer > 3 then
        local side = love.math.random(1, 4)
        local ex, ey
        if side == 1 then ex, ey = -50, love.math.random(0, 600)
        elseif side == 2 then ex, ey = 850, love.math.random(0, 600)
        elseif side == 3 then ex, ey = love.math.random(0, 800), -50
        else ex, ey = love.math.random(0, 800), 650 end
        table.insert(enemies, {x = ex, y = ey, speed = player.speed * 0.5, shootTimer = 0})
        enemySpawnTimer = 0
    end

    -- Enemy AI and Shooting
    for i = #enemies, 1, -1 do
        local e = enemies[i]
        local distToPlayer = distance(e.x, e.y, player.x, player.y)
        local angleToPlayer = math.atan2(player.y - e.y, player.x - e.x)
        if distToPlayer > 250 then
            e.x = e.x + math.cos(angleToPlayer) * e.speed * dt
            e.y = e.y + math.sin(angleToPlayer) * e.speed * dt
        end
        e.shootTimer = e.shootTimer + dt
        if e.shootTimer > 2 then
            local spawnX = e.x + math.cos(angleToPlayer) * 40
            local spawnY = e.y + math.sin(angleToPlayer) * 40
            table.insert(enemyBullets, {x = spawnX, y = spawnY, angle = angleToPlayer})
            e.shootTimer = 0
            hitSound:clone():play()
        end
    end
end

function love.keypressed(key)
    if key == "space" then
        if player.health <= 0 then
            resetGame()
        elseif player.shootTimer <= 0 then 
            table.insert(bullets, {x = player.x, y = player.y, angle = player.angle})
            player.shootTimer = player.shootCooldown 
            hitSound:clone():play()
        end
    end
end

function love.draw()
    love.graphics.clear(0.1, 0.3, 0.1) 
    love.graphics.setColor(0.12, 0.35, 0.12)
    local size = 50
    for x = 0, love.graphics.getWidth(), size do
        for y = 0, love.graphics.getHeight(), size do
            if (x + y) % (size * 2) == 0 then
                love.graphics.rectangle("fill", x, y, size, size)
            end
        end
    end

    -- DRAW UI
    love.graphics.setColor(1, 1, 1)
    
    -- Calculate HP percentage
    local hpPercent = math.max(0, (player.health / player.maxHealth) * 100)
    love.graphics.print("HP: " .. hpPercent .. "%", 10, 10)
    
    love.graphics.printf("Score: " .. score, 0, 10, love.graphics.getWidth() - 10, "right")
    
    if player.health > 0 then
        -- CENTER TOP COOLDOWN BAR
        local fullBarWidth = 200
        local barHeight = 15
        local barX = (love.graphics.getWidth() / 2) - (fullBarWidth / 2)
        local barY = 20

        -- Background of bar
        love.graphics.setColor(0.3, 0.3, 0.3)
        love.graphics.rectangle("line", barX, barY, fullBarWidth, barHeight)
        
        -- Fill of bar
        if player.shootTimer <= 0 then
            love.graphics.setColor(0, 1, 0) -- Green when ready
        else
            love.graphics.setColor(1, 1, 0) -- Yellow when charging
        end
        
        local currentFillWidth = math.max(0, (1 - (player.shootTimer / player.shootCooldown)) * fullBarWidth)
        love.graphics.rectangle("fill", barX, barY, currentFillWidth, barHeight)
        
        -- Label for the bar
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("COOLDOWN", 0, barY + 18, love.graphics.getWidth(), "center")
    end

    if player.health <= 0 then
        love.graphics.setColor(0, 0, 0, 0.5)
        love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("GAME OVER", 0, love.graphics.getHeight()/2 - 20, love.graphics.getWidth(), "center")
        love.graphics.printf("Final Score: " .. score, 0, love.graphics.getHeight()/2 + 10, love.graphics.getWidth(), "center")
        love.graphics.printf("Press SPACE to Restart", 0, love.graphics.getHeight()/2 + 40, love.graphics.getWidth(), "center")
        return
    end

    -- Draw Bullets
    love.graphics.setColor(1, 1, 0)
    for _, b in ipairs(bullets) do
        love.graphics.circle("fill", b.x, b.y, 5)
    end

    love.graphics.setColor(1, 0, 0)
    for _, eb in ipairs(enemyBullets) do
        love.graphics.circle("fill", eb.x, eb.y, 5)
    end

    -- Draw Enemies
    for _, e in ipairs(enemies) do
        love.graphics.push()
        love.graphics.translate(e.x, e.y)
        love.graphics.rotate(math.atan2(player.y - e.y, player.x - e.x) + math.pi / 2)
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(enemyImage, 0, 0, 0, 1, 1, enemyImage:getWidth()/2, enemyImage:getHeight()/2)
        love.graphics.pop()
    end

    -- Draw Player
    love.graphics.push()
    love.graphics.translate(player.x, player.y)
    love.graphics.rotate(player.angle + math.pi / 2) 
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(playerImage, 0, 0, 0, 1, 1, playerImage:getWidth()/2, playerImage:getHeight()/2)
    love.graphics.pop()
end
