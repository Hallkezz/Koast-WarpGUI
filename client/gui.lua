class 'WarpGui'

function WarpGui:__init()
	self.cooldown = 35
	timer = Timer()
	self.cooltime = 0

	self.textColor = Color( 200, 50, 200 )
	self.admins = {}
	self.rows = {}
	self.acceptButtons = {}
	self.whitelistButtons = {}
	self.whitelist = {}
	self.whitelistAll = false
	self.warpRequests = {}
	self.windowShown = false
	self.warping = true

	self:AddAdmin( "STEAM_0:0:90087002" )
	self:AddAdmin( "STEAM_0:0:143077310" )
	self:AddAdmin( "STEAM_0:0:68751787" )
	self:AddAdmin( "STEAM_0:0:155680548" )
	self:AddAdmin( "STEAM_0:0:193332380" )
	self:AddAdmin( "STEAM_0:0:175550508" )
	self:AddAdmin( "STEAM_0:1:197930152" )
	self:AddAdmin( "STEAM_0:1:117809432" )
	self:AddAdmin( "STEAM_0:1:229056007" )

	self.window = Window.Create()
	self.window:SetVisible( self.windowShown )
	self.window:SetTitle( "Teleport to players" )
	self.window:SetSizeRel( Vector2(0.35, 0.7) )
	self.window:SetMinimumSize( Vector2(400, 200) )
	self.window:SetPositionRel( Vector2(0.75, 0.5) - self.window:GetSizeRel()/2 )
    self.window:Subscribe( "WindowClosed", self, function (args) self:SetWindowVisible( false ) end )

	self.playerList = SortedList.Create( self.window )
	self.playerList:SetMargin( Vector2( 0, 0 ), Vector2( 0, 4 ) )
	self.playerList:SetBackgroundVisible( false )
	self.playerList:AddColumn( "Name" )
	self.playerList:AddColumn( "Teleport to", 90 )
	self.playerList:AddColumn( "Requests", 90 )
	self.playerList:AddColumn( "Auto-TP", 90 )
	self.playerList:SetButtonsVisible( true )
	self.playerList:SetDock( GwenPosition.Fill )

	self.filter = TextBox.Create( self.window )
	self.filter:SetDock( GwenPosition.Bottom )
	self.filter:SetSize( Vector2( self.window:GetSize().x, 32 ) )
	self.filter:SetToolTip( "Search" )
	self.filter:Subscribe( "TextChanged", self, self.TextChanged )

	local whitelistAllCheckbox = LabeledCheckBox.Create( self.window )
    whitelistAllCheckbox:SetSize( Vector2( 300, 20 ) )
    whitelistAllCheckbox:SetDock( GwenPosition.Top )
    whitelistAllCheckbox:GetLabel():SetText( "Allow Auto-TP to all" )
	whitelistAllCheckbox:GetLabel():SetTextSize( 15 )
    whitelistAllCheckbox:GetCheckBox():Subscribe( "CheckChanged",
		function() self.whitelistAll = whitelistAllCheckbox:GetCheckBox():GetChecked() end )

	local whitelistAllCheckbox = LabeledCheckBox.Create( self.window )
    whitelistAllCheckbox:SetSize( Vector2( 300, 20 ) )
    whitelistAllCheckbox:SetDock( GwenPosition.Top )
    whitelistAllCheckbox:GetLabel():SetText( "Do not disturb" )
	whitelistAllCheckbox:GetLabel():SetTextSize( 15 )
    whitelistAllCheckbox:GetCheckBox():Subscribe( "CheckChanged",
		function() self.warping = not self.warping end )	

	-- Add players
	for player in Client:GetPlayers() do
		self:AddPlayer(player)
	end
	--self:AddPlayer(LocalPlayer)

	Events:Subscribe( "LocalPlayerChat", self, self.LocalPlayerChat )
    Events:Subscribe( "LocalPlayerInput", self, self.LocalPlayerInput )
	Events:Subscribe( "PlayerJoin", self, self.PlayerJoin )
	Events:Subscribe( "PlayerQuit", self, self.PlayerQuit )
    Events:Subscribe( "KeyUp", self, self.KeyUp )
	Events:Subscribe( "KeyDown", self, self.KeyDown )
	Events:Subscribe( "Render", self, self.Render )
	Events:Subscribe( "Render", self, self.RenderText )
	Network:Subscribe( "WarpRequestToTarget", self, self.WarpRequest )
	Network:Subscribe( "WarpReturnWhitelists", self, self.WarpReturnWhitelists )
	Network:Subscribe( "WarpDoPoof", self, self.WarpDoPoof )

	-- Load whitelists from server
	Network:Send( "WarpGetWhitelists", LocalPlayer )

	--self:AddPlayer(LocalPlayer)
end

