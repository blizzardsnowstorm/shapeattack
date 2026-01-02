local player = {}
local bullets = {}
local enemyBullets = {}
local enemies = {}
local enemySpawnTimer = 0
local bulletSpeed = 500
local score = 0

function resetGame()
    player.x = love.graphics.getWidth() / 2
    player.y = love.graphics.getHeight() / 2
    player.angle = 0
    player.speed = 200
    player.rotSpeed = 5
    player.health = 2
    player.shootTimer = 0      -- Current timer state
    player.shootCooldown = 1.5 -- 1.5 seconds between shots
    score = 0
    
    bullets = {}
    enemyBullets = {}
    enemies = {}
    enemySpawnTimer = 0
end

function love.load()
    resetGame()
end

local function distance(x1, y1, x2, y2)
    return math.sqrt((x2 - x1)^2 + (y2 - y1)^2)
end

function love.update(dt)
    if player.health <= 0 then return end

    -- Handle Player Shoot Cooldown
    if player.shootTimer > 0 then
        player.shootTimer = player.shootTimer - dt
    end

    -- 1. Player Movement & Rotation
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

    -- 2. Update Player Bullets & Collision
    for i = #bullets, 1, -1 do
        local b = bullets[i]
        b.x = b.x + math.cos(b.angle) * bulletSpeed * dt
        b.y = b.y + math.sin(b.angle) * bulletSpeed * dt

        for j = #enemies, 1, -1 do
            local e = enemies[j]
            if distance(b.x, b.y, e.x, e.y) < 30 then
                table.remove(enemies, j)
                table.remove(bullets, i)
                score = score + 1
                break 
            end
        end
    end

    -- 3. Update Enemy Bullets
    for i = #enemyBullets, 1, -1 do
        local eb = enemyBullets[i]
        eb.x = eb.x + math.cos(eb.angle) * (bulletSpeed * 0.6) * dt
        eb.y = eb.y + math.sin(eb.angle) * (bulletSpeed * 0.6) * dt

        if distance(eb.x, eb.y, player.x, player.y) < 25 then
            player.health = player.health - 1
            table.remove(enemyBullets, i)
        end
    end

    -- 4. Enemy Spawning
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

    -- 5. Enemy Behavior
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
            table.insert(enemyBullets, {x = e.x, y = e.y, angle = angleToPlayer})
            e.shootTimer = 0
        end
    end
end

function love.keypressed(key)
    if key == "space" then
        if player.health <= 0 then
            resetGame()
        elseif player.shootTimer <= 0 then -- Only shoot if cooldown is over
            table.insert(bullets, {x = player.x, y = player.y, angle = player.angle})
            player.shootTimer = player.shootCooldown -- Reset the timer
        end
    end
end

function love.draw()
    -- Draw UI
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("HP: " .. player.health, 10, 10)
    love.graphics.printf("Score: " .. score, 0, 10, love.graphics.getWidth() - 10, "right")
    
    -- Visual cooldown bar (Optional but helpful)
    if player.health > 0 then
        love.graphics.setColor(0.3, 0.3, 0.3)
        love.graphics.rectangle("line", 10, 30, 100, 10)
        if player.shootTimer <= 0 then
            love.graphics.setColor(0, 1, 0) -- Green when ready
        else
            love.graphics.setColor(1, 1, 0) -- Yellow when recharging
        end
        local barWidth = math.max(0, (1 - (player.shootTimer / player.shootCooldown)) * 100)
        love.graphics.rectangle("fill", 10, 30, barWidth, 10)
    end

    if player.health <= 0 then
        love.graphics.printf("GAME OVER", 0, love.graphics.getHeight()/2 - 20, love.graphics.getWidth(), "center")
        love.graphics.printf("Final Score: " .. score, 0, love.graphics.getHeight()/2 + 10, love.graphics.getWidth(), "center")
        love.graphics.printf("Press SPACE to Restart", 0, love.graphics.getHeight()/2 + 40, love.graphics.getWidth(), "center")
        return
    end

    -- Draw Player Bullets
    love.graphics.setColor(1, 1, 0)
    for _, b in ipairs(bullets) do
        love.graphics.circle("fill", b.x, b.y, 5)
    end

    -- Draw Enemy Bullets
    love.graphics.setColor(1, 0, 0)
    for _, eb in ipairs(enemyBullets) do
        love.graphics.circle("fill", eb.x, eb.y, 5)
    end

    -- Draw Enemies
    for _, e in ipairs(enemies) do
        love.graphics.push()
        love.graphics.translate(e.x, e.y)
        love.graphics.rotate(math.atan2(player.y - e.y, player.x - e.x))
        love.graphics.setColor(1, 0, 0)
        love.graphics.rectangle("fill", -25, -25, 50, 50)
        love.graphics.setColor(0.5, 0, 0)
        love.graphics.rectangle("fill", 25, -5, 30, 10)
        love.graphics.pop()
    end

    -- Draw Player
    love.graphics.push()
    love.graphics.translate(player.x, player.y)
    love.graphics.rotate(player.angle)
    love.graphics.setColor(1, 0, 1)
    love.graphics.rectangle("fill", -25, -25, 50, 50)
    love.graphics.setColor(0.8, 0.8, 0.8)
    love.graphics.rectangle("fill", 25, -5, 30, 10)
    love.graphics.pop()
end
