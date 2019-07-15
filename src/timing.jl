mutable struct Timer
    starttime_ns::typeof(Base.time_ns())
    paused_elapsed_ns::typeof(Base.time_ns())
    Timer() = new(0,0)
end

function start!(timer::Timer)
    timer.starttime_ns = (Base.time_ns)()
    return nothing
end
started(timer::Timer) = (timer.starttime_ns ≠ 0)

""" Return seconds since timer was started or 0 if not yet started. """
function elapsed(timer::Timer)
    local elapsedtime_ns = (Base.time_ns)() - timer.starttime_ns
    return started(timer) * float(elapsedtime_ns) / 1000000000
end

function pause!(timer::Timer)
    timer.paused_elapsed_ns = (Base.time_ns)() - timer.starttime_ns
    return nothing
end
function unpause!(timer::Timer)
    timer.starttime_ns = (Base.time_ns)()
    timer.starttime_ns -= timer.paused_elapsed_ns;
    return nothing
end

t = Timer()
start!(t)
elapsed(t)
pause!(t)
unpause!(t)
elapsed(t)


# -----------------

""" Like Timer, but uses in-game time instead of wall time. """
mutable struct GameTimer
    elapsed_ns::typeof(Base.time_ns())
    started::Bool
    paused::Bool
    GameTimer() = new(0, false, false)
end

function update!(timer::GameTimer, dt)
    if timer.started && !timer.paused
        timer.elapsed_ns += round(dt * 1e9)  # secs to nanoseconds
    end
    return nothing
end

function start!(timer::GameTimer)
    timer.started = true
    return nothing
end
started(timer::GameTimer) = timer.started
elapsed(timer::GameTimer) = timer.elapsed_ns / 1e9

function pause!(timer::GameTimer)
    timer.paused = true
    return nothing
end
function unpause!(timer::GameTimer)
    timer.paused = false
    return nothing
end

t = GameTimer()
start!(t)
update!(t, 2.0)
elapsed(t)
pause!(t)
update!(t, 2.0)
unpause!(t)
elapsed(t)
