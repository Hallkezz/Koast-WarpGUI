------------------------
--Modified by Hallkezz--
------------------------
--Original module: www.jc-mp.com/forums/index.php/topic,3841.0.html
------------------------

-----------------------------------------------------------------------------------
--Settings
local debug = false -- ON/OFF Debug mode. (Use: true / false)
---------------------
local key = 'V' -- Activation button.
local command = "/tpm" -- Activation command.
local world = true -- Blocking in other worlds. (Use: true / false)
---------------------
local cooldown = 15 -- Cooldown time.
local textColor = Color(200, 150, 100) -- Text Color.
---------------------
local content = "Teleportation to players" -- Title text.
local visible = false -- Background Visible. (Use: true / false)
local tpall = true -- Visible 'Auto-TP' button. (Use: true / false)
local notdis = true -- Visible 'Do not disturb' button. (Use: true / false)
-----------------------------------------------------------------------------------

-----------------------------------------------------------------------------------
--Script
class 'WarpGui'

function WarpGui:__init()
	timer = Timer()
	self.cooltime = 0

	-- Variables
	self.admins = {}
	self.rows = {}
	self.acceptButtons = {}
	self.whitelistButtons = {}
	self.whitelist = {}
	self.whitelistAll = false
	self.warpRequests = {}
	self.windowShown = false
	self.warping = true

	-- Admins
	self:AddAdmin("STEAM_0:0:90087002")
	self:AddAdmin("STEAM_0:0:16870054")

	-- Create GUI
	self.window = Window.Create()
	self.window:SetVisible( self.windowShown )
	self.window:SetTitle( content )
	self.window:SetSizeRel( Vector2( 0.35, 0.7 ) )
	self.window:SetMinimumSize( Vector2( 400, 200 ) )
	self.window:SetPositionRel( Vector2( 0.75, 0.5 ) - self.window:GetSizeRel()/2 )
    self.window:Subscribe( "WindowClosed", self, function (args) self:SetWindowVisible( false ) end )

	-- Player list
	self.playerList = SortedList.Create( self.window )
	self.playerList:SetMargin( Vector2( 0, 0 ), Vector2( 0, 4 ) )
	self.playerList:SetBackgroundVisible( visible )
	self.playerList:AddColumn( "Name" )
	self.playerList:AddColumn( "Teleport to", 90 )
	self.playerList:AddColumn( "Accept TP", 90 )
	self.playerList:AddColumn( "Auto-TP", 90 )
	self.playerList:SetButtonsVisible( true )
	self.playerList:SetDock( GwenPosition.Fill )

	-- Player search box
	self.filter = TextBox.Create( self.window )
	self.filter:SetDock( GwenPosition.Bottom )
	self.filter:SetSize( Vector2( self.window:GetSize().x, 32 ) )
	self.filter:SetToolTip( "Search" )
	self.filter:Subscribe( "TextChanged", self, self.TextChanged )

	if tpall then
		-- Auto-TP all
		local whitelistAllCheckbox = LabeledCheckBox.Create( self.window )
		whitelistAllCheckbox:SetSize( Vector2( 300, 20 ) )
		whitelistAllCheckbox:SetDock( GwenPosition.Top )
		whitelistAllCheckbox:GetLabel():SetText( "Allow Auto-TP for All" )
		whitelistAllCheckbox:GetLabel():SetTextSize( 15 )
		whitelistAllCheckbox:GetCheckBox():Subscribe( "CheckChanged",
			function() self.whitelistAll = whitelistAllCheckbox:GetCheckBox():GetChecked() end )
	end

	if notdis then
		-- Do not disturb
		local whitelistAllCheckbox = LabeledCheckBox.Create( self.window )
		whitelistAllCheckbox:SetSize( Vector2( 300, 20 ) )
		whitelistAllCheckbox:SetDock( GwenPosition.Top )
		whitelistAllCheckbox:GetLabel():SetText( "Do not disturb" )
		whitelistAllCheckbox:GetLabel():SetTextSize( 15 )
		whitelistAllCheckbox:GetCheckBox():Subscribe( "CheckChanged",
			function() self.warping = not self.warping end )
	end

	-- Add players
	for player in Client:GetPlayers() do
		self:AddPlayer(player)
	end
	--self:AddPlayer(LocalPlayer)

	-- Subscribe to events
	Events:Subscribe( "LocalPlayerChat", self, self.LocalPlayerChat )
    Events:Subscribe( "LocalPlayerInput", self, self.LocalPlayerInput )
	Events:Subscribe( "PlayerJoin", self, self.PlayerJoin )
	Events:Subscribe( "PlayerQuit", self, self.PlayerQuit )
    Events:Subscribe( "KeyUp", self, self.KeyUp )
	Events:Subscribe( "Render", self, self.Render )
	Events:Subscribe( "ModulesLoad", ModulesLoad )
    Events:Subscribe( "ModuleUnload", ModuleUnload )
	Network:Subscribe( "WarpRequestToTarget", self, self.WarpRequest )
	Network:Subscribe( "WarpReturnWhitelists", self, self.WarpReturnWhitelists )
	Network:Subscribe( "WarpDoPoof", self, self.WarpDoPoof )

	-- Load whitelists from server
	Network:Send( "WarpGetWhitelists", LocalPlayer )

	if debug then
		print( "Koast-WarpGUI loaded." )
		self:AddPlayer(LocalPlayer)
	end
