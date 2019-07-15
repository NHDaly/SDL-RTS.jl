

struct FoodSheetCoords end
struct FoodPos <: AbstractPos{FoodSheetCoords}  # 0,0 == middle
    x::Float64
    y::Float64
end

struct FoodParticle
    amountFood
    size::WorldDims
    pos::FoodPos
end


# The food is distributed on a "sheet" that "floats" around the world, causing
# it to strike the collectors.
worldFoodSheetOffset = Vector2D(0,0)

toWorldPos(p::FoodPos) = WorldPos((p + worldFoodSheetOffset)...)
toFoodPos(p::WorldPos) = FoodPos((p - worldFoodSheetOffset)...)


# Have to keep track of the foods that have been eaten so they can disappear.
eatenFoodPositions = []
# returns a list of all FoodParticles within a given dimension bounds.
function foodDistribution(center, dimBounds)::Array{FoodParticle}
    outArr = []

    worldCenter = toFoodPos(toWorldPos(center, cam))
    worldBounds = toWorldDims(dimBounds, cam)
    tl = worldCenter - Vector2D(worldBounds...) * .5
    br = worldCenter + Vector2D(worldBounds...) * .5
    for x in round(tl.x) : 1 : round(br.x)
        for y in round(tl.y) : 1 : round(br.y)
            p = FoodPos(x,y)
            if foodDistributionFunction(p) && !in(p, eatenFoodPositions)
                push!(outArr,FoodParticle(kFoodAmount, WorldDims(kFoodSize,kFoodSize), p))
            end
        end
    end
    outArr
end
foodDistributionFunction(p::FoodPos) = (round(p.x) % kFoodDistributionFreq) == 0 && (round(p.y) % kFoodDistributionFreq) == 0

destroyFoodParticle(fp::FoodParticle) = push!(eatenFoodPositions, fp.pos)

function renderFoodParticles(cam,renderer, curFoodParticles)
    for fp in curFoodParticles
        renderRectCentered(cam,renderer, toWorldPos(fp.pos), fp.size, kFoodColor)
    end
end


function overlapping(a_center::AbstractPos{C}, ad::AbstractDims{D},
                     b_center::AbstractPos{C}, bd::AbstractDims{D})::Bool where {C} where {D}
    a = a_center - Vector2D(ad...) * .5
    b = b_center - Vector2D(bd...) * .5

    if (a.x < b.x + bd.w &&
        a.x + ad.w > b.x &&
        a.y < b.y + bd.h &&
        ad.h + a.y > b.y)
        true
   else
       false
   end
end
