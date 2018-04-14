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

struct ScreenPixelPos <: AbstractCoord  # 0,0 == top-left
    x::Int
    y::Int
end
ScreenPixelPos(x::Number, y::Number) = ScreenPixelPos(convert.(Int, floor.((x,y)))...)
struct UIPixelPos <: AbstractCoord  # 0,0 == top-left (Same as ScreenPixelPos but not scaled.)
    x::Int
    y::Int
end
UIPixelPos(x::Number, y::Number) = UIPixelPos(convert.(Int, floor.((x,y)))...)

+(a::UIPixelPos, b::UIPixelPos) = UIPixelPos(a.x+b.x, a.y+b.y)
.+(a::UIPixelPos, x::Number) = UIPixelPos(a.x+x, a.y+x)

mutable struct Camera
    pos::WorldPos
    w::Threads.Atomic{Int32}   # Note: These are Atomics, since they can be modified by the
    h::Threads.Atomic{Int32}   # windowEventWatcher callback, which can run in another thread!
end
Camera() = Camera(WorldPos(0,0),100,100)

screenCenter() = UIPixelPos(winWidth[]/2, winHeight[]/2)
screenCenterX() = winWidth[]/2
screenCenterY() = winHeight[]/2
screenOffsetFromCenter(x::Int,y::Int) = UIPixelPos(screenCenterX()+x,screenCenterY()+y)

worldScale(c::Camera) = cam.w[] / winWidth[];
function toScreenPos(p::WorldPos, c::Camera)
    scale = worldScale(c)
    ScreenPixelPos(
        floor(c.w[]/2. + scale*p.x), floor(c.h[]/2. - scale*p.y))
end
function toScreenPos(p::UIPixelPos, c::Camera)
    scale = worldScale(c)
    ScreenPixelPos(floor(scale*p.x), floor(scale*p.y))
end
toScreenPos(p::ScreenPixelPos, c::Camera) = p
function toWorldPos(p::ScreenPixelPos, c::Camera)
    scale = worldScale(c)
    WorldPos(floor(p.x - c.w[]/2.)/scale, -floor(p.y - c.h[]/2.)/scale)
end
function toWorldPos(p::UIPixelPos, c::Camera)
    toWorldPos(toScreenPos(p, cam))
end
function toUIPixelPos(p::ScreenPixelPos, c::Camera)
    scale = worldScale(c)
    ScreenPixelPos(floor(p.x/scale), floor(p.y/scale))
end
function toUIPixelPos(p::WorldPos, c::Camera)
    toUIPixelPos(toScreenPos(p))
end
toUIPixelPos(p::UIPixelPos, c::Camera) = p
function screenScaleDims(w,h,c::Camera)
    scale = worldScale(c)
    round(scale*w), round(scale*h) # round to whole pixels
end

SetRenderDrawColor(renderer::Ptr{SDL2.Renderer}, c::SDL2.Color) = SDL2.SetRenderDrawColor(
    renderer, Int64(c.r), Int64(c.g), Int64(c.b), Int64(c.a))

topLeftPos(center::T, unitW, unitH) where {T<:AbstractCoord} = T(center.x - unitW/2., center.y + unitH/2.)
function renderRectCentered(cam, renderer, center::AbstractCoord, unitW, unitH, color; outlineColor=nothing)
    topLeft = topLeftPos(center, unitW, unitH)
    renderRectTopLeft(cam, renderer, topLeft, unitW, unitH, color; outlineColor=outlineColor)
end
function renderRectTopLeft(cam, renderer, topLeft::AbstractCoord, unitW, unitH, color; outlineColor=nothing)
    screenPos = toScreenPos(topLeft, cam)
    rect = SDL2.Rect(screenPos.x, screenPos.y, screenScaleDims(unitW, unitH, cam)...)
    if color != nothing
        SetRenderDrawColor(renderer, color)
        SDL2.RenderFillRect(renderer, Ref(rect) )
    end
    if outlineColor != nothing
        SetRenderDrawColor(renderer, outlineColor)
        SDL2.RenderDrawRect(renderer, Ref(rect) )
    end
end

function renderProgressBar(percent, cam::Camera, renderer, center, w, h, color, bgColor, boxColor)
    # bg
    renderRectCentered(cam, renderer, center, w, h, bgColor)
    # health
    topLeft = topLeftPos(center, w, h)
    renderRectTopLeft(cam, renderer, topLeft, percent * w, h, color)
    # outline
    renderRectCentered(cam, renderer, center, w, h, nothing; outlineColor=boxColor)
