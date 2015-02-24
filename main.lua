local matrix = require 'matrix'


local borderVerticalOffset = 10
local borderHorizontalOffset = 20

local paddleHeight = 100
local paddleWidth = 25
local paddleSpeed = 500

local gameSpeed = 2

local numberSuccess = 0

local Q = nil
local LEARNINGRATE = 0.7
local DISCOUNT = 0.999
local ACTIONS = {'UP', 'DOWN'}
local CURSTATE = {x = 0, y = 0}
local LASTSTATE = nil
local LASTACTION = nil

local tickCounter = 0
local tickUpdateCount = gameSpeed / 100

local generation = 1

function love.load()

	WINDOW_HEIGHT = 500
	WINDOW_WIDTH = 500

	Q = matrix:new(WINDOW_WIDTH, WINDOW_HEIGHT)

	p1 = {x = borderHorizontalOffset, y = WINDOW_HEIGHT / 2 - paddleHeight / 2}
	p2 = {x = WINDOW_WIDTH - borderHorizontalOffset - paddleWidth, y = WINDOW_HEIGHT / 2 - paddleHeight / 2}
	ball = {x = 100, y = 100, speed_h = 200, speed_v = 0, dir_h = 1, dir_v = 1, size = 25}

	love.window.setMode(WINDOW_WIDTH, WINDOW_HEIGHT, {resizable=true, vsync=enableVsync, fsaa=0})

	initQ()
	ballReset()


end

function love.update(dt)

	if ball.x <= 0 or ball.x + ball.size >= WINDOW_WIDTH then
		nextGeneration()
	end

	tickCounter = tickCounter + (1 * dt) * gameSpeed
	if tickCounter >= tickUpdateCount then
		tickCounter = 0
		tick()
	end

	if love.keyboard.isDown('w') or CURACTION == 'UP' then
		p1.y = p1.y - paddleSpeed * dt * gameSpeed
	elseif love.keyboard.isDown('s') or CURACTION == 'DOWN' then
		p1.y = p1.y + paddleSpeed * dt * gameSpeed
	end 

	if love.keyboard.isDown('up') then
		p2.y = p2.y - paddleSpeed * dt * gameSpeed
	elseif love.keyboard.isDown('down') then
		p2.y = p2.y + paddleSpeed * dt * gameSpeed
	end 

	if p1.y > WINDOW_HEIGHT - borderVerticalOffset - paddleHeight then
		p1.y = WINDOW_HEIGHT - borderVerticalOffset - paddleHeight
	elseif p1.y < borderVerticalOffset then
		p1.y = borderVerticalOffset
	end

	if p2.y > WINDOW_HEIGHT - borderVerticalOffset - paddleHeight then
		p2.y = WINDOW_HEIGHT - borderVerticalOffset - paddleHeight
	elseif p2.y < borderVerticalOffset then
		p2.y = borderVerticalOffset
	end

	if ball.dir_h > 0 then
		if isBallBetweenPaddle(ball, p2) then
			if ball.x >= p2.x - ball.size then
				ballCollided(ball, p2)
				ball.x = p2.x - ball.size
				ball.dir_h = -1
			end
		end
	else
		if isBallBetweenPaddle(ball, p1) then
			if ball.x <= p1.x + paddleWidth then
				ballCollided(ball, p1)
				ball.x = p1.x + paddleWidth
				ball.dir_h = 1
			end
		end
	end

	if ball.y < borderVerticalOffset then
		ball.y = borderVerticalOffset
		ball.dir_v = -ball.dir_v
	elseif ball.y > WINDOW_HEIGHT - borderVerticalOffset - ball.size then
		ball.y = WINDOW_HEIGHT - borderVerticalOffset - ball.size
		ball.dir_v = -ball.dir_v
	end

	--print(ball.dir_v)

	ball.x = ball.x + (ball.speed_h * dt * gameSpeed) * ball.dir_h
	ball.y = ball.y + (ball.speed_v * dt * gameSpeed) * ball.dir_v

end

function love.draw()
	love.graphics.rectangle('fill', p1.x, p1.y, 25, paddleHeight)
	love.graphics.rectangle('fill', p2.x, p2.y, 25, paddleHeight)
	love.graphics.rectangle('fill', ball.x, ball.y, ball.size, ball.size)
	love.graphics.print('Generation: ' .. generation, WINDOW_WIDTH / 2, 25)
	love.graphics.print('Game Speed: ' .. gameSpeed, WINDOW_WIDTH / 2, 50)
end

function love.resize(w, h)
	WINDOW_HEIGHT = h
	WINDOW_WIDTH = w
end

function love.keypressed(key)
	if key == '=' then
		if gameSpeed < 5 then
			gameSpeed = gameSpeed + 1
		end
	elseif key == '-' then
		if gameSpeed > 1 then
			gameSpeed = gameSpeed - 1
		end
	end
end

function isBallBetweenPaddle(_ball, _paddle)
	if _ball.y + _ball.size >= _paddle.y and _ball.y <= _paddle.y + paddleHeight then
		return true
	else
		return false
	end
end

