local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")

local visitedPlayers = {} -- List of players already visited
local tweenSpeed = 30
local stayDuration = 15
local isRunning = false
local currentTween = nil
local waitingForResponse = false
local currentTargetPlayer = nil

-- Create GUI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PlayerTrackerGUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 200, 0, 140)
frame.Position = UDim2.new(0.5, -100, 0, 20)
frame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
frame.BorderSizePixel = 2
frame.BorderColor3 = Color3.fromRGB(255, 255, 255)
frame.Active = true
frame.Draggable = true
frame.Parent = screenGui

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -30, 0, 30)
title.Position = UDim2.new(0, 0, 0, 0)
title.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
title.BorderSizePixel = 0
title.Text = "Player Tracker"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextSize = 16
title.Font = Enum.Font.GothamBold
title.Parent = frame

local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.new(0, 30, 0, 30)
closeButton.Position = UDim2.new(1, -30, 0, 0)
closeButton.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
closeButton.BorderSizePixel = 0
closeButton.Text = "X"
closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
closeButton.TextSize = 18
closeButton.Font = Enum.Font.GothamBold
closeButton.Parent = frame

local toggleButton = Instance.new("TextButton")
toggleButton.Size = UDim2.new(0, 160, 0, 35)
toggleButton.Position = UDim2.new(0.5, -80, 0, 40)
toggleButton.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
toggleButton.BorderSizePixel = 0
toggleButton.Text = "START"
toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleButton.TextSize = 18
toggleButton.Font = Enum.Font.GothamBold
toggleButton.Parent = frame

local clearButton = Instance.new("TextButton")
clearButton.Size = UDim2.new(0, 160, 0, 35)
clearButton.Position = UDim2.new(0.5, -80, 0, 90)
clearButton.BackgroundColor3 = Color3.fromRGB(255, 150, 50)
clearButton.BorderSizePixel = 0
clearButton.Text = "CLEAR LIST"
clearButton.TextColor3 = Color3.fromRGB(255, 255, 255)
clearButton.TextSize = 16
clearButton.Font = Enum.Font.GothamBold
clearButton.Parent = frame

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = frame

local buttonCorner = Instance.new("UICorner")
buttonCorner.CornerRadius = UDim.new(0, 6)
buttonCorner.Parent = toggleButton

local clearButtonCorner = Instance.new("UICorner")
clearButtonCorner.CornerRadius = UDim.new(0, 6)
clearButtonCorner.Parent = clearButton

-- Function to send a chat message (updated for new chat system)
local function sendChatMessage(message)
	-- Try new TextChatService first
	if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
		local textChannel = TextChatService.TextChannels:FindFirstChild("RBXGeneral")
		if textChannel then
			textChannel:SendAsync(message)
		end
	else
		-- Fallback to legacy chat
		local ReplicatedStorage = game:GetService("ReplicatedStorage")
		local remoteEvent = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
		if remoteEvent then
			local sayMessageRequest = remoteEvent:FindFirstChild("SayMessageRequest")
			if sayMessageRequest then
				sayMessageRequest:FireServer(message, "All")
			end
		end
	end
end

-- Function to check if message contains yes or no
local function checkResponse(message)
	local lowerMessage = string.lower(message)
	-- Remove spaces and check for yes/no variations
	lowerMessage = string.gsub(lowerMessage, "%s+", "")
	
	if string.find(lowerMessage, "yes") or string.find(lowerMessage, "ye") or string.find(lowerMessage, "y") then
		return "yes"
	elseif string.find(lowerMessage, "no") or string.find(lowerMessage, "nah") or string.find(lowerMessage, "nope") then
		return "no"
	end
	
	return nil
end

-- Function to get the closest unvisited player
local function getClosestPlayer()
	local closestPlayer = nil
	local shortestDistance = math.huge

	for _, otherPlayer in pairs(Players:GetPlayers()) do
		if otherPlayer ~= player and not visitedPlayers[otherPlayer.UserId] then
			if otherPlayer.Character and otherPlayer.Character:FindFirstChild("HumanoidRootPart") then
				local distance = (humanoidRootPart.Position - otherPlayer.Character.HumanoidRootPart.Position).Magnitude

				if distance < shortestDistance then
					shortestDistance = distance
					closestPlayer = otherPlayer
				end
			end
		end
	end

	return closestPlayer
end

-- Function to continuously follow a player
local function followPlayer(targetPlayer, duration)
	local startTime = tick()
	while tick() - startTime < duration and isRunning do
		if not targetPlayer.Character or not targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
			break
		end

		local targetRoot = targetPlayer.Character.HumanoidRootPart

		-- Quick tween to follow the player (stay in front)
		currentTween = TweenService:Create(humanoidRootPart, TweenInfo.new(0.1), {
			CFrame = targetRoot.CFrame * CFrame.new(0, 0, -3)
		})

		currentTween:Play()
		wait(0.1)
	end
