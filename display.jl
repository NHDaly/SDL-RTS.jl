# Defines structus and functions relating to display.
# Defines `render` for all game objects.

function blendAlphaColors(x::SDL2.Color, y::SDL2.Color)
    xAlphaPercent = x.a / 255
    yAlphaPercent = y.a / 255
    r = round(x.r*xAlphaPercent + (y.r - Int32(x.r) * xAlphaPercent) * yAlphaPercent)
    g = round(x.g*xAlphaPercent + (y.g - Int32(x.g) * xAlphaPercent) * yAlphaPercent)
    b = round(x.b*xAlphaPercent + (y.b - Int32(x.b) * xAlphaPercent) * yAlphaPercent)
    a = round(x.a + (1-xAlphaPercent)*yAlphaPercent * 255)
    SDL2.Color(r,g,b,a)
end

""" Coordinate system to represent the screen, not the Game World.
Importantly, these are "upside-down" from WorldCoords: (0,0) is top-left, and
higher numbers go down and to the right.
"""
abstract type ScreenCoords <: AbstractCoordSystem end

""" ScreenPixelCoords are absolute space on screen, in actual pixels. """
struct ScreenPixelCoords <: ScreenCoords end

"""
    ScreenPixelPos(1200, 1150)
Absolute position on screen, in pixels. (0,0) is top-left of screen.
"""
struct ScreenPixelPos <: AbstractPos{ScreenPixelCoords}  # 0,0 == top-left
    x::Int
    y::Int
end
ScreenPixelPos(x::Number, y::Number) = ScreenPixelPos(convert.(Int, floor.((x,y)))...)

# TODO: CONSIDER SWITCHING TO DOWN-SCALING INSTEAD of up-scaling, so you can get
# more precise sizes (1.5 "pixels" -> 3 pixels). Or consider using Floats for UIPixelCoords.
""" UIPixelCoords are space on screen, in un-dpi-scaled "pixels". """
struct UIPixelCoords <: ScreenCoords end

"""
    UIPixelPos(400, 450)
Position on screen, in un-dpi-scaled "pixels". (0,0) is top-left of screen.

These should be used whenever placing anything on the screen, since they are
indepdent of resolution-scaling.
"""
struct UIPixelPos <: AbstractPos{UIPixelCoords}  # 0,0 == top-left
    x::Int
    y::Int
end
UIPixelPos(x::Number, y::Number) = UIPixelPos(convert.(Int, floor.((x,y)))...)

+(a::UIPixelPos, b::UIPixelPos) = UIPixelPos(a.x+b.x, a.y+b.y)
.+(a::UIPixelPos, x::Number) = UIPixelPos(a.x+x, a.y+x)


""" Absolute size on screen, in pixels. Use with ScreenPixelPos. """
struct ScreenPixelDims <: AbstractDims{ScreenPixelCoords}
    w::Int
    h::Int
end
""" Size on screen, in un-dpi-scaled "pixels". Use with UIPixelPos. """
struct UIPixelDims <: AbstractDims{UIPixelCoords}
    w::Int
    h::Int
end

mutable struct Camera
    pos::WorldPos
    # Note, these are in ScreenPixelDims size.
    w::Threads.Atomic{Int32}   # Note: These are Atomics, since they can be modified by the
    h::Threads.Atomic{Int32}   # windowEventWatcher callback, which can run in another thread!
end
Camera() = Camera(WorldPos(0,0),100,100)

screenCenter() = UIPixelPos(winWidth[]/2, winHeight[]/2)
screenCenterX() = winWidth[]/2
screenCenterY() = winHeight[]/2
screenOffsetFromCenter(x::Int,y::Int) = UIPixelPos(screenCenterX()+x,screenCenterY()+y)

dpiScale() = winWidth_highDPI[] / winWidth[];
worldScale(c::Camera) = dpiScale() * (winWidth[] / cam.w[]);
function toScreenPos(p::WorldPos, c::Camera)
    scale = worldScale(c)
    ScreenPixelPos(
        round(winWidth_highDPI[]/2. + scale*p.x), round(winHeight_highDPI[]/2. - scale*p.y))
end
function toScreenPos(p::UIPixelPos, c::Camera)
    scale = dpiScale()
    ScreenPixelPos(round(scale*p.x), round(scale*p.y))
end
toScreenPos(p::ScreenPixelPos, c::Camera) = p
function toWorldPos(p::ScreenPixelPos, c::Camera)
    scale = worldScale(c)
    WorldPos(round(p.x - c.w[]/2.)/scale, -round(p.y - c.h[]/2.)/scale)