function WarpGui:RenderText()
	if Game:GetState() ~= GUIState.Game then return end	
	if timerF and textF then
		alpha = 4

	if timerF:GetSeconds() > 3 and timerF:GetSeconds() < 4 then
		alpha = 3 - (timerF:GetSeconds() - 1)
	elseif timerF:GetSeconds() >= 4 then
		timerF = nil
		textF = nil
		return
	end

	text_width = Render:GetTextWidth( textF,28 )
	pos_0 = Vector2(
	(Render.Width - text_width)/1.8,
	(Render.Height)/2.5 )
	col = Copy( ErColor )
	col.a = col.a * alpha

	colS = Copy( Color( 0, 0, 0, 80 ) )
	colS.a = colS.a * alpha	

	Render:SetFont( AssetLocation.SystemFont, "Impact" )
	Render:DrawText( pos_0 + Vector2.One, textF, colS, 28 )
	Render:DrawText( pos_0, textF, col, 28 )
	end
end

function WarpGui:AddAdmin( steamId )
	self.admins[steamId] = true
end

function WarpGui:IsAdmin( player )
	return self.admins[player:GetSteamId().string] ~= nil
end

--  Player adding
function WarpGui:CreateListButton( text, enabled, listItem )
    local buttonBackground = Rectangle.Create( listItem )
    buttonBackground:SetSizeRel( Vector2( 0.5, 1.0 ) )
    buttonBackground:SetDock( GwenPosition.Fill )
    buttonBackground:SetColor( Color( 0, 0, 0, 100 ) )

	local button = Button.Create( listItem )
	button:SetText( text )
	button:SetTextSize( 13 )
	button:SetDock( GwenPosition.Fill )
	button:SetEnabled( enabled )

	return button
end

function WarpGui:AddPlayer( player )
	local playerId = tostring(player:GetSteamId().id)
	local playerName = player:GetName()
	local playerColor = player:GetColor()

	local item = self.playerList:AddItem(playerId)

	if LocalPlayer:IsFriend( player ) then
		item:SetToolTip( "Friend" )
	end	

	local warpToButton = self:CreateListButton( "Teleport", true, item )
	warpToButton:Subscribe( "Press", function() self:WarpToPlayerClick(player) end )

	local acceptButton = self:CreateListButton( "Accept", false, item )
	acceptButton:Subscribe( "Press", function() self:AcceptWarpClick(player) end )
	self.acceptButtons[playerId] = acceptButton

	local whitelist = self.whitelist[playerId]
	local whitelistButtonText = "-"
	if whitelist ~= nil then
		if whitelist == 1 then whitelistButtonText = "On"
		elseif whitelist == 2 then whitelistButtonText = "Blocked"
		end
	end
	local whitelistButton = self:CreateListButton( whitelistButtonText, true, item )
	whitelistButton:Subscribe( "Press", function() self:WhitelistClick(playerId, whitelistButton) end )
	self.whitelistButtons[playerId] = whitelistButton

	item:SetCellText( 0, playerName )
	item:SetCellContents( 1, warpToButton )
	item:SetCellContents( 2, acceptButton )
	item:SetCellContents( 3, whitelistButton )
	item:SetTextColor( playerColor )

	self.rows[playerId] = item

	-- Add is serch filter matches
	local filter = self.filter:GetText():lower()
	if filter:len() > 0 then
		item:SetVisible( true )
	end
end

--  Player search
function WarpGui:TextChanged()
	local filter = self.filter:GetText()

	if filter:len() > 0 then
		for k, v in pairs(self.rows) do
			v:SetVisible( self:PlayerNameContains(v:GetCellText(0), filter) )
		end
	else
		for k, v in pairs(self.rows) do
			v:SetVisible( true )
		end
	end
end

function WarpGui:PlayerNameContains( name, filter )
	return string.match(name:lower(), filter:lower()) ~= nil
end

function WarpGui:WarpToPlayerClick( player )
	local time = Client:GetElapsedSeconds()
	if time < self.cooltime then
		self:SetWindowVisible( false )
		timerF = Timer()
		textF = "Wait " .. math.ceil(self.cooltime - time) .. " seconds to resend the request!"
		ErColor = Color.Red
		return
	end
	Network:Send( "WarpRequestToServer", {requester = LocalPlayer, target = player} )
	timer:Restart()
	self:SetWindowVisible( false )

	self.cooltime = time + self.cooldown
	return false		
end

function WarpGui:AcceptWarpClick( player )
	local playerId = tostring(player:GetSteamId().id)

	if self.warpRequests[playerId] == nil then
		Chat:Print( player:GetName() .. " did not ask you to teleport.", self.textColor )
		return
	else
		local acceptButton = self.acceptButtons[playerId]
		if acceptButton == nil then return end
		self.warpRequests[playerId] = nil
		acceptButton:SetEnabled( false )
		
		Network:Send( "WarpTo", {requester = player, target = LocalPlayer} )
		self:SetWindowVisible( false )
	end
end