end
function renderUnit(o::UnitTypes, playerColor, cam::Camera, renderer, unitW, unitH, color)
    # First render the player color, then the unit color (for transparency)
    renderRectCentered(cam, renderer, o.pos, unitW, unitH, playerColor)
    renderRectCentered(cam, renderer, o.pos, unitW, unitH, color)

    # render health bar
    healthBarPos = WorldPos(o.pos.x, o.pos.y + unitH/2 + healthBarRenderOffset)
    renderProgressBar(health_percent(o), cam, renderer, healthBarPos,
          healthBarRenderWidth, healthBarRenderHeight, healthBarColor,
          kBackgroundColor, healthBarOutlineColor)
end
function render(o::Worker, playerColor, cam::Camera, renderer)
    unitW, unitH = workerRenderWidth, workerRenderWidth
    renderUnit(o, playerColor, cam, renderer, unitW, unitH, kWorkerColor)
end
function render(o::Fighter, playerColor, cam::Camera, renderer)
    unitW, unitH = unitRenderWidth, unitRenderWidth
    renderUnit(o, playerColor, cam, renderer, unitW, unitH, kFighterColor)
end

abstract type AbstractButton end
mutable struct MenuButton <: AbstractButton
    enabled::Bool
    pos::UIPixelPos
    w::Int
    h::Int
    text::String
    callBack
end
mutable struct KeyButton <: AbstractButton
    enabled::Bool
    pos::UIPixelPos
    w::Int
    h::Int
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
    topLeft = UIPixelPos(b.pos.x - b.w/2., b.pos.y - b.h/2.)
    screenPos = toScreenPos(topLeft, cam)
    rect = SDL2.Rect(screenPos.x, screenPos.y, screenScaleDims(b.w, b.h, cam)...)
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
    checkbox_radius = b.h/2. - border  # (checkbox is a square)
    topLeft = topLeftPos(b.pos, b.w, b.h)
    topLeft = topLeft .+ border
    screenPos = toScreenPos(topLeft, cam)
    rect = SDL2.Rect(screenPos.x, screenPos.y, screenScaleDims(checkbox_radius*2, checkbox_radius*2, cam)...)
    SetRenderDrawColor(renderer, color)
    SDL2.RenderFillRect(renderer, Ref(rect) )
end

# ---- Text Rendering ----

fonts_cache = Dict()
txt_cache = Dict()
function sizeText(cam, txt, fontName, fontSize)
    scale = worldScale(cam)
    sizeText(scale, txt, loadFont(scale, fontName, fontSize))
end
function sizeText(scale, txt, font::Ptr{SDL2.TTF_Font})
   fw,fh = Cint[1], Cint[1]
   SDL2.TTF_SizeText(font, txt, pointer(fw), pointer(fh))
   return fw[1]/scale,fh[1]/scale
end
function loadFont(scale, fontName, fontSize)
   fontSize = scale*fontSize
   fontKey = (fontName, fontSize)
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
   font = loadFont(worldScale(cam), fontName, fontSize)
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

   return tex, fw, fh
end
@enum TextAlign centered leftJustified rightJustified
function renderText(renderer, cam::Camera, txt::String, pos::UIPixelPos
                    ; fontName = defaultFontName,
                     fontSize=defaultFontSize, align::TextAlign = centered)
   tex, fw, fh = createText(renderer, cam, txt, fontName, fontSize)
   renderTextSurface(renderer, cam, pos, tex, fw, fh, align)
end

function renderTextSurface(renderer, cam::Camera, pos::AbstractCoord,
                           tex::Ptr{SDL2.Texture}, fw::Integer, fh::Integer, align::TextAlign)
   screenPos = toScreenPos(pos, cam)
   renderPos = SDL2.Rect(0,0,0,0)
   if align == centered
       renderPos = SDL2.Rect(Int(floor(screenPos.x-fw/2.)), Int(floor(screenPos.y-fh/2.)), fw,fh)
   elseif align == leftJustified
       renderPos = SDL2.Rect(Int(floor(screenPos.x)), Int(floor(screenPos.y-fh/2.)), fw,fh)
   else # align == rightJustified
       renderPos = SDL2.Rect(Int(floor(screenPos.x-fw)), Int(floor(screenPos.y-fh/2.)), fw,fh)
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
        widths = [sizeText(cam, line, fontName, fontSize)[1] for line in lines]
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

function render(t::Ptr{SDL2.Texture}, pos, cam::Camera, renderer; size = nothing)
    if (t == C_NULL) return end
    pos = toScreenPos(pos, cam)
    if size != nothing
        size = toScreenPos(size, cam)
        w = size.x
        h = size.y
    else
        w,h,access = Cint[1], Cint[1], Cint[1]
        format = Cuint[1]
        SDL2.QueryTexture( t, format, access, w, h );
        w,h = w[], h[]
    end
    rect = SDL2.Rect(pos.x - w÷2,pos.y - h÷2,w,h)
    SDL2.RenderCopy(renderer, t, C_NULL, pointer_from_objref(rect))
end