end
function toWorldPos(p::UIPixelPos, c::Camera)
    toWorldPos(toScreenPos(p, cam), cam)
end
function toUIPixelPos(p::ScreenPixelPos, c::Camera)
    scale = dpiScale()
    UIPixelPos(round(p.x/scale), round(p.y/scale))
end
function toUIPixelPos(p::WorldPos, c::Camera)
    toUIPixelPos(toScreenPos(p, cam), cam)
end
toUIPixelPos(p::UIPixelPos, c::Camera) = p
function toScreenPixelDims(dims::UIPixelDims,c::Camera)
    scale = dpiScale()
    ScreenPixelDims(round(scale*dims.w), round(scale*dims.h))
end
function toScreenPixelDims(dims::WorldDims,c::Camera)
    scale = worldScale(c)  # TODO: This needs to be changed
    ScreenPixelDims(round(scale*dims.w), round(scale*dims.h))
end
toScreenPixelDims(dims::ScreenPixelDims,c::Camera) = dims
function toUIPixelDims(dims::ScreenPixelDims,c::Camera)
    scale = dpiScale()
    UIPixelDims(round(dims.w/scale), round(dims.h/scale))
end
function toUIPixelDims(d::WorldDims, c::Camera)
    toUIPixelDims(toScreenDims(d, cam), cam)
end
toUIPixelDims(dims::UIPixelDims,c::Camera) = dims

SetRenderDrawColor(renderer::Ptr{SDL2.Renderer}, c::SDL2.Color) = SDL2.SetRenderDrawColor(
    renderer, Int64(c.r), Int64(c.g), Int64(c.b), Int64(c.a))

# Convenience functions
import Base: start, next, done
start(a::Union{AbstractPos, AbstractDims}) = 1
next(p::AbstractPos, i) = (if (i==1) return (p.x,2) elseif (i==2) return (p.y,3) else throw(DomainError()) end)
next(p::AbstractDims, i) = (if (i==1) return (p.w,2) elseif (i==2) return (p.h,3) else throw(DomainError()) end)
done(p::Union{AbstractPos, AbstractDims}, i) = (i == 3)

topLeftPos(center::P, dims::D) where P<:AbstractPos{Coord} where D<:AbstractDims{Coord} where Coord<:ScreenCoords = P(center.x - dims.w/2., center.y - dims.h/2.)  # positive is down
topLeftPos(center::P, dims::D) where P<:AbstractPos{Coord} where D<:AbstractDims{Coord} where Coord<:WorldCoords = P(center.x - dims.w/2., center.y + dims.h/2.)  # positive is up
rectOrigin(center::P, dims::D) where P<:AbstractPos{C} where D<:AbstractDims{C} where {C} = P(center.x - dims.w/2., center.y - dims.h/2.)  # always minus
function renderRectCentered(cam, renderer, center::AbstractPos{C}, dims::AbstractDims{C}, color; outlineColor=nothing) where C
    origin = rectOrigin(center, dims)
    renderRectFromOrigin(cam, renderer, origin, dims, color; outlineColor=outlineColor)
end
function renderRectFromOrigin(cam, renderer, origin::AbstractPos{C}, dims::AbstractDims{C}, color; outlineColor=nothing) where C
    screenPos = toScreenPos(origin, cam)
    rect = SDL2.Rect(screenPos.x, screenPos.y, toScreenPixelDims(dims, cam)...)
    if color != nothing
        SetRenderDrawColor(renderer, color)
        SDL2.RenderFillRect(renderer, Ref(rect) )
    end
    if outlineColor != nothing
        SetRenderDrawColor(renderer, outlineColor)
        SDL2.RenderDrawRect(renderer, Ref(rect) )
    end
end

function renderProgressBar(percent, cam::Camera, renderer, center::AbstractPos{C}, dims::D, color, bgColor, boxColor) where D<:AbstractDims{C} where C
    # bg
    renderRectCentered(cam, renderer, center, dims, bgColor)
    # health
    origin = rectOrigin(center, dims)
    renderRectFromOrigin(cam, renderer, origin, D(round(percent * dims.w), dims.h), color)
    # outline
    renderRectCentered(cam, renderer, center, dims, nothing; outlineColor=boxColor)
end
function renderUnit(o::UnitTypes, playerColor, cam::Camera, renderer, dims::WorldDims, color)
    # First render the player color, then the unit color (for transparency)
    renderRectCentered(cam, renderer, o.pos, dims, playerColor)
    renderRectCentered(cam, renderer, o.pos, dims, color)

    # render health bar
    healthBarPos = toUIPixelPos(WorldPos(o.pos.x, o.pos.y + dims.h/2 + healthBarRenderOffset), cam)
    renderProgressBar(health_percent(o), cam, renderer, healthBarPos,
          UIPixelDims(healthBarRenderWidth, healthBarRenderHeight), healthBarColor,
          kBackgroundColor, healthBarOutlineColor)
