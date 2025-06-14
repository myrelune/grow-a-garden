if game.PlaceId ~= 126884695634066 then
	return
end

while not game:IsLoaded() do
	game.Loaded:Wait()
end

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local selectedEggs = {}
local selectedSeeds = {}
local selectedGear = {}

local autoBuyEggs = false
local autoBuySeeds = false
local autoBuyGear = false

local seedData = require(ReplicatedStorage:WaitForChild("Data"):WaitForChild("SeedData"))
local seedNames = {}
for seedKey, seed in pairs(seedData) do
	if seed.DisplayInShop then
		table.insert(seedNames, seedKey)
	end
end

local gearData = require(ReplicatedStorage:WaitForChild("Data"):WaitForChild("GearData"))
local gearNames = {}
for _, gear in pairs(gearData) do
	if gear.DisplayInShop then
		table.insert(gearNames, gear.GearName)
	end
end

local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
local Window = Rayfield:CreateWindow({
	Name = "FarmHelper",
	LoadingTitle = "Grow a Garden",
	LoadingSubtitle = "By Myrelune",
	ConfigurationSaving = {
		Enabled = true,
		FolderName = "FarmHelper",
		FileName = "FarmHelper",
	},
	DisableRayfieldPrompts = true,
	ToggleUIKeybind = "U",
	Discord = {
		Enabled = true,
		Invite = "wB34Qa4zbr",
		RememberJoins = true,
	},
})

local ShopTab = Window:CreateTab("Shop", "store")

local _SeedDropdown = ShopTab:CreateDropdown({
	Name = "Select Seeds",
	Options = seedNames,
	CurrentOption = {},
	MultipleOptions = true,
	Flag = "SeedDropdown",
	Callback = function(Options)
		print(Options)
		selectedSeeds = Options
	end,
})

local _AutoBuySeedsToggle = ShopTab:CreateToggle({
	Name = "Auto Buy Seeds",
	Default = false,
	Flag = "AutoBuySeedsToggle",
	Callback = function(Value)
		autoBuySeeds = Value
	end,
})

local _GearDropdown = ShopTab:CreateDropdown({
	Name = "Select Gear",
	Options = gearNames,
	CurrentOption = {},
	MultipleOptions = true,
	Flag = "GearDropdown",
	Callback = function(Options)
		print(Options)
		selectedGear = Options
	end,
})

local _AutoBuyGearToggle = ShopTab:CreateToggle({
	Name = "Auto Buy Gear",
	Default = false,
	Flag = "AutoBuyGearToggle",
	Callback = function(Value)
		autoBuyGear = Value
	end,
})

local _EggDropdown = ShopTab:CreateDropdown({
	Name = "Select Eggs",
	Options = { "Common Egg", "Uncommon Egg", "Rare Egg", "Legendary Egg", "Mythical Egg", "Bug Egg" },
	CurrentOption = {},
	MultipleOptions = true,
	Flag = "EggDropdown",
	Callback = function(Options)
		print(Options)
		selectedEggs = Options
	end,
})

local _AutoBuyEggsToggle = ShopTab:CreateToggle({
	Name = "Auto Buy Eggs",
	Default = false,
	Flag = "AutoBuyEggsToggle",
	Callback = function(Value)
		autoBuyEggs = Value
	end,
})

local function getStockNumber(stockText)
	return tonumber(stockText:match("X(%d+)")) or 0
end

local function getAvailableItems()
	local gearShop = LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("Gear_Shop")
	local seedShop = LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("Seed_Shop")

	local availableItems = {}

	for _, item in pairs(gearShop.Frame.ScrollingFrame:GetChildren()) do
		if item:FindFirstChild("Main_Frame") and item.Main_Frame:FindFirstChild("Stock_Text") then
			local stockText = item.Main_Frame.Stock_Text.Text
			local stock = getStockNumber(stockText)
			if stock > 0 then
				table.insert(availableItems, {
					name = item.Name,
					stock = stock,
					shop = "Gear",
				})
			end
		end
	end

	for _, item in pairs(seedShop.Frame.ScrollingFrame:GetChildren()) do
		if item:FindFirstChild("Main_Frame") and item.Main_Frame:FindFirstChild("Stock_Text") then
			local stockText = item.Main_Frame.Stock_Text.Text
			local stock = getStockNumber(stockText)
			if stock > 0 then
				table.insert(availableItems, {
					name = item.Name,
					stock = stock,
					shop = "Seed",
				})
			end
		end
	end

	return availableItems
end