--  Warp request
function WarpGui:WarpRequest( args )
	if self.warping then
		local requestingPlayer = args
		local playerId = tostring(requestingPlayer:GetSteamId().id)
		local whitelist = self.whitelist[playerId]

		if whitelist == 1 or self.whitelistAll or self:IsAdmin(requestingPlayer) then -- In whitelist and not in blacklist, OR admin
			Network:Send( "WarpTo", {requester = requestingPlayer, target = LocalPlayer} )
		elseif whitelist == 0 or whitelist == nil then -- Not in whitelist
			local acceptButton = self.acceptButtons[playerId]
			if acceptButton == nil then return end

			acceptButton:SetEnabled( true )
			self.warpRequests[playerId] = true
			Network:Send( "WarpMessageTo", {target = requestingPlayer, message = "The request for teleportation has been sent to " .. LocalPlayer:GetName() .. ". Wait for the request to be accepted."} )
			Chat:Print( requestingPlayer:GetName() .. " would like to teleport to you. Type /warp or press V to accept.", self.textColor )
		end
	end 	-- Blacklist
end

--  White/black -list click
function WarpGui:WhitelistClick( playerId, button )
	local currentWhiteList = self.whitelist[playerId]

	if currentWhiteList == 0 or currentWhiteList == nil then -- Currently none, set whitelisted
		self:SetWhitelist( playerId, 1, true )
	elseif currentWhiteList == 1 then -- Currently whitelisted, blacklisted
		self:SetWhitelist( playerId, 2, true )
	elseif currentWhiteList == 2 then -- Currently blacklisted, set none
		self:SetWhitelist( playerId, 0, true )
	end
end

function WarpGui:SetWhitelist( playerId, whitelisted, sendToServer )
	if self.whitelist[playerId] ~= whitelisted then self.whitelist[playerId] = whitelisted end

	local whitelistButton = self.whitelistButtons[playerId]
	if whitelistButton == nil then return end

	if whitelisted == 0 then
		whitelistButton:SetText( "-" )
		whitelistButton:SetTextSize( 13 )
	elseif whitelisted == 1 then
		whitelistButton:SetText( "On" )
		whitelistButton:SetTextSize( 13 )
	elseif whitelisted == 2 then
		whitelistButton:SetText( "Blocked" )
		whitelistButton:SetTextSize( 13 )
	end

	if sendToServer then
		Network:Send( "WarpSetWhitelist", {playerSteamId = LocalPlayer:GetSteamId().id, targetSteamId = playerId, whitelist = whitelisted} )
	end
end

function WarpGui:WarpReturnWhitelists( whitelists )
	for i = 1, #whitelists do
		local targetSteamId = whitelists[i].target_steam_id
		local whitelisted = whitelists[i].whitelist
		self:SetWhitelist( targetSteamId, tonumber(whitelisted), false )
	end
end

--  Chat command
function WarpGui:LocalPlayerChat( args )
	local message = args.text

	local commands = {}
	for command in string.gmatch(message, "[^%s]+") do
		table.insert(commands, command)
	end

	if commands[1] ~= "/warp" then return true end

	if #commands == 1 then -- No extra commands, show window and return
		self:SetWindowVisible( not self.windowShown )
		return false
	end

	local warpNameSearch = table.concat(commands, " ", 2)

	for player in Client:GetPlayers() do
		if (self:PlayerNameContains( player:GetName(), warpNameSearch) ) then
			self:WarpToPlayerClick( player )
			return false
		end
	end

	return false
end

--  Effect
function WarpGui:WarpDoPoof( position )
    ClientEffect.Play( AssetLocation.Game, {effect_id = 250, position = position, angle = Angle()} )
end

--  Window management
function WarpGui:LocalPlayerInput( args ) -- Prevent mouse from moving & buttons being pressed
    return not (self.windowShown and Game:GetState() == GUIState.Game)
end

function WarpGui:KeyUp( args )
	if Game:GetState() ~= GUIState.Game then return end
    if args.key == string.byte('V') then
        self:SetWindowVisible( not self.windowShown )
		local sound = ClientSound.Create(AssetLocation.Game, {
				bank_id = 20,
				sound_id = 18,
				position = LocalPlayer:GetPosition(),
				angle = Angle()
		})

		sound:SetParameter(0,0.75)
    end
end

function WarpGui:KeyDown( args )
	if args.key == VirtualKey.Escape then
		self:SetWindowVisible( false )
	end
end

function WarpGui:PlayerJoin( args )
	local player = args.player

	self:AddPlayer(player)
end

function WarpGui:PlayerQuit( args )
	local player = args.player
	local playerId = tostring(player:GetSteamId().id)

	if self.rows[playerId] == nil then return end

	self.playerList:RemoveItem(self.rows[playerId])
	self.rows[playerId] = nil
end

function WarpGui:Render()
	local is_visible = self.windowShown and (Game:GetState() == GUIState.Game)

	if self.window:GetVisible() ~= is_visible then
		self.window:SetVisible( is_visible )
	end

	if self.active then
		Mouse:SetVisible( true )
	end
end

function WarpGui:SetWindowVisible( visible )
    if self.windowShown ~= visible then
        if visible == true and LocalPlayer:GetWorld() ~= DefaultWorld then
            Chat:Print( "You can not open it here!", Color( 255, 0, 0 ) )
            return
        end

		self.windowShown = visible
		self.window:SetVisible( visible )
		Mouse:SetVisible( visible )
	end
end

warpGui = WarpGui()