end
function render(o::Worker, playerColor, cam::Camera, renderer)
    dims = WorldDims(workerRenderWidth, workerRenderWidth)
    renderUnit(o, playerColor, cam, renderer, dims, kWorkerColor)
end
function render(o::Fighter, playerColor, cam::Camera, renderer)
    dims = WorldDims(unitRenderWidth, unitRenderWidth)
    renderUnit(o, playerColor, cam, renderer, dims, kFighterColor)
end

abstract type AbstractButton end
mutable struct MenuButton <: AbstractButton
    enabled::Bool
    pos::UIPixelPos
    dims::UIPixelDims
    text::String
    callBack
end
mutable struct KeyButton <: AbstractButton
    enabled::Bool
    pos::UIPixelPos
    dims::UIPixelDims
    text::String
    callBack
end

mutable struct CheckboxButton
    toggled::Bool
    button::MenuButton
end

import Base.run
run(b::AbstractButton) = b.callBack()
function run(b::CheckboxButton)
    b.toggled = !b.toggled
    b.button.callBack(b.toggled)
end

# pointwise subtraction with bounds checking (floors to 0)
-(a::SDL2.Color, b::Int) = SDL2.Color(a.r-min(b,a.r), a.g-min(b,a.g), a.b-min(b,a.b), a.a-min(b,a.a))
SDL2.Color(1,5,1,1) - 2 == SDL2.Color(0,3,0,0)

function render(b::AbstractButton, cam::Camera, renderer, color, fontSize)
    if (!b.enabled)
         return
    end
    topLeft = rectOrigin(b.pos, b.dims)
    screenPos = toScreenPos(topLeft, cam)
    rect = SDL2.Rect(screenPos..., toScreenPixelDims(b.dims, cam)...)
    x,y = Int[0], Int[0]
    SDL2.GetMouseState(pointer(x), pointer(y))
    if clickedButton == b
        if mouseOnButton(UIPixelPos(x[],y[]),b,cam)
            color = color - 50
        else
            color = color - 30
        end
    else
        if mouseOnButton(UIPixelPos(x[],y[]),b,cam)
            color = color - 10
        end
    end
    SetRenderDrawColor(renderer, color)
    SDL2.RenderFillRect(renderer, Ref(rect) )
    renderText(renderer, cam, b.text, b.pos; fontSize = fontSize)
end

function render(b::MenuButton, cam::Camera, renderer)
    render(b, cam, renderer, kMenuButtonColor, kMenuButtonFontSize)
end
function render(b::KeyButton, cam::Camera, renderer)
    render(b, cam, renderer, kKeySettingButtonColor, kKeyButtonFontSize)
end

function render(b::CheckboxButton, cam::Camera, renderer)
    # Hack: move button text offcenter before rendering to accomodate checkbox
    offsetText = " "
    text_backup = b.button.text
    b.button.text = offsetText * b.button.text
    render(b.button, cam, renderer)
    b.button.text = text_backup

    # Render checkbox
    render_checkbox_square(b.button, 6, SDL2.Color(200,200,200, 255), cam, renderer)

    if b.toggled
        # Inside checkbox "fill"
        render_checkbox_square(b.button, 8, SDL2.Color(100,100,100, 255), cam, renderer)
    end
end

function render_checkbox_square(b::AbstractButton, border, color, cam, renderer)
    checkbox_radius = b.dims.h/2. - border  # (checkbox is a square)
    topLeft = rectOrigin(b.pos, b.dims)
    topLeft = topLeft .+ border
    screenPos = toScreenPos(topLeft, cam)
    screenDims = toScreenPixelDims(UIPixelDims(checkbox_radius*2, checkbox_radius*2), cam)
    rect = SDL2.Rect(screenPos..., screenDims...)
    SetRenderDrawColor(renderer, color)
    SDL2.RenderFillRect(renderer, Ref(rect) )
end

# ---- Text Rendering ----

fonts_cache = Dict()
txt_cache = Dict()
function sizeText(txt, fontName, fontSize)
    sizeText(txt, loadFont(dpiScale(), fontName, fontSize))
end
function sizeText(txt, font::Ptr{SDL2.TTF_Font})
   fw,fh = Cint[1], Cint[1]
   SDL2.TTF_SizeText(font, txt, pointer(fw), pointer(fh))
   return ScreenPixelDims(fw[1],fh[1])
