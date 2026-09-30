--!strict

--[[
	Session-only server-authoritative coin wallet.
	No persistence. Never trust client-supplied balances.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local WalletService = {}

export type WalletSnapshot = {
	coins: number,
}

export type TransactionLogEntry = {
	userId: number,
	delta: number,
	balanceBefore: number,
	balanceAfter: number,
	reason: string,
	sequenceId: number,
	timestamp: number,
}

local STARTING_COINS = 500
local balances: { [Player]: number } = {}
local transactionLog: { TransactionLogEntry } = {}
local nextSequenceId = 0
local updatedBindable = Instance.new("BindableEvent")

WalletService.Updated = updatedBindable.Event
WalletService.STARTING_COINS = STARTING_COINS

local function isFiniteNumber(value: number): boolean
	return typeof(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function isPositiveInteger(value: number): boolean
	return isFiniteNumber(value) and value > 0 and value == math.floor(value)
end

local function ensureInitialized(player: Player): number
	local balance = balances[player]
	if balance == nil then
		balances[player] = STARTING_COINS
		balance = STARTING_COINS
		updatedBindable:Fire(player, WalletService.getSnapshot(player))
	end
	return balance
end

local function appendLog(
	player: Player,
	delta: number,
	balanceBefore: number,
	balanceAfter: number,
	reason: string
)
	nextSequenceId += 1
	local entry: TransactionLogEntry = {
		userId = player.UserId,
		delta = delta,
		balanceBefore = balanceBefore,
		balanceAfter = balanceAfter,
		reason = reason,
		sequenceId = nextSequenceId,
		timestamp = os.clock(),
	}
	table.insert(transactionLog, entry)
	if RunService:IsStudio() then
		-- Development-only; avoid production Output spam.
		print(string.format(
			"[WalletService] userId=%d delta=%d before=%d after=%d reason=%s seq=%d",
			entry.userId,
			entry.delta,
			entry.balanceBefore,
			entry.balanceAfter,
			entry.reason,
			entry.sequenceId
		))
	end
end

function WalletService.initializePlayer(player: Player)
	ensureInitialized(player)
end

function WalletService.getBalance(player: Player): number
	return ensureInitialized(player)
end

function WalletService.getSnapshot(player: Player): WalletSnapshot
	return {
		coins = ensureInitialized(player),
	}
end

function WalletService.canAfford(player: Player, amount: number): boolean
	if not isPositiveInteger(amount) then
		return false
	end
	return ensureInitialized(player) >= amount
end

function WalletService.addCoins(player: Player, amount: number, reason: string): (boolean, string?)
	if not isPositiveInteger(amount) then
		return false, "InvalidAmount"
	end
	if typeof(reason) ~= "string" or reason == "" then
		return false, "InvalidReason"
	end

	local before = ensureInitialized(player)
	local after = before + amount
	balances[player] = after
	appendLog(player, amount, before, after, reason)
	updatedBindable:Fire(player, WalletService.getSnapshot(player))
	return true, nil
end

function WalletService.removeCoins(player: Player, amount: number, reason: string): (boolean, string?)
	if not isPositiveInteger(amount) then
		return false, "InvalidAmount"
	end
	if typeof(reason) ~= "string" or reason == "" then
		return false, "InvalidReason"
	end

	local before = ensureInitialized(player)
	if before < amount then
		return false, "InsufficientFunds"
	end

	local after = before - amount
	balances[player] = after
	appendLog(player, -amount, before, after, reason)
	updatedBindable:Fire(player, WalletService.getSnapshot(player))
	return true, nil
end

function WalletService.trySpend(player: Player, amount: number, reason: string): (boolean, string?)
	return WalletService.removeCoins(player, amount, reason)
end

function WalletService.getTransactionLog(): { TransactionLogEntry }
	local copy: { TransactionLogEntry } = {}
	for _, entry in transactionLog do
		table.insert(copy, entry)
	end
	return copy
end

function WalletService.clearForTests(player: Player)
	balances[player] = nil
	transactionLog = {}
	nextSequenceId = 0
end

function WalletService.setBalanceForTests(player: Player, amount: number)
	assert(isFiniteNumber(amount) and amount >= 0 and amount == math.floor(amount))
	balances[player] = amount
	updatedBindable:Fire(player, WalletService.getSnapshot(player))
end

Players.PlayerAdded:Connect(function(player)
	WalletService.initializePlayer(player)
end)

Players.PlayerRemoving:Connect(function(player)
	balances[player] = nil
end)

for _, player in Players:GetPlayers() do
	WalletService.initializePlayer(player)
end

return WalletService
