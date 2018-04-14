# Objects in the game and their supporting functions (update!, collide!, ...)

# Abstract coordinate system for the game. can convert between different systems.
abstract type AbstractCoordSystem end
abstract type AbstractPos{CoordType<:AbstractCoordSystem} end
abstract type AbstractDims{CoordType<:AbstractCoordSystem} end

""" WorldCoords are the absolute space of the game, independent of camera. """
struct WorldCoords <: AbstractCoordSystem end

"""
    WorldPos(5.0,-200.0)
x,y float coordinates in the game world (not necessarily the same as pixel
coordinates on the screen).
"""
struct WorldPos <: AbstractPos{WorldCoords}  # 0,0 == middle
    x::Float64
    y::Float64
end
toWorldPos(p::WorldPos, c) = p
"""
    WorldDims(5.0,-200.0)
w,h float dimensions in the game world (not necessarily the same as pixel
coordinates on the screen).
"""
struct WorldDims <: AbstractDims{WorldCoords}  # 0,0 == middle
    w::Float64
    h::Float64
end
toWorldDims(d::WorldDims, c) = d

"""
    Vector2D(-2.5,1.0)
x,y vector representing direction in the game world. Could represent a velocity,
a distance, etc. Subtracting two `WorldPos`itions results in a `Vector2D`.
"""
struct Vector2D
    x::Float64
    y::Float64
end
import Base.*, Base./, Base.-, Base.+
+(a::Vector2D, b::Vector2D) = Vector2D(a.x+b.x, a.y+b.y)
-(a::Vector2D, b::Vector2D) = Vector2D(a.x-b.x, a.y-b.y)
*(a::Vector2D, x::Number) = Vector2D(a.x*x, a.y*x)
*(x::Number, a::Vector2D) = a*x
/(a::Vector2D, x::Number) = Vector2D(a.x/x, a.y/x)
+(a::WorldPos, b::Vector2D) = WorldPos(a.x+b.x, a.y+b.y)
-(a::WorldPos, b::Vector2D) = WorldPos(a.x-b.x, a.y-b.y)
+(a::Vector2D, b::WorldPos) = WorldPos(a.x+b.x, a.y+b.y)
-(a::Vector2D, b::WorldPos) = WorldPos(a.x-b.x, a.y-b.y)
-(a::WorldPos, b::WorldPos) = Vector2D(a.x-b.x, a.y-b.y)
-(x::WorldPos) = WorldPos(-x.x, -x.y)
-(x::Vector2D) = Vector2D(-x.x, -x.y)