end

-----------------------------------------------------------------------------------
--Admin check
function WarpGui:AddAdmin( steamId )
	self.admins[steamId] = true
end

function WarpGui:IsAdmin( player )
	return self.admins[player:GetSteamId().string] ~= nil
end

-----------------------------------------------------------------------------------
--Player adding
function WarpGui:CreateListButton( text, enabled, listItem  )
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
	local playerId = tostring( player:GetSteamId().id )
	local playerName = player:GetName()
	local playerColor = player:GetColor()

	local item = self.playerList:AddItem( playerId )

	if LocalPlayer:IsFriend( player ) then
		item:SetTextColor( Color( 150, 160, 255 ) )
		item:SetToolTip( "Friend" )
	end

	-- Warp to button
	local warpToButton = self:CreateListButton( "Teleport", true, item )
	warpToButton:Subscribe( "Press", function() self:WarpToPlayerClick(player) end )

	-- Accept
	local acceptButton = self:CreateListButton( "Accept", false, item )
	acceptButton:Subscribe( "Press", function() self:AcceptWarpClick(player) end )
	self.acceptButtons[playerId] = acceptButton

	-- Whitelist
	local whitelist = self.whitelist[playerId]
	local whitelistButtonText = "-"
	if whitelist ~= nil then
	if whitelist == 1 then whitelistButtonText = "On"
		elseif whitelist == 2 then whitelistButtonText = "Blocked"
		end
	end
	local whitelistButton = self:CreateListButton( whitelistButtonText, true, item )
	whitelistButton:Subscribe( "Press", function() self:WhitelistClick( playerId, whitelistButton ) end )
	self.whitelistButtons[playerId] = whitelistButton

	-- List item
	item:SetCellText( 0, playerName )
	item:SetCellContents( 1, warpToButton )
	item:SetCellContents( 2, acceptButton )
	item:SetCellContents( 3, whitelistButton )
	--item:SetTextColor( playerColor )

	self.rows[playerId] = item

	-- Add is serch filter matches
	local filter = self.filter:GetText():lower()
	if filter:len() > 0 then
		item:SetVisible( true )
	end
end

-----------------------------------------------------------------------------------
--Player search
function WarpGui:TextChanged()
	local filter = self.filter:GetText()

	if filter:len() > 0 then
		for k, v in pairs(self.rows) do
			v:SetVisible( self:PlayerNameContains( v:GetCellText(0), filter ) )
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

-----------------------------------------------------------------------------------
--Teleport/Accept
function WarpGui:WarpToPlayerClick( player )
	local time = Client:GetElapsedSeconds()
	self:SetWindowVisible( false )

	if time < self.cooltime then
		Chat:Print( "Please wait " .. math.ceil(self.cooltime - time) .. " seconds to resend the request!", Color( 255, 34, 34 ) )
		return
	end

	Network:Send( "WarpRequestToServer", {requester = LocalPlayer, target = player} )
	timer:Restart()

	self.cooltime = time + cooldown
	return false
end

function WarpGui:AcceptWarpClick( player )
	local playerId = tostring( player:GetSteamId().id )

	if self.warpRequests[playerId] == nil then
		Chat:Print( player:GetName() .. " has not requested to warp to you.", textColor )
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

