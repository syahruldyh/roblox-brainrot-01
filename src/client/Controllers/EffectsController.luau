--!strict
-- SNACK ATTACK: client-side effects only. The server decides every outcome; this
-- controller just makes outcomes feel like something happened: a "+$N" popup when the
-- cash ticks up, a red flash across the screen while the Inspector sweeps, and a
-- quick pop on the cash frame when a purchase lands. Nothing here touches game state.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Net = require(ReplicatedStorage.Shared.Net)

local LocalPlayer = Players.LocalPlayer

local EffectsController = {}

local lastCash = 0
local alarmFrame: Frame?

function EffectsController.start()
	task.spawn(function()
		local playerGui = LocalPlayer:WaitForChild("PlayerGui")
		local hud = playerGui:WaitForChild("SnackHud") :: ScreenGui

		-- Red full-screen flash, shown while the Inspector sweeps.
		alarmFrame = Instance.new("Frame")
		alarmFrame.Name = "InspectorAlarm"
		alarmFrame.Size = UDim2.fromScale(1, 1)
		alarmFrame.BackgroundColor3 = Color3.fromRGB(200, 30, 30)
		alarmFrame.BackgroundTransparency = 1
		alarmFrame.BorderSizePixel = 0
		alarmFrame.Visible = false
		alarmFrame.Parent = hud

		-- "+$N" popup on the cash frame whenever the balance jumps.
		LocalPlayer:GetAttributeChangedSignal("SnackCash"):Connect(function()
			local cash = LocalPlayer:GetAttribute("SnackCash")
			if typeof(cash) ~= "number" then
				return
			end
			local gain = cash - lastCash
			lastCash = cash
			if gain <= 0 or gain > 100000 then
				return -- a purchase or a rebirth reset, not income: no popup
			end
			local popup = Instance.new("TextLabel")
			popup.Name = "CashPopup"
			popup.Size = UDim2.new(0, 120, 0, 28)
			popup.Position = UDim2.new(1, -140, 0, 60)
			popup.AnchorPoint = Vector2.new(1, 0)
			popup.BackgroundTransparency = 1
			popup.Text = `+${gain}`
			popup.TextColor3 = Color3.fromRGB(120, 220, 120)
			popup.Font = Enum.Font.GothamBlack
			popup.TextSize = 20
			popup.Parent = hud
			local tween = TweenService:Create(
				popup,
				TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Position = UDim2.new(1, -140, 0, 10), TextTransparency = 1 }
			)
			tween:Play()
			tween.Completed:Connect(function()
				popup:Destroy()
			end)
		end)

		-- The alarm flashes while the sweep runs, and clears when it ends.
		Net.InspectorChanged.OnClientEvent:Connect(function(phase: string, _secondsLeft: number)
			if not alarmFrame then
				return
			end
			if phase == "sweep" then
				alarmFrame.Visible = true
				TweenService:Create(alarmFrame, TweenInfo.new(0.6), { BackgroundTransparency = 0.85 }):Play()
			else
				TweenService:Create(alarmFrame, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
			end
		end)
	end)
end

return EffectsController
