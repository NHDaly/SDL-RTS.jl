
buttons = Dict([
    # This button is disabled until the game starts.
    :bRestart =>
        MenuButton(false, UIPixelPos(0,0), UIPixelDims(200, 30), "New Game",
            ()->(resetGame(); buttons[:bNewContinue].callBack();))
    # Note that this text changes to "Continue" after first press.
    :bNewContinue =>
        MenuButton(true, UIPixelPos(0,0), UIPixelDims(200, 30), "New Game",
               ()->(global paused,game_started,buttons;
                    paused[] = false; game_started[] = true;
                    buttons[:bNewContinue].text = "Continue"; # After starting game
                    buttons[:bRestart].enabled = true;        # After starting game
                    ))
    :bSoundToggle =>
        CheckboxButton(true,
            MenuButton(true, UIPixelPos(0,0), UIPixelDims(200, 30), "Sound on/off",
                (enabled)->(toggleAudio(enabled)))
            )
    :bQuit =>
        MenuButton(true, UIPixelPos(0,0), UIPixelDims(200, 30), "Quit",
            ()->(global paused, playing; paused[] = playing[] = false;))

     # Key controls buttons
    :keyALeft =>
        KeyButton(true, UIPixelPos(0,0), UIPixelDims(120, 20), keyDisplayNames[keySettings[:keyP1Collector]],
               ()->(tryChangingKeySettingButton(:keyALeft)))
    :keyARight =>
        KeyButton(true, UIPixelPos(0,0), UIPixelDims(120, 20), keyDisplayNames[keySettings[:keyP1Fighter]],
               ()->(tryChangingKeySettingButton(:keyARight)))
    :keyP2Collector =>
        KeyButton(true, UIPixelPos(0,0), UIPixelDims(120, 20), keyDisplayNames[keySettings[:keyP2Collector]],
               ()->(tryChangingKeySettingButton(:keyP2Collector)))
    :keyP2Fighter =>
        KeyButton(true, UIPixelPos(0,0), UIPixelDims(120, 20), keyDisplayNames[keySettings[:keyP2Fighter]],
               ()->(tryChangingKeySettingButton(:keyP2Fighter)))

    :bResetDefaultKeys =>
        KeyButton(false, UIPixelPos(0,0), UIPixelDims(240, 30), "Reset Default Controls",
               ()->(resetDefaultKeys()))
  ])
paddleAControlsX() = screenCenterX()-260
paddleBControlsX() = screenCenterX()+260
function recenterButtons!()
    global buttons
    buttons[:bRestart].pos     = screenOffsetFromCenter(0,-25)
    buttons[:bNewContinue].pos = screenOffsetFromCenter(0,9)
    buttons[:bSoundToggle].button.pos = screenOffsetFromCenter(0,43)
    buttons[:bQuit].pos        = screenOffsetFromCenter(0,77)
    buttons[:keyALeft].pos    = UIPixelPos(paddleAControlsX(), winHeight[]-147)
    buttons[:keyARight].pos   = UIPixelPos(paddleAControlsX(), winHeight[]-122)
    buttons[:keyP2Collector].pos    = UIPixelPos(paddleBControlsX(), winHeight[]-147)
    buttons[:keyP2Fighter].pos   = UIPixelPos(paddleBControlsX(), winHeight[]-122)
    buttons[:bResetDefaultKeys].pos   = UIPixelPos(screenCenterX(), winHeight[]-102)
end
function toggleAudio(enabled)
    global audioEnabled;
    audioEnabled = enabled;
    if (audioEnabled) SDL2.Mix_ResumeMusic()
    else  SDL2.Mix_PauseMusic()
    end
end
