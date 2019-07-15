#
include("objects.jl")
import Base.show

mutable struct Collector
    health
    player  # who owns this unit
    pos::WorldPos
    Collector(player) = new(max_health(Collector), player, WorldPos(0,0))
    Collector(player, pos) = new(max_health(Collector), player, pos)
end
mutable struct Fighter
    health
    player  # who owns this unit
    pos::WorldPos
    attackTargetUnit  # who currently attacking
    Fighter(player) = new(max_health(Fighter), player, WorldPos(0,0), nothing)
    Fighter(player, pos) = new(max_health(Fighter), player, pos, nothing)
end

Base.show(io::IO, u::Collector) = print(io, "Collector($(u.health), $(Ptr{PlayerUnits}(pointer_from_objref(u.player))), $(u.pos)")
health_percent(u) = health(u) / max_health(typeof(u))

health(x::Collector) = x.health
set_health!(x::Collector, h) = (x.health = h)

health(x::Fighter) = x.health
set_health!(x::Fighter, h) = (x.health = h)

# Unit attributes
@noinline max_health(::Type{Collector}) = (global kMaxHealth_Collector; kMaxHealth_Collector)
@noinline max_health(::Type{Fighter}) = (global kMaxHealth_Collector; kMaxHealth_Fighter)

@noinline attack_damage(::Collector) = (global kMaxHealth_Collector; kAttackDamage_Collector)
@noinline attack_damage(::Fighter) = (global kMaxHealth_Collector; kAttackDamage_Fighter)

@noinline build_time(::Type{Collector}) = (global kMaxHealth_Collector; kBuildTime_Collector)
@noinline build_time(::Type{Fighter}) = (global kMaxHealth_Collector; kBuildTime_Fighter)
@noinline build_cost(::Type{Collector}) = (global kMaxHealth_Collector; kBuildCost_Collector)
@noinline build_cost(::Type{Fighter}) = (global kMaxHealth_Collector; kBuildCost_Fighter)

unit_types = (Collector, Fighter)
UnitTypes = Union{unit_types...}

# ---------------------
# PLAYER
# --------------------
mutable struct PlayerUnits
    units::Array
    collectors::Array{Collector}
    fighters::Array{Fighter}
end
PlayerUnits() = PlayerUnits([],[],[])
Base.show(io::IO, pu::PlayerUnits) = print(io,
                     "PlayerUnits(\n"
                    *"            units[$(length(pu.units))]\n"
                    *"            collectors[$(length(pu.collectors))]\n"
                    *"            fighters[$(length(pu.fighters))]\n"
                    *"           )")

function add_unit_helper(p::PlayerUnits, u)
    assert(u.player == p)
    push!(p.units, u)
    return u
end
function add_unit!(p::PlayerUnits, u)
    return add_unit_helper(p,u)
end
function add_unit!(p::PlayerUnits, u::Collector)
    add_unit_helper(p,u)
    push!(p.collectors, u)
    return u
end
function add_unit!(p::PlayerUnits, u::Fighter)
    add_unit_helper(p,u)
    push!(p.fighters, u)
    return u
end
add_collector!(p::PlayerUnits) = add_unit!(p, Collector(p))
add_fighter!(p::PlayerUnits) = add_unit!(p, Fighter(p))

remove_unit!(p, unit) = filter!(u->u≠unit, p.units)
function remove_unit!(p, unit::Collector)
    filter!(u->u≠unit, p.collectors)
    filter!(u->u≠unit, p.units)
end
function remove_unit!(p, unit::Fighter)
    filter!(u->u≠unit, p.fighters)
    filter!(u->u≠unit, p.units)
end

function clear_units!(p)
    empty!(p.units)
    empty!(p.collectors)
    empty!(p.fighters)
end
function clear_collectors!(p)
    filter!(u->!isa(u, Collector), p.units)
    empty!(p.collectors)
end
function clear_fighters!(p)
    filter!(u->!isa(u, Fighter), p.units)
    empty!(p.fighters)
end


owning_player(x)::PlayerUnits = x.player

# --------------

function attack!(target, attacker)
    set_health!(target, health(target) - attack_damage(attacker))
    if (health(target) <= 0)
        destroy_unit!(target)
    end
    return health(target)
end

function destroy_unit!(target)
    remove_unit!(owning_player(target), target)
end


# Tests
using Base.Test
collectors = PlayerUnits()
add_collector!(collectors)
destroy_unit!(collectors.units[1])
@test 0 == length(collectors.units)
w = add_collector!(collectors)
w = add_collector!(collectors)
@test 2 == length(collectors.units)
attack!(w, Fighter(nothing))
attack!(w, Fighter(nothing))
@test 1 == length(collectors.units)
