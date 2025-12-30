local function OverrideTraitCosts()
    local traits = TraitFactory.getTraits()

    for i = 0, traits:size() - 1 do
        local trait = traits:get(i)
        local cost = trait:getCost()

        -- POSITIVE TRAIT
        if cost > 0 then
            trait:setCost(1)
        end
        
    end
end

Events.OnGameBoot.Add(OverrideTraitCosts)
