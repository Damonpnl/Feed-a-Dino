local Format=require(game.ReplicatedStorage.Shared.NumberFormat)
return function(t)
	-- Requirements use actual authoritative numbers, not client values or rarity guesses.
	t.test("compact Power requirement",function()
		t.expect.equal(Format.needPower(25000),"NEED 25K POWER")
		t.expect.equal(Format.needPower(6000000),"NEED 6M POWER")
		t.expect.equal(Format.needPower(1500),"NEED 1.5K POWER")
		t.expect.equal(Format.needPower(0),"NEED 0 POWER")
	end)
end