end
function loadFont(scale, fontName, fontSize)
   fontSize = scale*fontSize
   fontKey = (fontName, Cint(round(fontSize)))
   if haskey(fonts_cache, fontKey)
       font = fonts_cache[fontKey]
   else
       font = SDL2.TTF_OpenFont(fontKey...)
       font == C_NULL && throw(ErrorException("Failed to load font '$fontKey'"))
       fonts_cache[fontKey] = font
   end
   return font
end
function createText(renderer, cam, txt, fontName, fontSize)
   font = loadFont(dpiScale(), fontName, fontSize)
   txtKey = (font, txt)
   if haskey(txt_cache, txtKey)
       tex = txt_cache[txtKey]
   else
       text = SDL2.TTF_RenderText_Blended(font, txt, SDL2.Color(20,20,20,255))
       tex = SDL2.CreateTextureFromSurface(renderer,text)
       #SDL2.FreeSurface(text)
       txt_cache[txtKey] = tex
   end

   fw,fh = Cint[1], Cint[1]
   SDL2.TTF_SizeText(font, txt, pointer(fw), pointer(fh))
   fw,fh = fw[1],fh[1]

   return tex, ScreenPixelDims(fw, fh)
end
@enum TextAlign centered leftJustified rightJustified
function renderText(renderer, cam::Camera, txt::String, pos::UIPixelPos
                    ; fontName = defaultFontName,
                     fontSize=defaultFontSize, align::TextAlign = centered)
   tex, fDims = createText(renderer, cam, txt, fontName, fontSize)
   renderTextSurface(renderer, cam, pos, tex, toUIPixelDims(fDims,cam), align)
end

function renderTextSurface(renderer, cam::Camera, pos::AbstractPos{C},
                           tex::Ptr{SDL2.Texture}, dims::AbstractDims{C}, align::TextAlign) where C <:AbstractCoordSystem
   screenPos = toScreenPos(pos, cam)
   screenDims = toScreenPixelDims(dims, cam)
   x,y, fw, fh = screenPos.x, screenPos.y, screenDims.w, screenDims.h
   renderPos = SDL2.Rect(0,0,0,0)
   if align == centered
       renderPos = SDL2.Rect(Int(floor(x-fw/2.)), Int(floor(y-fh/2.)), fw,fh)
   elseif align == leftJustified
       renderPos = SDL2.Rect(Int(floor(x)), Int(floor(y-fh/2.)), fw,fh)
   else # align == rightJustified
       renderPos = SDL2.Rect(Int(floor(x-fw)), Int(floor(y-fh/2.)), fw,fh)
   end
   SDL2.RenderCopy(renderer, tex, C_NULL, pointer_from_objref(renderPos))
   #SDL2.DestroyTexture(tex)
end

function hcat_render_text(lines, renderer, cam, gap, pos::UIPixelPos;
         fixedWidth=nothing, fontName=defaultFontName, fontSize=defaultFontSize)
    numLines = size(lines)[1]
    if fixedWidth != nothing
        widths = fill(fixedWidth,size(lines))
    else
        widths = [toUIPixelDims(sizeText(line, fontName, fontSize), cam).w for line in lines]
    end
    totalWidth = sum(widths) + gap*(numLines-1)
    runningWidth = 0
    leftMostPos = pos.x - totalWidth/2.0
    text_centers = []
    for i in 1:numLines
        linePos = leftMostPos + runningWidth
        leftPos = UIPixelPos(linePos, pos.y)
        renderText(renderer, cam, lines[i], leftPos; fontName=fontName, fontSize=fontSize, align=leftJustified)
        runningWidth += widths[i] + gap
        push!(text_centers, UIPixelPos(leftPos.x + widths[i]÷2, leftPos.y))
    end
    return text_centers
end

#  ------- Image rendering ---------

function render(t::Ptr{SDL2.Texture}, pos::AbstractPos{C}, cam::Camera, renderer; size::Union{Void, AbstractDims{C}} = nothing) where C<:AbstractCoordSystem
    if (t == C_NULL) return end
    pos = toScreenPos(pos, cam)
    if size != nothing
        size = toScreenPixelDims(size, cam)
        w = size.w
        h = size.h
    else
        w,h,access = Cint[1], Cint[1], Cint[1]
        format = Cuint[1]
        SDL2.QueryTexture( t, format, access, w, h );
        w,h = w[], h[]
    end
    rect = SDL2.Rect(pos.x - w÷2,pos.y - h÷2,w,h)
    SDL2.RenderCopy(renderer, t, C_NULL, pointer_from_objref(rect))
end
