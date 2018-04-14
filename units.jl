#
include("objects.jl")
import Base.show

mutable struct Worker
    health
    player  # who owns this unit
    pos::WorldPos
    Worker(player) = new(max_health(Worker), player, WorldPos(0,0))
    Worker(player, pos) = new(max_health(Worker), player, pos)
end
mutable struct Fighter
    health
    player  # who owns this unit
    pos::WorldPos
    Fighter(player) = new(max_health(Fighter), player, WorldPos(0,0))
    Fighter(player, pos) = new(max_health(Fighter), player, pos)
end

Base.show(io::IO, u::Worker) = print(io, "Worker($(u.health), $(Ptr{PlayerUnits}(pointer_from_objref(u.player))), $(u.pos)")
health_percent(u) = health(u) / max_health(typeof(u))

health(x::Worker) = x.health
set_health!(x::Worker, h) = (x.health = h)

health(x::Fighter) = x.health
set_health!(x::Fighter, h) = (x.health = h)

# Unit attributes
@noinline max_health(::Type{Worker}) = (global kMaxHealth_Worker; kMaxHealth_Worker)
@noinline max_health(::Type{Fighter}) = (global kMaxHealth_Worker; kMaxHealth_Fighter)

@noinline attack_damage(::Worker) = (global kMaxHealth_Worker; kAttackDamage_Worker)
@noinline attack_damage(::Fighter) = (global kMaxHealth_Worker; kAttackDamage_Fighter)

@noinline build_time(::Type{Worker}) = (global kMaxHealth_Worker; kBuildTime_Worker)
@noinline build_time(::Type{Fighter}) = (global kMaxHealth_Worker; kBuildTime_Fighter)
@noinline build_cost(::Type{Worker}) = (global kMaxHealth_Worker; kBuildCost_Worker)
@noinline build_cost(::Type{Fighter}) = (global kMaxHealth_Worker; kBuildCost_Fighter)

@noinline money_persec_perworker() = kMoneyPersecPerworker # 1 every n secs

unit_types = (Worker, Fighter)
UnitTypes = Union{unit_types...}

# ---------------------
# PLAYER
# --------------------
mutable struct PlayerUnits
    units::Array
    workers::Array{Worker}
    fighters::Array{Fighter}
end
PlayerUnits() = PlayerUnits([],[],[])
Base.show(io::IO, pu::PlayerUnits) = print(io,
                     "PlayerUnits(\n"
                    *"            units[$(length(pu.units))]\n"
                    *"            workers[$(length(pu.workers))]\n"
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
function add_unit!(p::PlayerUnits, u::Worker)
    add_unit_helper(p,u)
    push!(p.workers, u)
    return u
end
function add_unit!(p::PlayerUnits, u::Fighter)
    add_unit_helper(p,u)
    push!(p.fighters, u)
    return u
end
add_worker!(p::PlayerUnits) = add_unit!(p, Worker(p))
add_fighter!(p::PlayerUnits) = add_unit!(p, Fighter(p))

remove_unit!(p, unit) = filter!(u->u≠unit, p.units)
function remove_unit!(p, unit::Worker)
    filter!(u->u≠unit, p.workers)
    filter!(u->u≠unit, p.units)
end
function remove_unit!(p, unit::Fighter)
    filter!(u->u≠unit, p.fighters)
    filter!(u->u≠unit, p.units)
end

function clear_units!(p)
    empty!(p.units)
    empty!(p.workers)
    empty!(p.fighters)
end
function clear_workers!(p)
    filter!(u->!isa(u, Worker), p.units)
    empty!(p.workers)
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
workers = PlayerUnits()
add_worker!(workers)
destroy_unit!(workers.units[1])
@test 0 == length(workers.units)
w = add_worker!(workers)
w = add_worker!(workers)
@test 2 == length(workers.units)
attack!(w, Fighter(nothing))
attack!(w, Fighter(nothing))
@test 1 == length(workers.units)