function ballCollided(_ball, _paddle)
	if _paddle.x == p1.x then
		love.graphics.setBackgroundColor(0, 100, 0)
		numberSuccess = numberSuccess + 1
	end
	--print('collision')

	if true then
		ball.speed_v = 75
		ball.dir_v = 1
	elseif ball.y + ball.size >= _paddle.y and ball.y < _paddle.y + paddleHeight / 4 then
		ball.speed_v = 100
	elseif ball.y >= _paddle.y + paddleHeight / 4 and ball.y < _paddle.y + paddleHeight / 2 then
		ball.speed_v = 25
	elseif ball.y >= _paddle.y + paddleHeight / 2 and ball.y < _paddle.y + paddleHeight - (paddleHeight / 4) then
		ball.speed_v = 25
	elseif ball.y >= _paddle.y + paddleHeight - (paddleHeight / 4) and ball.y < _paddle.y + paddleHeight then
		ball.speed_v = 100
	else
		ball.speed_v = 0
	end
end

function initQ()
	local iter = matrix.ipairs(Q)
	for i, j in iter do
		matrix.setelement(Q, i, j, {0, 0})
	end
	-- local iter = matrix.ipairs(Q)
	-- for i, j in iter do
	-- 	print(matrix.getelement(Q, i, j)[1])
	-- end
end

function tick()
	LASTSTATE = CURSTATE
	LASTACTION = CURACTION
	CURSTATE.x = math.floor(ball.x)
	CURSTATE.y = math.floor(ball.y)
	CURACTION = getBestAction()
	if CURACTION and CURSTATE and LASTSTATE and LASTACTION then
		setQBasedOnAlgo(CURSTATE, CURACTION, LASTSTATE, LASTACTION)
	end
	--if getRewardFromState(CURSTATE)
	--print(CURACTION)
end

function setQBasedOnAlgo(curstate, curaction, laststate, lastaction)
	local s = laststate
	local a = lastaction
	local sprime = curstate
	local aprime = curaction

	local reward = getRewardFromState(s, a)

	-- print(getQ( sprime, 'UP' ), getQ( sprime, 'DOWN' ))

	local newQ = getQ(s, a) + LEARNINGRATE * ( reward + ( DISCOUNT * math.max( getQ( sprime, 'UP' ), getQ( sprime, 'DOWN' ) ) ) - getQ(s, a))

	setQ(laststate, lastaction, newQ)

end

function getBestAction()
	local a1 = getQ(CURSTATE, 'UP')
	local a2 = getQ(CURSTATE, 'DOWN')

	if a1 == nil or a2 == nil then
		return ACTIONS[flip()]
	elseif a2 == a1 then
		return ACTIONS[flip()]
	elseif a1 > a2 then
		return 'UP'
	elseif a2 > a1 then
		return 'DOWN'
	end

end

function setQ(state, action, value)
	-- print(state.x, state.y)

	if state.x < 1 or state.x > WINDOW_WIDTH or state.y < 1 or state.y > WINDOW_HEIGHT then
		return nil
	end

	if action == 'UP' then
		matrix.getelement(Q, state.x, state.y)[1] = value
		--print('up  ', matrix.getelement(Q, state.x, state.y)[1])
	elseif action == 'DOWN' then
		matrix.getelement(Q, state.x, state.y)[2] = value
		--print('down', matrix.getelement(Q, state.x, state.y)[2])
	end
end

function getQ(state, action)

	if state.x < 1 or state.x > WINDOW_WIDTH or state.y < 1 or state.y > WINDOW_HEIGHT then
		return -1000
	end

	if action == 'UP' then
		return matrix.getelement(Q, state.x, state.y)[1]
	elseif action == 'DOWN' then
		return matrix.getelement(Q, state.x, state.y)[2]
	else
		--print('NOPE')
	end
end

function QContains(key, value)
	return matrix.getelement(Q, key, value)
end

	--//TICK IS NOT REGISTERING THAT THE BALL WENT OUT OF BOUNDS... INCREASE TICK SPEED????

function getRewardFromState(CURSTATE)
	if isBallOutOfBoundsLeft(CURSTATE.x) then
		return -1000
	elseif isBallOutOfBoundsRight(CURSTATE.x) then
		return 1000
	else
		return 1
	end
end

function flip()
	local num = math.random()
	if num > 0.5 then
		return 1
	else
		return 2
	end

end

function ballReset()
	ball.x = WINDOW_WIDTH / 2
	ball.y = WINDOW_HEIGHT / 2
	ball.dir_h = 1
	ball.speed_v = 0 --math.random(-100, 100)
end

function nextGeneration()

	love.graphics.setBackgroundColor(0, 0, 0)

	print('Success Percent:', (numberSuccess / generation))

	generation = generation + 1
	ballReset()
	p1.y = WINDOW_HEIGHT / 2 - paddleHeight / 2
	p2.y = WINDOW_HEIGHT / 2 - paddleHeight / 2
end

function isBallOutOfBoundsLeft(x)
	if x < borderHorizontalOffset then
		return true
	else
		return false
	end
end

function isBallOutOfBoundsRight(x)
	if x >= WINDOW_WIDTH - borderHorizontalOffset - ball.size then
		return true
	else
		return false
	end
end