-----------------------------------------------------------------------------------
--Warp request
function WarpGui:WarpRequest( args )
	local requestingPlayer = args
	local playerId = tostring( requestingPlayer:GetSteamId().id )
	local whitelist = self.whitelist[playerId]

	if whitelist == 1 or self.whitelistAll or self:IsAdmin(requestingPlayer) then -- In whitelist and not in blacklist, OR admin
		Network:Send( "WarpTo", {requester = requestingPlayer, target = LocalPlayer} )
	elseif whitelist == 0 or whitelist == nil then -- Not in whitelist
		local acceptButton = self.acceptButtons[playerId]
		if acceptButton == nil then return end

		if self.warping then
		acceptButton:SetEnabled( true )
		self.warpRequests[playerId] = true
		Network:Send( "WarpMessageTo", {target = requestingPlayer, message = "Please wait for " .. LocalPlayer:GetName() .. " to accept."} )
		Chat:Print( requestingPlayer:GetName() .. " sent you a teleport request. Type " .. command .. " or press " .. key .. " to accept.", textColor )
		end
	end 	-- Blacklist
end

-----------------------------------------------------------------------------------
--On/Off and Blocked -list click
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

	if whitelisted == 0 then -- none
		whitelistButton:SetText( "-" )
		whitelistButton:SetTextSize( 13 )
	elseif whitelisted == 1 then -- whitelist
		whitelistButton:SetText( "On" )
		whitelistButton:SetTextSize( 13 )
	elseif whitelisted == 2 then -- blacklist
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

-----------------------------------------------------------------------------------
--Chat command
function WarpGui:LocalPlayerChat( args )
	local message = args.text

	local commands = {}
	for command in string.gmatch(message, "[^%s]+") do
		table.insert(commands, command)
	end

	if commands[1] ~= command then return true end

	if #commands == 1 then -- No extra commands, show window and return
		self:SetWindowVisible( not self.windowShown )
		return false
	end

	local warpNameSearch = table.concat(commands, " ", 2)

	for player in Client:GetPlayers() do
		if ( self:PlayerNameContains( player:GetName(), warpNameSearch ) ) then
			self:WarpToPlayerClick( player )
			return false
		end
	end

	return false
end

-----------------------------------------------------------------------------------
--Effect
function WarpGui:WarpDoPoof( position )
    ClientEffect.Play( AssetLocation.Game, {effect_id = 250, position = position, angle = Angle()} )
end

-----------------------------------------------------------------------------------
--Window management
function WarpGui:LocalPlayerInput( args ) -- Prevent mouse from moving & buttons being pressed
    return not ( self.windowShown and Game:GetState() == GUIState.Game )
end

function WarpGui:KeyUp( args )
	if Game:GetState() ~= GUIState.Game then return end
    if args.key == string.byte(key) then
        self:SetWindowVisible( not self.windowShown )
    end
end

function WarpGui:PlayerJoin( args )
	local player = args.player

	self:AddPlayer( player )
end

function WarpGui:PlayerQuit( args )
	local player = args.player
	local playerId = tostring( player:GetSteamId().id )

	if self.rows[playerId] == nil then return end

	self.playerList:RemoveItem( self.rows[playerId] )
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

--Help
function ModulesLoad()
	Events:Fire( "HelpAddItem",
        {
            name = "Teleportation to players",
            text = 
                "Press '" .. key .. "' to open the teleportation to players.\n\n" ..
                "Click the Teleport button to send a request for teleportation.\n" ..
				"To accept the request, use the 'Accept' button.\n\n" ..
				"You can also block the player or allow him to use the Auto-TP to you. (Initially neutral)\n" ..
				"\n::Modified by Hallkezz!"
        } )
end

function ModuleUnload()
    Events:Fire( "HelpRemoveItem",
        {
            name = "Teleportation to players"
        } )
end

-----------------------------------------------------------------------------------
--Check world

function WarpGui:SetWindowVisible( visible )
    if self.windowShown ~= visible then
		if world then
			if visible == true and LocalPlayer:GetWorld() ~= DefaultWorld then
				Chat:Print( "You can not open it here!", Color( 255, 0, 0 ) )
				return
			end
		end

		self.windowShown = visible
		self.window:SetVisible( visible )
		Mouse:SetVisible( visible )
	end
end

warpGui = WarpGui()

--v0.2--
--07.04.18--