end

-- Function to tween to a player and stay on them
local function tweenToPlayer(targetPlayer)
	if not targetPlayer or not targetPlayer.Character then return end

	local targetRoot = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
	if not targetRoot then return end

	currentTargetPlayer = targetPlayer

	-- Calculate distance and tween time
	local distance = (humanoidRootPart.Position - targetRoot.Position).Magnitude
	local tweenTime = distance / tweenSpeed

	-- Create tween info
	local tweenInfo = TweenInfo.new(
		tweenTime,
		Enum.EasingStyle.Linear,
		Enum.EasingDirection.InOut
	)

	-- Create and play tween (go to front of player)
	currentTween = TweenService:Create(humanoidRootPart, tweenInfo, {
		CFrame = targetRoot.CFrame * CFrame.new(0, 0, -3) -- Stay 3 studs in front
	})

	currentTween:Play()
	currentTween.Completed:Wait()

	if not isRunning then return end

	-- Send initial message
	sendChatMessage("I made a printer script for anomic it makes 150k a hour. do you want? Yes or no?")
	
	-- Wait for response for 15 seconds
	waitingForResponse = true
	local responseReceived = false
	local saidYes = false
	local waitStartTime = tick()
	
	while tick() - waitStartTime < stayDuration and isRunning do
		if not targetPlayer.Character or not targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
			break
		end

		targetRoot = targetPlayer.Character.HumanoidRootPart

		-- Quick tween to follow the player while waiting
		currentTween = TweenService:Create(humanoidRootPart, TweenInfo.new(0.1), {
			CFrame = targetRoot.CFrame * CFrame.new(0, 0, -3)
		})

		currentTween:Play()
		wait(0.1)
		
		-- Check if response was received
		if not waitingForResponse then
			responseReceived = true
			break
		end
	end

	-- Mark player as visited
	visitedPlayers[targetPlayer.UserId] = true
	waitingForResponse = false
	currentTargetPlayer = nil
end

-- Listen for chat messages (New TextChatService)
if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
	TextChatService.MessageReceived:Connect(function(message)
		if not waitingForResponse or not currentTargetPlayer then return end
		
		-- Check if message is from current target player
		if message.TextSource and message.TextSource.UserId == currentTargetPlayer.UserId then
			local response = checkResponse(message.Text)
			
			if response == "yes" then
				sendChatMessage("igotdas on blue")
				wait(0.5)
				waitingForResponse = false
				-- Stay for 30 seconds so they can type it in
				followPlayer(currentTargetPlayer, 30)
			elseif response == "no" then
				waitingForResponse = false
				-- Move to next player immediately
			end
		end
	end)
else
	-- Listen for chat messages (Legacy Chat)
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local chatEvents = ReplicatedStorage:WaitForChild("DefaultChatSystemChatEvents")
	local onMessageDoneFiltering = chatEvents:WaitForChild("OnMessageDoneFiltering")
	
	onMessageDoneFiltering.OnClientEvent:Connect(function(messageData)
		if not waitingForResponse or not currentTargetPlayer then return end
		
		-- Check if message is from current target player
		local fromPlayer = Players:FindFirstChild(messageData.FromSpeaker)
		if fromPlayer and fromPlayer.UserId == currentTargetPlayer.UserId then
			local response = checkResponse(messageData.Message)
			
			if response == "yes" then
				sendChatMessage("igotdas on blue")
				wait(0.5)
				waitingForResponse = false
				-- Stay for 30 seconds so they can type it in
				followPlayer(currentTargetPlayer, 30)
			elseif response == "no" then
				waitingForResponse = false
				-- Move to next player immediately
			end
		end
	end)
end

-- Main tracking loop
local function startTracking()
	while isRunning do
		local targetPlayer = getClosestPlayer()

		if targetPlayer then
			tweenToPlayer(targetPlayer)
		else
			print("All players have been visited!")
			isRunning = false
			toggleButton.Text = "START"
			toggleButton.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
			break
		end

		wait(1) -- Small delay before finding next player
	end
end

-- Toggle button functionality
toggleButton.MouseButton1Click:Connect(function()
	isRunning = not isRunning

	if isRunning then
		toggleButton.Text = "STOP"
		toggleButton.BackgroundColor3 = Color3.fromRGB(50, 255, 50)
		startTracking()
	else
		toggleButton.Text = "START"
		toggleButton.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
		if currentTween then
			currentTween:Cancel()
		end
		waitingForResponse = false
	end
end)

-- Close button functionality
closeButton.MouseButton1Click:Connect(function()
	isRunning = false
	waitingForResponse = false
	if currentTween then
		currentTween:Cancel()
	end
	screenGui:Destroy()
end)

-- Clear list button functionality
clearButton.MouseButton1Click:Connect(function()
	visitedPlayers = {}
	print("Visited players list cleared!")
end)