local function setupShopChecks()
	local lastCheck = 0
	RunService.Heartbeat:Connect(function()
		if tick() - lastCheck < 0.5 then
			return
		end
		lastCheck = tick()

		local ok, availableItems = pcall(getAvailableItems)
		if not ok then
			warn("[FarmHelper] Failed to get available items:", availableItems)
			return
		end

		local availableNames = {}
		for _, item in pairs(availableItems) do
			availableNames[item.name] = true
		end

		if autoBuyGear then
			for _, gearName in pairs(selectedGear) do
				local ok = pcall(function()
					if availableNames[gearName] then
						ReplicatedStorage:WaitForChild("GameEvents"):WaitForChild("BuyGearStock"):FireServer(gearName)
						Rayfield:Notify({
							Title = "Gear in Stock",
							Content = "Bought " .. gearName,
							Time = 0.5,
						})
					end
				end)
				if not ok then
					warn("[FarmHelper] Failed to buy gear:", gearName)
				end
			end
		end

		if autoBuySeeds then
			for _, seedName in pairs(selectedSeeds) do
				local ok = pcall(function()
					if availableNames[seedName] then
						ReplicatedStorage:WaitForChild("GameEvents"):WaitForChild("BuySeedStock"):FireServer(seedName)
						Rayfield:Notify({
							Title = "Seed in Stock",
							Content = "Bought " .. seedName,
							Time = 0.5,
						})
					end
				end)
				if not ok then
					warn("[FarmHelper] Failed to buy seed:", seedName)
				end
			end
		end

		if autoBuyEggs then
			local ok, eggLocationsFolder = pcall(function()
				return workspace:WaitForChild("NPCS"):WaitForChild("Pet Stand"):WaitForChild("EggLocations")
			end)
			if not ok then
				warn("[FarmHelper] Failed to get egg locations folder:", eggLocationsFolder)
				return
			end
			local eggLocations = eggLocationsFolder:GetChildren()

			for i, location in ipairs(eggLocations) do
				local success, err = pcall(function()
					if not location:IsA("BasePart") then
						return
					end

					local eggNameText = location.PetInfo.SurfaceGui.EggNameTextLabel.Text
					if not eggNameText then
						warn("[FarmHelper] No egg name text found at location", i)
						return
					end

					for _, selectedEgg in pairs(selectedEggs) do
						if eggNameText == selectedEgg then
							-- Find the corresponding egg model using the folder instance
							local eggModel = eggLocationsFolder:FindFirstChild(eggNameText)
							if not eggModel then
								warn("[FarmHelper] Could not find egg model for", eggNameText)
								return
							end

							local isVisible = true

							-- Check all parts of the egg model and its children
							local function checkTransparency(obj)
								if obj:IsA("BasePart") and obj.Transparency > 0 then
									isVisible = false
									return
								end
								for _, child in pairs(obj:GetChildren()) do
									checkTransparency(child)
								end
							end

							checkTransparency(eggModel)

							if isVisible then
								ReplicatedStorage:WaitForChild("GameEvents"):WaitForChild("BuyPetEgg"):FireServer(i)
								Rayfield:Notify({
									Title = "Egg in Stock",
									Content = "Bought " .. selectedEgg,
									Time = 0.5,
								})
							end
						end
					end
				end)
				if not success then
					warn("[FarmHelper] Failed to process egg at location", i, "Error:", err)
				end
			end
		end
	end)
end

local function noclip()
	local noclipConnection
	local function noclipLoop()
		if LocalPlayer.Character then
			for _, part in pairs(LocalPlayer.Character:GetDescendants()) do
				if part:IsA("BasePart") and part.CanCollide then
					part.CanCollide = false
				end
			end
		end
	end

	noclipConnection = RunService.Stepped:Connect(noclipLoop)

	return function()
		if noclipConnection then
			noclipConnection:Disconnect()
		end
	end
end

local function init()
	local gearUI =
		LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("Teleport_UI"):WaitForChild("Frame"):WaitForChild("Gear")
	local petsUI =
		LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("Teleport_UI"):WaitForChild("Frame"):WaitForChild("Pets")

	gearUI.Visible = true
	petsUI.Visible = true

	UserInputService.JumpRequest:Connect(function()
		if LocalPlayer and LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
			LocalPlayer.Character:FindFirstChildOfClass("Humanoid"):ChangeState(Enum.HumanoidStateType.Jumping)
		end
	end)

	Window:CreateTab("Discord"):CreateLabel("Join https://discord.gg/wB34Qa4zbr for support!")

	for _, connection in pairs(getconnections(game:GetService("Players").LocalPlayer.Idled)) do
		connection:Disable()
	end

	noclip()
	setupShopChecks()
	Rayfield:LoadConfiguration()
end

init()
