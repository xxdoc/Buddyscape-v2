Attribute VB_Name = "modDirectDraw7"
Option Explicit
' **********************
' ** Renders graphics **
' **********************
' DirectDraw7 Object
Public DD As DirectDraw7
' Clipper object
Public DD_Clip As DirectDrawClipper

' primary surface
Public DDS_Primary As DirectDrawSurface7
Public DDSD_Primary As DDSURFACEDESC2

' back buffer
Public DDS_BackBuffer As DirectDrawSurface7
Public DDSD_BackBuffer As DDSURFACEDESC2

' Used for pre-rendering
Public DDS_Map As DirectDrawSurface7
Public DDSD_Map As DDSURFACEDESC2

' gfx buffers
Public DDS_Item() As DirectDrawSurface7 ' arrays
Public DDS_Character() As DirectDrawSurface7
Public DDS_Paperdoll() As DirectDrawSurface7
Public DDS_Tileset() As DirectDrawSurface7
Public DDS_Resource() As DirectDrawSurface7
Public DDS_Animation() As DirectDrawSurface7
Public DDS_SpellIcon() As DirectDrawSurface7
Public DDS_Face() As DirectDrawSurface7
Public DDS_Projectile() As DirectDrawSurface7 ' projectiles
Public DDS_Door As DirectDrawSurface7 ' singes
Public DDS_Blood As DirectDrawSurface7
Public DDS_Misc As DirectDrawSurface7
Public DDS_Direction As DirectDrawSurface7
Public DDS_Target As DirectDrawSurface7
Public DDS_Bars As DirectDrawSurface7

' descriptions
Public DDSD_Temp As DDSURFACEDESC2 ' arrays
Public DDSD_Item() As DDSURFACEDESC2
Public DDSD_Character() As DDSURFACEDESC2
Public DDSD_Paperdoll() As DDSURFACEDESC2
Public DDSD_Tileset() As DDSURFACEDESC2
Public DDSD_Resource() As DDSURFACEDESC2
Public DDSD_Animation() As DDSURFACEDESC2
Public DDSD_SpellIcon() As DDSURFACEDESC2
Public DDSD_Face() As DDSURFACEDESC2
Public DDSD_Projectile() As DDSURFACEDESC2 ' projectiles
Public DDSD_Door As DDSURFACEDESC2 ' singles
Public DDSD_Blood As DDSURFACEDESC2
Public DDSD_Misc As DDSURFACEDESC2
Public DDSD_Direction As DDSURFACEDESC2
Public DDSD_Target As DDSURFACEDESC2
Public DDSD_Bars As DDSURFACEDESC2

' timers
Public Const SurfaceTimerMax As Long = 10000
Public CharacterTimer() As Long
Public PaperdollTimer() As Long
Public ItemTimer() As Long
Public ResourceTimer() As Long
Public AnimationTimer() As Long
Public SpellIconTimer() As Long
Public FaceTimer() As Long

' Number of graphic files
Public NumTileSets As Long
Public NumCharacters As Long
Public NumPaperdolls As Long
Public NumItems As Long
Public NumResources As Long
Public NumAnimations As Long
Public NumSpellIcons As Long
Public NumFaces As Long
Public NumProjectiles As Long ' projectiles

' ********************
' ** Initialization **
' ********************
Public Function InitDirectDraw() As Boolean
    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo errorhandler

    ' Clear DD7
    Call DestroyDirectDraw
    
    ' Init Direct Draw
    Set DD = DX7.DirectDrawCreate(vbNullString)
    
    ' Windowed
    DD.SetCooperativeLevel frmMain.hWnd, DDSCL_NORMAL

    ' Init type and set the primary surface
    With DDSD_Primary
        .lFlags = DDSD_CAPS
        .ddsCaps.lCaps = DDSCAPS_PRIMARYSURFACE
        .lBackBufferCount = 1
    End With
    Set DDS_Primary = DD.CreateSurface(DDSD_Primary)
    
    ' Create the clipper
    Set DD_Clip = DD.CreateClipper(0)
    
    ' Associate the picture hwnd with the clipper
    DD_Clip.SetHWnd frmMain.picScreen.hWnd
    
    ' Have the blits to the screen clipped to the picture box
    DDS_Primary.SetClipper DD_Clip
    
    ' Initialise the surfaces
    InitSurfaces
    
    ' We're done
    InitDirectDraw = True
    
    ' Error handler
    Exit Function
errorhandler:
    HandleError "InitDirectDraw", "modDirectDraw7", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
    Exit Function
End Function

Private Sub InitSurfaces()
Dim Rec As DxVBLib.RECT

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo errorhandler
    
    ' DirectDraw Surface memory management setting
    DDSD_Temp.lFlags = DDSD_CAPS
    DDSD_Temp.ddsCaps.lCaps = DDSCAPS_OFFSCREENPLAIN Or DDSCAPS_SYSTEMMEMORY
    
    ' clear out everything for re-init
    Set DDS_BackBuffer = Nothing

    ' Initialize back buffer
    With DDSD_BackBuffer
        .lFlags = DDSD_CAPS Or DDSD_WIDTH Or DDSD_HEIGHT
        .ddsCaps.lCaps = DDSD_Temp.ddsCaps.lCaps
        .lWidth = (MAX_MAPX + 3) * PIC_X
        .lHeight = (MAX_MAPY + 3) * PIC_Y
    End With
    Set DDS_BackBuffer = DD.CreateSurface(DDSD_BackBuffer)
    
    ' load persistent surfaces
    If FileExist(App.Path & "\data files\graphics\door.bmp", True) Then Call InitDDSurf("door", DDSD_Door, DDS_Door)
    If FileExist(App.Path & "\data files\graphics\direction.bmp", True) Then Call InitDDSurf("direction", DDSD_Direction, DDS_Direction)
    If FileExist(App.Path & "\data files\graphics\target.bmp", True) Then Call InitDDSurf("target", DDSD_Target, DDS_Target)
    If FileExist(App.Path & "\data files\graphics\misc.bmp", True) Then Call InitDDSurf("misc", DDSD_Misc, DDS_Misc)
    If FileExist(App.Path & "\data files\graphics\blood.bmp", True) Then Call InitDDSurf("blood", DDSD_Blood, DDS_Blood)
    If FileExist(App.Path & "\data files\graphics\bars.bmp", True) Then Call InitDDSurf("bars", DDSD_Bars, DDS_Bars)
    
    ' count the blood sprites
    BloodCount = DDSD_Blood.lWidth / 32
    
    ' Error handler
    Exit Sub
errorhandler:
    HandleError "InitSurfaces", "modDirectDraw7", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
    Exit Sub
End Sub

' This sub gets the mask color from the surface loaded from a bitmap image
Public Sub SetMaskColorFromPixel(ByRef TheSurface As DirectDrawSurface7, ByVal x As Long, ByVal y As Long)
Dim TmpR As RECT
Dim TmpDDSD As DDSURFACEDESC2
Dim TmpColorKey As DDCOLORKEY

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo errorhandler

    With TmpR
        .Left = x
        .top = y
        .Right = x
        .Bottom = y
    End With

    TheSurface.Lock TmpR, TmpDDSD, DDLOCK_WAIT Or DDLOCK_READONLY, 0

    With TmpColorKey
        .Low = TheSurface.GetLockedPixel(x, y)
        .High = .Low
    End With

    TheSurface.SetColorKey DDCKEY_SRCBLT, TmpColorKey
    TheSurface.Unlock TmpR
    
    ' Error handler
    Exit Sub
errorhandler:
    HandleError "SetMaskColorFromPixel", "modDirectDraw7", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
    Exit Sub
End Sub

' Initializing a surface, using a bitmap
Public Sub InitDDSurf(fileName As String, ByRef SurfDesc As DDSURFACEDESC2, ByRef Surf As DirectDrawSurface7)
    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo errorhandler

    ' Set path
    fileName = App.Path & GFX_PATH & fileName & GFX_EXT

    ' Destroy surface if it exist
    If Not Surf Is Nothing Then
        Set Surf = Nothing
        Call ZeroMemory(ByVal VarPtr(SurfDesc), LenB(SurfDesc))
    End If

    ' set flags
    SurfDesc.lFlags = DDSD_CAPS
    SurfDesc.ddsCaps.lCaps = DDSD_Temp.ddsCaps.lCaps
    
    ' init object
    Set Surf = DD.CreateSurfaceFromFile(fileName, SurfDesc)
    
    ' Set mask
    Call SetMaskColorFromPixel(Surf, 0, 0)
    
    ' Error handler
    Exit Sub
errorhandler:
    HandleError "InitDDSurf", "modDirectDraw7", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
    Exit Sub
End Sub

Public Function CheckSurfaces() As Boolean
    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo errorhandler

    ' Check if we need to restore surfaces
    If Not DD.TestCooperativeLevel = DD_OK Then
        CheckSurfaces = False
    Else
        CheckSurfaces = True
    End If
    
    ' Error handler
    Exit Function
errorhandler:
    HandleError "CheckSurfaces", "modDirectDraw7", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
    Exit Function
End Function

Private Function NeedToRestoreSurfaces() As Boolean
    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo errorhandler

    If Not DD.TestCooperativeLevel = DD_OK Then
        NeedToRestoreSurfaces = True
    End If
    
    ' Error handler
    Exit Function
errorhandler:
    HandleError "NeedToRestoreSurfaces", "modDirectDraw7", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
    Exit Function
End Function

Public Sub ReInitDD()
    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo errorhandler

    Call InitDirectDraw
    
    LoadTilesets
    
    ' Error handler
    Exit Sub
errorhandler:
    HandleError "ReInitDD", "modDirectDraw7", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
    Exit Sub
End Sub

Public Sub DestroyDirectDraw()
Dim i As Long
    
    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo errorhandler

    ' Unload DirectDraw
    Set DDS_Misc = Nothing
    
    For i = 1 To NumTileSets
        Set DDS_Tileset(i) = Nothing
        ZeroMemory ByVal VarPtr(DDSD_Tileset(i)), LenB(DDSD_Tileset(i))
    Next

    For i = 1 To NumItems
        Set DDS_Item(i) = Nothing
        ZeroMemory ByVal VarPtr(DDSD_Item(i)), LenB(DDSD_Item(i))
    Next

    For i = 1 To NumCharacters
        Set DDS_Character(i) = Nothing
        ZeroMemory ByVal VarPtr(DDSD_Character(i)), LenB(DDSD_Character(i))
    Next
    
    For i = 1 To NumPaperdolls
        Set DDS_Paperdoll(i) = Nothing
        ZeroMemory ByVal VarPtr(DDSD_Paperdoll(i)), LenB(DDSD_Paperdoll(i))
    Next
    
    For i = 1 To NumResources
        Set DDS_Resource(i) = Nothing
        ZeroMemory ByVal VarPtr(DDSD_Resource(i)), LenB(DDSD_Resource(i))
    Next
    
    For i = 1 To NumAnimations
        Set DDS_Animation(i) = Nothing
        ZeroMemory ByVal VarPtr(DDSD_Animation(i)), LenB(DDSD_Animation(i))
    Next
    
    For i = 1 To NumSpellIcons
        Set DDS_SpellIcon(i) = Nothing
        ZeroMemory ByVal VarPtr(DDSD_SpellIcon(i)), LenB(DDSD_SpellIcon(i))
    Next
    
    For i = 1 To NumFaces
        Set DDS_Face(i) = Nothing
        ZeroMemory ByVal VarPtr(DDSD_Face(i)), LenB(DDSD_Face(i))
    Next
    
    ' projectiles
    For i = 1 To NumProjectiles
        Set DDS_Projectile(i) = Nothing
        ZeroMemory ByVal VarPtr(DDSD_Projectile(i)), LenB(DDSD_Projectile(i))
    Next
    
    Set DDS_Blood = Nothing
    ZeroMemory ByVal VarPtr(DDSD_Blood), LenB(DDSD_Blood)
    
    Set DDS_Door = Nothing
    ZeroMemory ByVal VarPtr(DDSD_Door), LenB(DDSD_Door)
    
    Set DDS_Direction = Nothing
    ZeroMemory ByVal VarPtr(DDSD_Direction), LenB(DDSD_Direction)
    
    Set DDS_Target = Nothing
    ZeroMemory ByVal VarPtr(DDSD_Target), LenB(DDSD_Target)

    Set DDS_BackBuffer = Nothing
    Set DDS_Primary = Nothing
    Set DD_Clip = Nothing
    Set DD = Nothing
    
    ' Error handler
    Exit Sub
errorhandler:
    HandleError "DestroyDirectDraw", "modDirectDraw7", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
    Exit Sub
End Sub

' **************
' ** Blitting **
' **************
Public Sub Engine_BltFast(ByVal dx As Long, ByVal dy As Long, ByRef ddS As DirectDrawSurface7, srcRECT As RECT, trans As CONST_DDBLTFASTFLAGS)
    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo errorhandler


    If Not ddS Is Nothing Then
        Call DDS_BackBuffer.BltFast(dx, dy, ddS, srcRECT, trans)
    End If

    ' Error handler
    Exit Sub
errorhandler:
    HandleError "Engine_BltFast", "modDirectDraw7", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
    Exit Sub
End Sub

Public Function Engine_BltToDC(ByRef Surface As DirectDrawSurface7, sRECT As DxVBLib.RECT, dRECT As DxVBLib.RECT, ByRef picBox As VB.PictureBox, Optional Clear As Boolean = True) As Boolean
    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo errorhandler

    If Clear Then
        picBox.Cls
    End If

    Call Surface.BltToDC(picBox.hDC, sRECT, dRECT)
    picBox.Refresh
    Engine_BltToDC = True
    
    ' Error handler
    Exit Function
errorhandler:
    HandleError "Engine_BltToDC", "modDirectDraw7", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
    Exit Function
End Function

Public Sub BltDirection(ByVal x As Long, ByVal y As Long)
Dim Rec As DxVBLib.RECT
Dim i As Long
    
    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo errorhandler

    ' render grid
    Rec.top = 24
    Rec.Left = 0
    Rec.Right = Rec.Left + 32
    Rec.Bottom = Rec.top + 32
    Call Engine_BltFast(ConvertMapX(x * PIC_X), ConvertMapY(y * PIC_Y), DDS_Direction, Rec, DDBLTFAST_WAIT Or DDBLTFAST_SRCCOLORKEY)
    
    ' render dir blobs
    For i = 1 To 4
        Rec.Left = (i - 1) * 8
        Rec.Right = Rec.Left + 8
        ' find out whether render blocked or not
        If Not isDirBlocked(Map.Tile(x, y).DirBlock, CByte(i)) Then
            Rec.top = 8
        Else
            Rec.top = 16
        End If
        Rec.Bottom = Rec.top + 8
        'render!
        Call Engine_BltFast(ConvertMapX(x * PIC_X) + DirArrowX(i), ConvertMapY(y * PIC_Y) + DirArrowY(i), DDS_Direction, Rec, DDBLTFAST_WAIT Or DDBLTFAST_SRCCOLORKEY)
    Next
    
    ' Error handler
    Exit Sub
errorhandler:
    HandleError "BltDirection", "modDirectDraw7", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
    Exit Sub
End Sub

Public Sub BltTarget(ByVal x As Long, ByVal y As Long)
Dim sRECT As DxVBLib.RECT
Dim width As Long, height As Long
    
    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo errorhandler

    If DDS_Target Is Nothing Then Exit Sub
    
    width = DDSD_Target.lWidth / 2
    height = DDSD_Target.lHeight

    With sRECT
        .top = 0
        .Bottom = height
        .Left = 0
        .Right = width
    End With
    
    x = x - ((width - 32) / 2)
    y = y - (height / 2)
    
    x = ConvertMapX(x)
    y = ConvertMapY(y)
    
    ' clipping
    If y < 0 Then
        With sRECT
            .top = .top - y
        End With
        y = 0
    End If

    If x < 0 Then
        With sRECT
            .Left = .Left - x
        End With
        x = 0
    End If

    If y + height > DDSD_BackBuffer.lHeight Then
        sRECT.Bottom = sRECT.Bottom - (y + height - DDSD_BackBuffer.lHeight)
    End If

    If x + width > DDSD_BackBuffer.lWidth Then
        sRECT.Right = sRECT.Right - (x + width - DDSD_BackBuffer.lWidth)
    End If
    ' /clipping
    
    Call Engine_BltFast(x, y, DDS_Target, sRECT, DDBLTFAST_WAIT Or DDBLTFAST_SRCCOLORKEY)
    
    ' Error handler
    Exit Sub
errorhandler:
    HandleError "BltTarget", "modDirectDraw7", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
    Exit Sub
End Sub

Public Sub BltHover(ByVal tType As Long, ByVal target As Long, ByVal x As Long, ByVal y As Long)
Dim sRECT As DxVBLib.RECT
Dim width As Long, height As Long
    
    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo errorhandler

    If DDS_Target Is Nothing Then Exit Sub
    
    width = DDSD_Target.lWidth / 2
    height = DDSD_Target.lHeight

    With sRECT
        .top = 0
        .Bottom = height
        .Left = width
        .Right = .Left + width
    End With
    
    x = x - ((width - 32) / 2)
    y = y - (height / 2)

    x = ConvertMapX(x)
    y = ConvertMapY(y)
    
    ' clipping
    If y < 0 Then
        With sRECT
            .top = .top - y
        End With
        y = 0
    End If

    If x < 0 Then
        With sRECT
            .Left = .Left - x
        End With
        x = 0
    End If

    If y + height > DDSD_BackBuffer.lHeight Then
        sRECT.Bottom = sRECT.Bottom - (y + height - DDSD_BackBuffer.lHeight)
    End If

    If x + width > DDSD_BackBuffer.lWidth Then
        sRECT.Right = sRECT.Right - (x + width - DDSD_BackBuffer.lWidth)
    End If
    ' /clipping
    
    Call Engine_BltFast(x, y, DDS_Target, sRECT, DDBLTFAST_WAIT Or DDBLTFAST_SRCCOLORKEY)
    
    ' Error handler
    Exit Sub
errorhandler:
    HandleError "BltHover", "modDirectDraw7", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
    Exit Sub
End Sub

Public Sub BltMapTile(ByVal x As Long, ByVal y As Long)
Dim Rec As DxVBLib.RECT
Dim i As Long
    
    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo errorhandler

    With Map.Tile(x, y)
        For i = MapLayer.Ground To MapLayer.Mask2
            ' skip tile?
            If (.Layer(i).Tileset > 0 And .Layer(i).Tileset <= NumTileSets) And (.Layer(i).x > 0 Or .Layer(i).y > 0) Then
                ' sort out rec
                Rec.top = .Layer(i).y * PIC_Y
                Rec.Bottom = Rec.top + PIC_Y
                Rec.Left = .Layer(i).x * PIC_X
                Rec.Right = Rec.Left + PIC_X
                ' render
                Call Engine_BltFast(ConvertMapX(x * PIC_X), ConvertMapY(y * PIC_Y), DDS_Tileset(.Layer(i).Tileset), Rec, DDBLTFAST_WAIT Or DDBLTFAST_SRCCOLORKEY)
            End If
        Next
    End With
    
    ' Error handler
    Exit Sub
    
errorhandler:
    HandleError "BltMapTile", "modDirectDraw7", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
    Exit Sub
End Sub

Public Sub BltMapFringeTile(ByVal x As Long, ByVal y As Long)
Dim Rec As DxVBLib.RECT
Dim i As Long

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo errorhandler

    With Map.Tile(x, y)
        For i = MapLayer.Fringe To MapLayer.Fringe2
            ' skip tile if tileset isn't set
            If (.Layer(i).Tileset > 0 And .Layer(i).Tileset <= NumTileSets) And (.Layer(i).x > 0 Or .Layer(i).y > 0) Then
                ' sort out rec
                Rec.top = .Layer(i).y * PIC_Y
                Rec.Bottom = Rec.top + PIC_Y
                Rec.Left = .Layer(i).x * PIC_X
                Rec.Right = Rec.Left + PIC_X
                ' render
                Call Engine_BltFast(ConvertMapX(x * PIC_X), ConvertMapY(y * PIC_Y), DDS_Tileset(.Layer(i).Tileset), Rec, DDBLTFAST_WAIT Or DDBLTFAST_SRCCOLORKEY)
            End If
        Next
    End With
    
    ' Error handler
    Exit Sub
errorhandler:
    HandleError "BltMapFringeTile", "modDirectDraw7", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
    Exit Sub
End Sub

Public Sub BltDoor(ByVal x As Long, ByVal y As Long)
Dim Rec As DxVBLib.RECT
Dim x2 As Long, y2 As Long
    
    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo errorhandler

    ' sort out animation
    With TempTile(x, y)
        If .DoorAnimate = 1 Then ' opening
            If .DoorTimer + 100 < GetTickCount Then
                If .DoorFrame < 4 Then
                    .DoorFrame = .DoorFrame + 1
                Else
                    .DoorAnimate = 2 ' set to closing
                End If
                .DoorTimer = GetTickCount
            End If
        ElseIf .DoorAnimate = 2 Then ' closing
            If .DoorTimer + 100 < GetTickCount Then
                If .DoorFrame > 1 Then
                    .DoorFrame = .DoorFrame - 1
                Else
                    .DoorAnimate = 0 ' end animation
                End If
                .DoorTimer = GetTickCount
            End If
        End If
        
        If .DoorFrame = 0 Then .DoorFrame = 1
    End With

    With Rec
        .top = 0
        .Bottom = DDSD_Door.lHeight
        .Left = ((TempTile(x, y).DoorFrame - 1) * (DDSD_Door.lWidth / 4))
        .Right = .Left + (DDSD_Door.lWidth / 4)
    End With

    x2 = (x * PIC_X)
    y2 = (y * PIC_Y) - (DDSD_Door.lHeight / 2) + 4
    Call DDS_BackBuffer.BltFast(ConvertMapX(x2), ConvertMapY(y2), DDS_Door, Rec, DDBLTFAST_WAIT Or DDBLTFAST_SRCCOLORKEY)
    
    ' Error handler
    Exit Sub
errorhandler:
    HandleError "BltDoor", "modDirectDraw7", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
    Exit Sub
End Sub

Public Sub BltBlood(ByVal Index As Long)
Dim Rec As DxVBLib.RECT
    
    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo errorhandler

    With Blood(Index)
        ' check if we should be seeing it
        If .Timer + 20000 < GetTickCount Then Exit Sub
        
        Rec.top = 0
        Rec.Bottom = PIC_Y
        Rec.Left = (.Sprite - 1) * PIC_X
        Rec.Right = Rec.Left + PIC_X
        
        Engine_BltFast ConvertMapX(.x * PIC_X), ConvertMapY(.y * PIC_Y), DDS_Blood, Rec, DDBLTFAST_WAIT Or DDBLTFAST_SRCCOLORKEY
    End With
    
    ' Error handler
    Exit Sub
errorhandler:
    HandleError "BltBlood", "modDirectDraw7", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
    Exit Sub
End Sub

Public Sub BltAnimation(ByVal Index As Long, ByVal Layer As Long)
Dim Sprite As Long
Dim sRECT As DxVBLib.RECT
Dim dRECT As DxVBLib.RECT
Dim i As Long
Dim width As Long, height As Long
Dim looptime As Long
Dim FrameCount As Long
Dim x As Long, y As Long
Dim lockindex As Long
    
    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo errorhandler

    If AnimInstance(Index).Animation = 0 Then
        ClearAnimInstance Index
        Exit Sub
    End If
    
    Sprite = Animation(AnimInstance(Index).Animation).Sprite(Layer)
    
    If Sprite < 1 Or Sprite > NumAnimations Then Exit Sub
    
    FrameCount = Animation(AnimInstance(Index).Animation).Frames(Layer)
    
    AnimationTimer(Sprite) = GetTickCount + SurfaceTimerMax
    
    If DDS_Animation(Sprite) Is Nothing Then
        Call InitDDSurf("animations\" & Sprite, DDSD_Animation(Sprite), DDS_Animation(Sprite))
    End If
    
    ' total width divided by frame count
    width = DDSD_Animation(Sprite).lWidth / FrameCount
    height = DDSD_Animation(Sprite).lHeight
    
    sRECT.top = 0
    sRECT.Bottom = height
    sRECT.Left = (AnimInstance(Index).FrameIndex(Layer) - 1) * width
    sRECT.Right = sRECT.Left + width
    
    ' change x or y if locked
    If AnimInstance(Index).LockType > TARGET_TYPE_NONE Then ' if <> none
        ' is a player
        If AnimInstance(Index).LockType = TARGET_TYPE_PLAYER Then
            ' quick save the index
            lockindex = AnimInstance(Index).lockindex
            ' check if is ingame
            If IsPlaying(lockindex) Then
                ' check if on same map
                If GetPlayerMap(lockindex) = GetPlayerMap(MyIndex) Then
                    ' is on map, is playing, set x & y
                    x = (GetPlayerX(lockindex) * PIC_X) + 16 - (width / 2) + Player(lockindex).XOffset
                    y = (GetPlayerY(lockindex) * PIC_Y) + 16 - (height / 2) + Player(lockindex).YOffset
                End If
            End If
        ElseIf AnimInstance(Index).LockType = TARGET_TYPE_NPC Then
            ' quick save the index
            lockindex = AnimInstance(Index).lockindex
            ' check if NPC exists
            If MapNpc(lockindex).num > 0 Then
                ' check if alive
                If MapNpc(lockindex).Vital(Vitals.HitPoints) > 0 Then
                    ' exists, is alive, set x & y
                    x = (MapNpc(lockindex).x * PIC_X) + 16 - (width / 2) + MapNpc(lockindex).XOffset
                    y = (MapNpc(lockindex).y * PIC_Y) + 16 - (height / 2) + MapNpc(lockindex).YOffset
                Else
                    ' npc not alive anymore, kill the animation
                    ClearAnimInstance Index
                    Exit Sub
                End If
            Else
                ' npc not alive anymore, kill the animation
                ClearAnimInstance Index
                Exit Sub
            End If
        End If
    Else
        ' no lock, default x + y
        x = (AnimInstance(Index).x * 32) + 16 - (width / 2)
        y = (AnimInstance(Index).y * 32) + 16 - (height / 2)
    End If
    
    x = ConvertMapX(x)
    y = ConvertMapY(y)

    ' Clip to screen
    If y < 0 Then

        With sRECT
            .top = .top - y
        End With

        y = 0
    End If

    If x < 0 Then

        With sRECT
            .Left = .Left - x
        End With

        x = 0
    End If

    If y + height > DDSD_BackBuffer.lHeight Then
        sRECT.Bottom = sRECT.Bottom - (y + height - DDSD_BackBuffer.lHeight)
    End If

    If x + width > DDSD_BackBuffer.lWidth Then
        sRECT.Right = sRECT.Right - (x + width - DDSD_BackBuffer.lWidth)
    End If
    
    Call Engine_BltFast(x, y, DDS_Animation(Sprite), sRECT, DDBLTFAST_WAIT Or DDBLTFAST_SRCCOLORKEY)
    
    ' Error handler
    Exit Sub
errorhandler:
    HandleError "BltAnimation", "modDirectDraw7", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
    Exit Sub
End Sub

Public Sub BltItem(ByVal ItemNum As Long)
Dim PicNum As Long
Dim Rec As DxVBLib.RECT
Dim MaxFrames As Byte

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo errorhandler
    
    ' if it's not us then don't render
    If MapItem(ItemNum).playerName <> vbNullString Then
        If MapItem(ItemNum).playerName <> Trim$(GetPlayerName(MyIndex)) Then Exit Sub
    End If
    
    ' get the picture
    PicNum = Item(MapItem(ItemNum).num).Picture

    If PicNum < 1 Or PicNum > NumItems Then Exit Sub
    ItemTimer(PicNum) = GetTickCount + SurfaceTimerMax

    If DDS_Item(PicNum) Is Nothing Then
        Call InitDDSurf("items\" & PicNum, DDSD_Item(PicNum), DDS_Item(PicNum))
    End If

    If DDSD_Item(PicNum).lWidth > 64 Then ' has more than 1 frame
        With Rec
            .top = 0
            .Bottom = 32
            .Left = (MapItem(ItemNum).Frame * 32)
            .Right = .Left + 32
        End With
    Else
        With Rec
            .top = 0
            .Bottom = PIC_Y
            .Left = 0
            .Right = PIC_X
        End With
    End If

    Call Engine_BltFast(ConvertMapX(MapItem(ItemNum).x * PIC_X), ConvertMapY(MapItem(ItemNum).y * PIC_Y), DDS_Item(PicNum), Rec, DDBLTFAST_WAIT Or DDBLTFAST_SRCCOLORKEY)
    
    ' Error handler
    Exit Sub
errorhandler:
    HandleError "BltItem", "modDirectDraw7", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
    Exit Sub
End Sub

Public Sub ScreenshotMap()
Dim x As Long, y As Long, i As Long, Rec As RECT

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo errorhandler
    
    ' clear the surface
    Set DDS_Map = Nothing
    
    ' Initialize it
    With DDSD_Map
        .lFlags = DDSD_CAPS Or DDSD_WIDTH Or DDSD_HEIGHT
        .ddsCaps.lCaps = DDSD_Temp.ddsCaps.lCaps
        .lWidth = (Map.MaxX + 1) * 32
        .lHeight = (Map.MaxY + 1) * 32
    End With
    Set DDS_Map = DD.CreateSurface(DDSD_Map)
    
    ' render the tiles
    For x = 0 To Map.MaxX
        For y = 0 To Map.MaxY
            With Map.Tile(x, y)
                For i = MapLayer.Ground To MapLayer.Mask2
                    ' skip tile?
                    If (.Layer(i).Tileset > 0 And .Layer(i).Tileset <= NumTileSets) And (.Layer(i).x > 0 Or .Layer(i).y > 0) Then
                        ' sort out rec
                        Rec.top = .Layer(i).y * PIC_Y
                        Rec.Bottom = Rec.top + PIC_Y
                        Rec.Left = .Layer(i).x * PIC_X
                        Rec.Right = Rec.Left + PIC_X
                        ' render
                        DDS_Map.BltFast x * PIC_X, y * PIC_Y, DDS_Tileset(.Layer(i).Tileset), Rec, DDBLTFAST_WAIT Or DDBLTFAST_SRCCOLORKEY
                    End If
                Next
            End With
        Next
    Next
    
    ' render the resources
    For y = 0 To Map.MaxY
        If NumResources > 0 Then
            If Resources_Init Then
                If Resource_Index > 0 Then
                    For i = 1 To Resource_Index
                        If MapResource(i).y = y Then
                            Call BltMapResource(i, True)
                        End If
                    Next
                End If
            End If
        End If
    Next
    
    ' render the tiles
    For x = 0 To Map.MaxX
        For y = 0 To Map.MaxY
            With Map.Tile(x, y)
                For i = MapLayer.Fringe To MapLayer.Fringe2
                    ' skip tile?
                    If (.Layer(i).Tileset > 0 And .Layer(i).Tileset <= NumTileSets) And (.Layer(i).x > 0 Or .Layer(i).y > 0) Then
                        ' sort out rec
                        Rec.top = .Layer(i).y * PIC_Y
                        Rec.Bottom = Rec.top + PIC_Y
                        Rec.Left = .Layer(i).x * PIC_X
                        Rec.Right = Rec.Left + PIC_X
                        ' render
                        DDS_Map.BltFast x * PIC_X, y * PIC_Y, DDS_Tileset(.Layer(i).Tileset), Rec, DDBLTFAST_WAIT Or DDBLTFAST_SRCCOLORKEY
                    End If
                Next
            End With
        Next
    Next
    
    ' dump and save
    frmMain.picSSMap.width = DDSD_Map.lWidth
    frmMain.picSSMap.height = DDSD_Map.lHeight
    Rec.top = 0
    Rec.Left = 0
    Rec.Bottom = DDSD_Map.lHeight
    Rec.Right = DDSD_Map.lWidth
    Engine_BltToDC DDS_Map, Rec, Rec, frmMain.picSSMap
    SavePicture frmMain.picSSMap.Image, App.Path & "\map" & GetPlayerMap(MyIndex) & ".jpg"
    
    ' let them know we did it
    AddText "Screenshot of map #" & GetPlayerMap(MyIndex) & " saved.", BrightGreen
    
    ' Error handler
    Exit Sub
errorhandler:
    HandleError "ScreenshotMap", "modDirectDraw7", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
    Exit Sub
End Sub

Public Sub BltMapResource(ByVal Resource_num As Long, Optional ByVal screenShot As Boolean = False)
Dim Resource_master As Long
Dim Resource_state As Long
Dim Resource_sprite As Long
Dim Rec As DxVBLib.RECT
Dim x As Long, y As Long
    
    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo errorhandler

    ' make sure it's not out of map
    If MapResource(Resource_num).x > Map.MaxX Then Exit Sub
    If MapResource(Resource_num).y > Map.MaxY Then Exit Sub
    
    ' Get the Resource type
    Resource_master = Map.Tile(MapResource(Resource_num).x, MapResource(Resource_num).y).Data1
    
    If Resource_master = 0 Then Exit Sub

    If Resource(Resource_master).ResourceImage = 0 Then Exit Sub
    ' Get the Resource state
    Resource_state = MapResource(Resource_num).ResourceState

    If Resource_state = 0 Then ' normal
        Resource_sprite = Resource(Resource_master).ResourceImage
    ElseIf Resource_state = 1 Then ' used
        Resource_sprite = Resource(Resource_master).ExhaustedImage
    End If
    
    ' cut down everything if we're editing
    If InMapEditor Then
        Resource_sprite = Resource(Resource_master).ExhaustedImage
    End If

    ' Load early
    If DDS_Resource(Resource_sprite) Is Nothing Then
        Call InitDDSurf("Resources\" & Resource_sprite, DDSD_Resource(Resource_sprite), DDS_Resource(Resource_sprite))
    End If

    ' src rect
    With Rec
        .top = 0
        .Bottom = DDSD_Resource(Resource_sprite).lHeight
        .Left = 0
        .Right = DDSD_Resource(Resource_sprite).lWidth
    End With

    ' Set base x + y, then the offset due to size
    x = (MapResource(Resource_num).x * PIC_X) - (DDSD_Resource(Resource_sprite).lWidth / 2) + 16
    y = (MapResource(Resource_num).y * PIC_Y) - DDSD_Resource(Resource_sprite).lHeight + 32
    
    ' render it
    If Not screenShot Then
        Call BltResource(Resource_sprite, x, y, Rec)
    Else
        Call ScreenshotResource(Resource_sprite, x, y, Rec)
    End If
    
    ' Error handler
    Exit Sub
errorhandler:
    HandleError "BltMapResource", "modDirectDraw7", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
    Exit Sub
End Sub

Private Sub BltResource(ByVal Resource As Long, ByVal dx As Long, dy As Long, Rec As DxVBLib.RECT)
Dim x As Long
Dim y As Long
Dim width As Long
Dim height As Long
Dim destRECT As DxVBLib.RECT

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo errorhandler

    If Resource < 1 Or Resource > NumResources Then Exit Sub
    
    ResourceTimer(Resource) = GetTickCount + SurfaceTimerMax

    If DDS_Resource(Resource) Is Nothing Then
        Call InitDDSurf("Resources\" & Resource, DDSD_Resource(Resource), DDS_Resource(Resource))
    End If

    x = ConvertMapX(dx)
    y = ConvertMapY(dy)
    
    width = (Rec.Right - Rec.Left)
    height = (Rec.Bottom - Rec.top)

    If y < 0 Then
        With Rec
            .top = .top - y
        End With
        y = 0
    End If

    If x < 0 Then
        With Rec
            .Left = .Left - x
        End With
        x = 0
    End If

    If y + height > DDSD_BackBuffer.lHeight Then
        Rec.Bottom = Rec.Bottom - (y + height - DDSD_BackBuffer.lHeight)
    End If

    If x + width > DDSD_BackBuffer.lWidth Then
        Rec.Right = Rec.Right - (x + width - DDSD_BackBuffer.lWidth)
    End If

    ' End clipping
    Call Engine_BltFast(x, y, DDS_Resource(Resource), Rec, DDBLTFAST_WAIT Or DDBLTFAST_SRCCOLORKEY)
    
    ' Error handler
    Exit Sub
errorhandler:
    HandleError "BltResource", "modDirectDraw7", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
    Exit Sub
End Sub

Private Sub ScreenshotResource(ByVal Resource As Long, ByVal x As Long, y As Long, Rec As DxVBLib.RECT)
Dim width As Long
Dim height As Long
Dim destRECT As DxVBLib.RECT

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo errorhandler

    If Resource < 1 Or Resource > NumResources Then Exit Sub
    
    ResourceTimer(Resource) = GetTickCount + SurfaceTimerMax

    If DDS_Resource(Resource) Is Nothing Then
        Call InitDDSurf("Resources\" & Resource, DDSD_Resource(Resource), DDS_Resource(Resource))
    End If
    
    width = (Rec.Right - Rec.Left)
    height = (Rec.Bottom - Rec.top)

    If y < 0 Then
        With Rec
            .top = .top - y
        End With
        y = 0
    End If

    If x < 0 Then
        With Rec
            .Left = .Left - x
        End With
        x = 0
    End If

    If y + height > DDSD_Map.lHeight Then
        Rec.Bottom = Rec.Bottom - (y + height - DDSD_Map.lHeight)
    End If

    If x + width > DDSD_Map.lWidth Then
        Rec.Right = Rec.Right - (x + width - DDSD_Map.lWidth)
    End If

    ' End clipping
    'Call Engine_BltFast(x, y, DDS_Resource(Resource), rec, DDBLTFAST_WAIT Or DDBLTFAST_SRCCOLORKEY)
    DDS_Map.BltFast x, y, DDS_Resource(Resource), Rec, DDBLTFAST_WAIT Or DDBLTFAST_SRCCOLORKEY
    
    ' Error handler
    Exit Sub
errorhandler:
    HandleError "ScreenshotResource", "modDirectDraw7", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
    Exit Sub
End Sub

Private Sub BltBars()
Dim tmpY As Long, tmpX As Long
Dim sWidth As Long, sHeight As Long
Dim sRECT As RECT
Dim barWidth As Long
Dim i As Long, NpcNum As Long

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo errorhandler
    
    ' dynamic bar calculations
    sWidth = DDSD_Bars.lWidth
    sHeight = DDSD_Bars.lHeight / 4
    
    ' render health bars
    For i = 1 To MAX_MAP_NPCS
        NpcNum = MapNpc(i).num
        ' exists?
        If NpcNum > 0 Then
            ' alive?
            If MapNpc(i).Vital(Vitals.HitPoints) > 0 And MapNpc(i).Vital(Vitals.HitPoints) < Npc(NpcNum).Skill(Skills.HitPoints) Then
                ' lock to npc
                tmpX = MapNpc(i).x * PIC_X + MapNpc(i).XOffset + 16 - (sWidth / 2)
                tmpY = MapNpc(i).y * PIC_Y + MapNpc(i).YOffset + 35
                
                ' calculate the width to fill
                barWidth = ((MapNpc(i).Vital(Vitals.HitPoints) / sWidth) / (Npc(NpcNum).Skill(Skills.HitPoints) / sWidth)) * sWidth
                
                ' draw bar background
                With sRECT
                    .top = sHeight * 1 ' HP bar background
                    .Left = 0
                    .Right = .Left + sWidth
                    .Bottom = .top + sHeight
                End With
                Engine_BltFast ConvertMapX(tmpX), ConvertMapY(tmpY), DDS_Bars, sRECT, DDBLTFAST_WAIT Or DDBLTFAST_SRCCOLORKEY
                
                ' draw the bar proper
                With sRECT
                    .top = 0 ' HP bar
                    .Left = 0
                    .Right = .Left + barWidth
                    .Bottom = .top + sHeight
                End With
                Engine_BltFast ConvertMapX(tmpX), ConvertMapY(tmpY), DDS_Bars, sRECT, DDBLTFAST_WAIT Or DDBLTFAST_SRCCOLORKEY
            End If
        End If
    Next

    ' check for casting time bar
    If SpellBuffer > 0 Then
        If Spell(PlayerSpells(SpellBuffer)).CastingTime > 0 Then
            ' lock to player
            tmpX = GetPlayerX(MyIndex) * PIC_X + Player(MyIndex).XOffset + 16 - (sWidth / 2)
            tmpY = GetPlayerY(MyIndex) * PIC_Y + Player(MyIndex).YOffset + 35 + sHeight + 1
            
            ' calculate the width to fill
            barWidth = (GetTickCount - SpellBufferTimer) / ((Spell(PlayerSpells(SpellBuffer)).CastingTime * 1000)) * sWidth
            
            ' draw bar background
            With sRECT
                .top = sHeight * 3 ' cooldown bar background
                .Left = 0
                .Right = sWidth
                .Bottom = .top + sHeight
            End With
            Engine_BltFast ConvertMapX(tmpX), ConvertMapY(tmpY), DDS_Bars, sRECT, DDBLTFAST_WAIT Or DDBLTFAST_SRCCOLORKEY
            
            ' draw the bar proper
            With sRECT
                .top = sHeight * 2 ' cooldown bar
                .Left = 0
                .Right = barWidth
                .Bottom = .top + sHeight
            End With
            Engine_BltFast ConvertMapX(tmpX), ConvertMapY(tmpY), DDS_Bars, sRECT, DDBLTFAST_WAIT Or DDBLTFAST_SRCCOLORKEY
        End If
    End If
    
    ' draw own health bar
    If Player(MyIndex).Skill(Skills.HitPoints).Level > 0 And Player(MyIndex).Skill(Skills.HitPoints).Level < Player(MyIndex).Skill(Skills.HitPoints).MaxLevel Then
        ' lock to Player
        tmpX = GetPlayerX(MyIndex) * PIC_X + Player(MyIndex).XOffset + 16 - (sWidth / 2)
        tmpY = GetPlayerY(MyIndex) * PIC_X + Player(MyIndex).YOffset + 35
       
        ' calculate the width to fill
        barWidth = ((Player(MyIndex).Skill(Skills.HitPoints).Level / sWidth) / (Player(MyIndex).Skill(Skills.HitPoints).MaxLevel / sWidth)) * sWidth
       
        ' draw bar background
        With sRECT
            .top = sHeight * 1 ' HP bar background
            .Left = 0
            .Right = .Left + sWidth
            .Bottom = .top + sHeight
        End With
        Engine_BltFast ConvertMapX(tmpX), ConvertMapY(tmpY), DDS_Bars, sRECT, DDBLTFAST_WAIT Or DDBLTFAST_SRCCOLORKEY
       
        ' draw the bar proper
        With sRECT
            .top = 0 ' HP bar
            .Left = 0
            .Right = .Left + barWidth
            .Bottom = .top + sHeight
        End With
        Engine_BltFast ConvertMapX(tmpX), ConvertMapY(tmpY), DDS_Bars, sRECT, DDBLTFAST_WAIT Or DDBLTFAST_SRCCOLORKEY
    End If
    
    ' Error handler
    Exit Sub
errorhandler:
    HandleError "BltBars", "modDirectDraw7", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
    Exit Sub
End Sub

Public Sub BltHotbar()
Dim sRECT As RECT, dRECT As RECT, i As Long, num As String, n As Long

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo errorhandler

    frmMain.picHotbar.Cls
    For i = 1 To MAX_HOTBAR
        With dRECT
            .top = HotbarTop
            .Left = HotbarLeft + ((HotbarOffsetX + 32) * (((i - 1) Mod MAX_HOTBAR)))
            .Bottom = .top + 32
            .Right = .Left + 32
        End With
        
        With sRECT
            .top = 0
            .Left = 32
            .Bottom = 32
            .Right = 64
        End With
        
        Select Case Hotbar(i).sType
            Case 1 ' inventory
                If Len(Item(Hotbar(i).Slot).Name) > 0 Then
                    If Item(Hotbar(i).Slot).Picture > 0 Then
                        If DDS_Item(Item(Hotbar(i).Slot).Picture) Is Nothing Then
                            Call InitDDSurf("Items\" & Item(Hotbar(i).Slot).Picture, DDSD_Item(Item(Hotbar(i).Slot).Picture), DDS_Item(Item(Hotbar(i).Slot).Picture))
                        End If
                        Engine_BltToDC DDS_Item(Item(Hotbar(i).Slot).Picture), sRECT, dRECT, frmMain.picHotbar, False
                    End If
                End If
            Case 2 ' spell
                With sRECT
                    .top = 0
                    .Left = 0
                    .Bottom = 32
                    .Right = 32
                End With
                If Len(Spell(Hotbar(i).Slot).Name) > 0 Then
                    If Spell(Hotbar(i).Slot).Icon > 0 Then
                        If DDS_SpellIcon(Spell(Hotbar(i).Slot).Icon) Is Nothing Then
                            Call InitDDSurf("Spellicons\" & Spell(Hotbar(i).Slot).Icon, DDSD_SpellIcon(Spell(Hotbar(i).Slot).Icon), DDS_SpellIcon(Spell(Hotbar(i).Slot).Icon))
                        End If
                        ' check for cooldown
                        For n = 1 To MAX_PLAYER_SPELLS
                            If PlayerSpells(n) = Hotbar(i).Slot Then
                                ' has spell
                                If Not SpellCD(i) = 0 Then
                                    sRECT.Left = 32
                                    sRECT.Right = 64
                                End If
                            End If
                        Next
                        Engine_BltToDC DDS_SpellIcon(Spell(Hotbar(i).Slot).Icon), sRECT, dRECT, frmMain.picHotbar, False
                    End If
                End If
        End Select
        
        ' render the letters
        num = "F" & Str(i)
        DrawText frmMain.picHotbar.hDC, dRECT.Left + 2, dRECT.top + 16, num, QBColor(White)
    Next
    frmMain.picHotbar.Refresh
    
    ' Error handler
    Exit Sub
errorhandler:
    HandleError "BltHotbar", "modDirectDraw7", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
    Exit Sub
End Sub

Public Sub BltPlayer(ByVal Index As Long)
Dim Anim As Byte, i As Long, x As Long, y As Long
Dim Sprite As Long, spritetop As Long
Dim Rec As DxVBLib.RECT
Dim AttackSpeed As Long
    
    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo errorhandler

    Sprite = GetPlayerSprite(Index)

    If Sprite < 1 Or Sprite > NumCharacters Then Exit Sub
    
    CharacterTimer(Sprite) = GetTickCount + SurfaceTimerMax

    If DDS_Character(Sprite) Is Nothing Then
        Call InitDDSurf("characters\" & Sprite, DDSD_Character(Sprite), DDS_Character(Sprite))
    End If

    ' speed from weapon
    If GetPlayerEquipment(Index, weapon) > 0 Then
        AttackSpeed = Item(GetPlayerEquipment(Index, weapon)).Speed
    Else
        AttackSpeed = 1000
    End If

    ' Reset frame
    If Player(Index).Step = 3 Then
        Anim = 0
    ElseIf Player(Index).Step = 1 Then
        Anim = 2
    End If
    
    ' Check for attacking animation
    If Player(Index).AttackTimer + (AttackSpeed / 2) > GetTickCount Then
        If Player(Index).Attacking = 1 Then
            Anim = 3
        End If
    Else
        ' If not attacking, walk normally
        Select Case GetPlayerDir(Index)
            Case DIR_UP
                If (Player(Index).YOffset > 8) Then Anim = Player(Index).Step
            Case DIR_DOWN
                If (Player(Index).YOffset < -8) Then Anim = Player(Index).Step
            Case DIR_LEFT
                If (Player(Index).XOffset > 8) Then Anim = Player(Index).Step
            Case DIR_RIGHT
                If (Player(Index).XOffset < -8) Then Anim = Player(Index).Step
        End Select
    End If

    ' Check to see if we want to stop making him attack
    With Player(Index)
        If .AttackTimer + AttackSpeed < GetTickCount Then
            .Attacking = 0
            .AttackTimer = 0
        End If
    End With

    ' Set the left
    Select Case GetPlayerDir(Index)
        Case DIR_UP
            spritetop = 3
        Case DIR_RIGHT
            spritetop = 2
        Case DIR_DOWN
            spritetop = 0
        Case DIR_LEFT
            spritetop = 1
    End Select

    With Rec
        .top = spritetop * (DDSD_Character(Sprite).lHeight / 4)
        .Bottom = .top + (DDSD_Character(Sprite).lHeight / 4)
        .Left = Anim * (DDSD_Character(Sprite).lWidth / 4)
        .Right = .Left + (DDSD_Character(Sprite).lWidth / 4)
    End With
    
    If Sprite = 4 Then
        
        If spritetop = 3 Then spritetop = 1
        If spritetop = 2 Then spritetop = 0
    
        Rec.top = spritetop * DDSD_Character(Sprite).lHeight / 4
        Rec.Left = 0
        Rec.Right = DDSD_Character(Sprite).lWidth / 4
        Rec.Bottom = Rec.top + DDSD_Character(Sprite).lHeight / 4
        
        x = GetPlayerX(Index) * PIC_X + Player(Index).XOffset - ((DDSD_Character(Sprite).lWidth / 4 - 32))
    Else
        x = GetPlayerX(Index) * PIC_X + Player(Index).XOffset - ((DDSD_Character(Sprite).lWidth / 4) - 32 - 20)
    End If

    ' Is the player's height more than 32..?
    If (DDSD_Character(Sprite).lHeight) > 32 Then
        ' Create a 32 pixel offset for larger sprites
        y = GetPlayerY(Index) * PIC_Y + Player(Index).YOffset - ((DDSD_Character(Sprite).lHeight / 4) - 32)
    Else
        ' Proceed as normal
        y = GetPlayerY(Index) * PIC_Y + Player(Index).YOffset
    End If
    
    ' Render the shield first if we're facing down OR right
    If Player(Index).Dir = DIR_DOWN Or Player(Index).Dir = DIR_RIGHT Then
        If GetPlayerEquipment(Index, Shield) > 0 Then
            Call BltPaperdoll(x, y, Item(GetPlayerEquipment(Index, Shield)).Paperdoll(1), Anim, spritetop)
        End If
        
        ' render the actual sprite
        Call BltSprite(Sprite, x, y, Rec)
            
        If GetPlayerEquipment(Index, Helmet) > 0 Then
            
        Else
            If Sprite = 1 Then Call BltSprite(2, x, y, Rec)
        End If
        
        ' check for paperdolling
        For i = 2 To UBound(PaperdollOrder)
            If GetPlayerEquipment(Index, PaperdollOrder(i)) > 0 Then
                If Item(GetPlayerEquipment(Index, PaperdollOrder(i))).Paperdoll(Player(Index).Gender) > 0 Then
                    Call BltPaperdoll(x, y, Item(GetPlayerEquipment(Index, PaperdollOrder(i))).Paperdoll(Player(Index).Gender), Anim, spritetop)
                End If
            End If
        Next
    Else
    
        ' render the actual sprite
        If GetPlayerEquipment(Index, Helmet) > 0 Then
            
        Else
            If Sprite = 1 Then Call BltSprite(2, x, y, Rec)
        End If
        
        Call BltSprite(Sprite, x, y, Rec)
        
        If GetPlayerEquipment(Index, Helmet) > 0 Then
            
        Else
            If Sprite = 1 Then Call BltSprite(2, x, y, Rec)
        End If
    
        For i = 1 To UBound(PaperdollOrder)
            If GetPlayerEquipment(Index, PaperdollOrder(i)) > 0 Then
                If Item(GetPlayerEquipment(Index, PaperdollOrder(i))).Paperdoll(Player(Index).Gender) > 0 Then
                    Call BltPaperdoll(x, y, Item(GetPlayerEquipment(Index, PaperdollOrder(i))).Paperdoll(Player(Index).Gender), Anim, spritetop)
                End If
            End If
        Next
    End If
    
    ' Error handler
    Exit Sub
errorhandler:
    HandleError "BltPlayer", "modDirectDraw7", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
    Exit Sub
End Sub

Public Sub BltNpc(ByVal MapNpcNum As Long)
Dim Anim As Byte, i As Long, x As Long, y As Long, Sprite As Long, spritetop As Long
Dim Rec As DxVBLib.RECT
Dim AttackSpeed As Long
    
    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo errorhandler

    If MapNpc(MapNpcNum).num = 0 Then Exit Sub ' no npc set
    
    Sprite = Npc(MapNpc(MapNpcNum).num).Sprite

    If Sprite < 1 Or Sprite > NumCharacters Then Exit Sub
    
    CharacterTimer(Sprite) = GetTickCount + SurfaceTimerMax

    If DDS_Character(Sprite) Is Nothing Then
        Call InitDDSurf("characters\" & Sprite, DDSD_Character(Sprite), DDS_Character(Sprite))
    End If

    AttackSpeed = 1000

    ' Reset frame
    Anim = 0
    ' Check for attacking animation
    If MapNpc(MapNpcNum).AttackTimer + (AttackSpeed / 2) > GetTickCount Then
        If MapNpc(MapNpcNum).Attacking = 1 Then
            Anim = 3
        End If
    Else
        ' If not attacking, walk normally
        Select Case MapNpc(MapNpcNum).Dir
            Case DIR_UP
                If (MapNpc(MapNpcNum).YOffset > 8) Then Anim = MapNpc(MapNpcNum).Step
            Case DIR_DOWN
                If (MapNpc(MapNpcNum).YOffset < -8) Then Anim = MapNpc(MapNpcNum).Step
            Case DIR_LEFT
                If (MapNpc(MapNpcNum).XOffset > 8) Then Anim = MapNpc(MapNpcNum).Step
            Case DIR_RIGHT
                If (MapNpc(MapNpcNum).XOffset < -8) Then Anim = MapNpc(MapNpcNum).Step
        End Select
    End If

    ' Check to see if we want to stop making him attack
    With MapNpc(MapNpcNum)
        If .AttackTimer + AttackSpeed < GetTickCount Then
            .Attacking = 0
            .AttackTimer = 0
        End If
    End With

    ' Set the left
    Select Case MapNpc(MapNpcNum).Dir
        Case DIR_UP
            spritetop = 3
        Case DIR_RIGHT
            spritetop = 2
        Case DIR_DOWN
            spritetop = 0
        Case DIR_LEFT
            spritetop = 1
    End Select
    
    If Sprite = 4 Then
        If spritetop = 3 Then spritetop = 1
        If spritetop = 2 Then spritetop = 0
        Anim = 0
    End If

    With Rec
        .top = (DDSD_Character(Sprite).lHeight / 4) * spritetop
        .Bottom = .top + DDSD_Character(Sprite).lHeight / 4
        .Left = Anim * (DDSD_Character(Sprite).lWidth / 4)
        .Right = .Left + (DDSD_Character(Sprite).lWidth / 4)
    End With

    ' Calculate the X
    x = MapNpc(MapNpcNum).x * PIC_X + MapNpc(MapNpcNum).XOffset - ((DDSD_Character(Sprite).lWidth / 4 - 32) / 2)

    ' Is the player's height more than 32..?
    If (DDSD_Character(Sprite).lHeight / 4) > 32 Then
        ' Create a 32 pixel offset for larger sprites
        y = MapNpc(MapNpcNum).y * PIC_Y + MapNpc(MapNpcNum).YOffset - ((DDSD_Character(Sprite).lHeight / 4) - 32)
    Else
        ' Proceed as normal
        y = MapNpc(MapNpcNum).y * PIC_Y + MapNpc(MapNpcNum).YOffset
    End If

    Call BltSprite(Sprite, x, y, Rec)
    
    ' Error handler
    Exit Sub
errorhandler:
    HandleError "BltNpc", "modDirectDraw7", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
    Exit Sub
End Sub

Public Sub BltPaperdoll(ByVal x2 As Long, ByVal y2 As Long, ByVal Sprite As Long, ByVal Anim As Long, ByVal spritetop As Long)
Dim Rec As DxVBLib.RECT
Dim x As Long, y As Long
Dim width As Long, height As Long
    
    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo errorhandler

    If Sprite < 1 Or Sprite > NumPaperdolls Then Exit Sub
    
    If DDS_Paperdoll(Sprite) Is Nothing Then
        Call InitDDSurf("Paperdolls\" & Sprite, DDSD_Paperdoll(Sprite), DDS_Paperdoll(Sprite))
    End If
    
    With Rec
        .top = spritetop * (DDSD_Paperdoll(Sprite).lHeight / 4)
        .Bottom = .top + (DDSD_Paperdoll(Sprite).lHeight / 4)
        .Left = Anim * (DDSD_Paperdoll(Sprite).lWidth / 4)
        .Right = .Left + (DDSD_Paperdoll(Sprite).lWidth / 4)
    End With
    
    ' clipping
    x = ConvertMapX(x2)
    y = ConvertMapY(y2)
    width = (Rec.Right - Rec.Left)
    height = (Rec.Bottom - Rec.top)

    ' Clip to screen
    If y < 0 Then
        With Rec
            .top = .top - y
        End With
        y = 0
    End If

    If x < 0 Then
        With Rec
            .Left = .Left - x
        End With
        x = 0
    End If

    If y + height > DDSD_BackBuffer.lHeight Then
        Rec.Bottom = Rec.Bottom - (y + height - DDSD_BackBuffer.lHeight)
    End If

    If x + width > DDSD_BackBuffer.lWidth Then
        Rec.Right = Rec.Right - (x + width - DDSD_BackBuffer.lWidth)
    End If
    ' /clipping
    
    Call Engine_BltFast(x, y, DDS_Paperdoll(Sprite), Rec, DDBLTFAST_WAIT Or DDBLTFAST_SRCCOLORKEY)
    
    ' Error handler
    Exit Sub
errorhandler:
    HandleError "BltPaperdoll", "modDirectDraw7", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
    Exit Sub
End Sub

Private Sub BltSprite(ByVal Sprite As Long, ByVal x2 As Long, y2 As Long, Rec As DxVBLib.RECT)
Dim x As Long
Dim y As Long
Dim width As Long
Dim height As Long

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo errorhandler

    If Sprite < 1 Or Sprite > NumCharacters Then Exit Sub
    
    x = ConvertMapX(x2)
    y = ConvertMapY(y2)
    width = (Rec.Right - Rec.Left)
    height = (Rec.Bottom - Rec.top)

    ' clipping
    If y < 0 Then
        With Rec
            .top = .top - y
        End With
        y = 0
    End If

    If x < 0 Then
        With Rec
            .Left = .Left - x
        End With
        x = 0
    End If

    If y + height > DDSD_BackBuffer.lHeight Then
        Rec.Bottom = Rec.Bottom - (y + height - DDSD_BackBuffer.lHeight)
    End If

    If x + width > DDSD_BackBuffer.lWidth Then
        Rec.Right = Rec.Right - (x + width - DDSD_BackBuffer.lWidth)
    End If
    ' /clipping
    
    If DDS_Character(Sprite) Is Nothing Then
        Call InitDDSurf("Characters\" & Sprite, DDSD_Character(Sprite), DDS_Character(Sprite))
    End If
    
    Call Engine_BltFast(x, y, DDS_Character(Sprite), Rec, DDBLTFAST_WAIT Or DDBLTFAST_SRCCOLORKEY)
    
    ' Error handler
    Exit Sub
errorhandler:
    HandleError "BltSprite", "modDirectDraw7", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
    Exit Sub
End Sub

Sub BltAnimatedInvItems()
Dim i As Long
Dim ItemNum As Long, itempic As Long
Dim x As Long, y As Long
Dim MaxFrames As Byte
Dim Amount As Long
Dim Rec As RECT, rec_pos As RECT

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo errorhandler

    If Not InGame Then Exit Sub
    
    ' check for map animation changes#
    For i = 1 To MAX_MAP_ITEMS

        If MapItem(i).num > 0 Then
            itempic = Item(MapItem(i).num).Picture

            If itempic < 1 Or itempic > NumItems Then Exit Sub
            MaxFrames = (DDSD_Item(itempic).lWidth / 2) / 32 ' Work out how many frames there are. /2 because of inventory icons as well as ingame

            If MapItem(i).Frame < MaxFrames - 1 Then
                MapItem(i).Frame = MapItem(i).Frame + 1
            Else
                MapItem(i).Frame = 1
            End If
        End If

    Next

    For i = 1 To MAX_INV
        ItemNum = GetPlayerInvItemNum(MyIndex, i)

        If ItemNum > 0 And ItemNum <= MAX_ITEMS Then
            itempic = Item(ItemNum).Picture

            If itempic > 0 And itempic <= NumItems Then
                If DDSD_Item(itempic).lWidth > 64 Then
                    MaxFrames = (DDSD_Item(itempic).lWidth / 2) / 32 ' Work out how many frames there are. /2 because of inventory icons as well as ingame

                    If InvItemFrame(i) < MaxFrames - 1 Then
                        InvItemFrame(i) = InvItemFrame(i) + 1
                    Else
                        InvItemFrame(i) = 1
                    End If

                    With Rec
                        .top = 0
                        .Bottom = 32
                        .Left = (DDSD_Item(itempic).lWidth / 2) + (InvItemFrame(i) * 32) ' middle to get the start of inv gfx, then +32 for each frame
                        .Right = .Left + 32
                    End With

                    With rec_pos
                        .top = InvTop + ((InvOffsetY + 32) * ((i - 1) \ InvColumns))
                        .Bottom = .top + PIC_Y
                        .Left = InvLeft + ((InvOffsetX + 32) * (((i - 1) Mod InvColumns)))
                        .Right = .Left + PIC_X
                    End With

                    ' Load item if not loaded, and reset timer
                    ItemTimer(itempic) = GetTickCount + SurfaceTimerMax

                    If DDS_Item(itempic) Is Nothing Then
                        Call InitDDSurf("Items\" & itempic, DDSD_Item(itempic), DDS_Item(itempic))
                    End If

                    ' We'll now re-blt the item, and place the currency value over it again :P
                    Engine_BltToDC DDS_Item(itempic), Rec, rec_pos, frmMain.picInventory, False

                    ' If item is a stack - draw the amount you have
                    If GetPlayerInvItemValue(MyIndex, i) > 1 Then
                        y = rec_pos.top + 22
                        x = rec_pos.Left - 4
                        Amount = CStr(GetPlayerInvItemValue(MyIndex, i))
                        ' Draw currency but with k, m, b etc. using a convertion function
                        DrawText frmMain.picInventory.hDC, x, y, ConvertCurrency(Amount), QBColor(Yellow)

                        ' Check if it's gold, and update the label
                        If GetPlayerInvItemNum(MyIndex, i) = 1 Then '1 = gold :P
                            frmMain.lblGold.Caption = Format$(Amount, "#,###,###,###") & "g"
                        End If
                    End If
                End If
            End If
        End If

    Next

    frmMain.picInventory.Refresh
    
    ' Error handler
    Exit Sub
errorhandler:
    HandleError "BltAnimatedInvItems", "modDirectDraw7", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
    Exit Sub
End Sub

Sub BltEquipment()
Dim i As Long, ItemNum As Long, itempic As Long
Dim Rec As RECT, rec_pos As RECT
Dim Amount As Long, colour As Long
Dim x As Long, y As Long

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo errorhandler

    If NumItems = 0 Then Exit Sub
    
    frmMain.picCharacter.Cls

    For i = 1 To Equipment.Equipment_Count - 1
        ItemNum = GetPlayerEquipment(MyIndex, i)
        
        
        With rec_pos
            Select Case i
                Case Equipment.Helmet
                    .top = 46
                    .Left = 80
                Case Equipment.Cape
                    .top = 86
                    .Left = 40
                Case Equipment.Amulet
                    .top = 86
                    .Left = 80
                Case Equipment.Arrows
                    .top = 86
                    .Left = 120
                Case Equipment.weapon
                    .top = 126
                    .Left = 26
                Case Equipment.Torso
                    .top = 126
                    .Left = 80
                Case Equipment.Shield
                    .top = 126
                    .Left = 133
                Case Equipment.Legs
                    .top = 166
                    .Left = 80
                Case Equipment.Gloves
                    .top = 206
                    .Left = 26
                Case Equipment.Boots
                    .top = 206
                    .Left = 80
                Case Equipment.Ring
                    .top = 206
                    .Left = 133
            End Select
            
            .Right = .Left + PIC_X
            .Bottom = .top + PIC_Y
        End With

        If ItemNum > 0 Then
            itempic = Item(ItemNum).Picture

            With Rec
                .top = 0
                .Bottom = 32
                .Left = 32
                .Right = 64
            End With

            ' Load item if not loaded, and reset timer
            ItemTimer(itempic) = GetTickCount + SurfaceTimerMax

            If DDS_Item(itempic) Is Nothing Then
                Call InitDDSurf("Items\" & itempic, DDSD_Item(itempic), DDS_Item(itempic))
            End If

            Engine_BltToDC DDS_Item(itempic), Rec, rec_pos, frmMain.picCharacter, False
            
            If (Player(MyIndex).Equipment(i).Value > 0 And Item(ItemNum).Stackable = 1) Then
                Amount = CStr(Player(MyIndex).Equipment(i).Value)
                x = rec_pos.Left - 4
                y = rec_pos.top + 22
                
                ' Draw currency but with k, m, b etc. using a convertion function
                If CLng(Amount) <= 1000000 Then
                    colour = QBColor(White)
                ElseIf CLng(Amount) > 1000000 And CLng(Amount) <= 10000000 Then
                    colour = QBColor(Yellow)
                ElseIf CLng(Amount) > 10000000 Then
                    colour = QBColor(BrightGreen)
                End If
                
                DrawText frmMain.picCharacter.hDC, x, y, ConvertCurrency(Amount), colour
            End If
        End If
    Next
    
    frmMain.picCharacter.Refresh

    ' Error handler
    Exit Sub
errorhandler:
    HandleError "BltEquipment", "modDirectDraw7", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
    Exit Sub
End Sub

Sub BltInventory()
Dim i As Long, x As Long, y As Long, ItemNum As Long, itempic As Long
Dim Amount As Long
Dim Rec As RECT, rec_pos As RECT
Dim colour As Long
Dim tmpItem As Long, amountModifier As Long

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo errorhandler

    If Not InGame Then Exit Sub
    
    ' reset gold label
    frmMain.lblGold.Caption = "0g"
    
    frmMain.picInventory.Cls

    For i = 1 To MAX_INV
        ItemNum = GetPlayerInvItemNum(MyIndex, i)

        If ItemNum > 0 And ItemNum <= MAX_ITEMS Then
            itempic = Item(ItemNum).Picture
            
            amountModifier = 0
            ' exit out if we're offering item in a trade.
            If InTrade > 0 Then
                For x = 1 To MAX_INV
                    tmpItem = GetPlayerInvItemNum(MyIndex, TradeYourOffer(x).num)
                    If TradeYourOffer(x).num = i Then
                        ' check if currency
                        If Not Item(tmpItem).Stackable = 1 Then
                            ' normal item, exit out
                            GoTo NextLoop
                        Else
                            ' if amount = all currency, remove from inventory
                            If TradeYourOffer(x).Value = GetPlayerInvItemValue(MyIndex, i) Then
                                GoTo NextLoop
                            Else
                                ' not all, change modifier to show change in currency count
                                amountModifier = TradeYourOffer(x).Value
                            End If
                        End If
                    End If
                Next
            End If

            If itempic > 0 And itempic <= NumItems Then
                If DDSD_Item(itempic).lWidth <= 64 Then ' more than 1 frame is handled by anim sub

                    With Rec
                        .top = 0
                        .Bottom = 32
                        .Left = 32
                        .Right = 64
                    End With

                    With rec_pos
                        .top = InvTop + ((InvOffsetY + 32) * ((i - 1) \ InvColumns))
                        .Bottom = .top + PIC_Y
                        .Left = InvLeft + ((InvOffsetX + 32) * (((i - 1) Mod InvColumns)))
                        .Right = .Left + PIC_X
                    End With

                    ' Load item if not loaded, and reset timer
                    ItemTimer(itempic) = GetTickCount + SurfaceTimerMax

                    If DDS_Item(itempic) Is Nothing Then
                        Call InitDDSurf("Items\" & itempic, DDSD_Item(itempic), DDS_Item(itempic))
                    End If

                    Engine_BltToDC DDS_Item(itempic), Rec, rec_pos, frmMain.picInventory, False

                    ' If item is a stack - draw the amount you have
                    If GetPlayerInvItemValue(MyIndex, i) > 1 Then
                        y = rec_pos.top + 22
                        x = rec_pos.Left - 4
                        
                        Amount = GetPlayerInvItemValue(MyIndex, i) - amountModifier
                        
                        ' Draw currency but with k, m, b etc. using a convertion function
                        If Amount < 1000000 Then
                            colour = QBColor(White)
                        ElseIf Amount > 1000000 And Amount < 10000000 Then
                            colour = QBColor(Yellow)
                        ElseIf Amount > 10000000 Then
                            colour = QBColor(BrightGreen)
                        End If
                        
                        DrawText frmMain.picInventory.hDC, x, y, Format$(ConvertCurrency(Str(Amount)), "#,###,###,###"), colour

                        ' Check if it's gold, and update the label
                        If GetPlayerInvItemNum(MyIndex, i) = 1 Then '1 = gold :P
                            frmMain.lblGold.Caption = Format$(Amount, "#,###,###,###") & "g"
                        End If
                    End If
                End If
            End If
        End If
NextLoop:
    Next
    
    frmMain.picInventory.Refresh
    'update animated items
    BltAnimatedInvItems
    
    ' Error handler
    Exit Sub
errorhandler:
    HandleError "BltInventory", "modDirectDraw7", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
    Exit Sub
End Sub

Sub BltTrade()
Dim i As Long, x As Long, y As Long, ItemNum As Long, itempic As Long
Dim Amount As Long
Dim Rec As RECT, rec_pos As RECT
Dim colour As Long

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo errorhandler

    If Not InGame Then Exit Sub
    frmMain.picYourTrade.Cls
    frmMain.picTheirTrade.Cls
    
    For i = 1 To MAX_INV
        ' blt your own offer
        ItemNum = GetPlayerInvItemNum(MyIndex, TradeYourOffer(i).num)

        If ItemNum > 0 And ItemNum <= MAX_ITEMS Then
            itempic = Item(ItemNum).Picture

            If itempic > 0 And itempic <= NumItems Then
                With Rec
                    .top = 0
                    .Bottom = 32
                    .Left = 32
                    .Right = 64
                End With

                With rec_pos
                    .top = InvTop - 24 + ((InvOffsetY + 32) * ((i - 1) \ InvColumns))
                    .Bottom = .top + PIC_Y
                    .Left = InvLeft + ((InvOffsetX + 32) * (((i - 1) Mod InvColumns)))
                    .Right = .Left + PIC_X
                End With

                ' Load item if not loaded, and reset timer
                ItemTimer(itempic) = GetTickCount + SurfaceTimerMax

                If DDS_Item(itempic) Is Nothing Then
                    Call InitDDSurf("Items\" & itempic, DDSD_Item(itempic), DDS_Item(itempic))
                End If

                Engine_BltToDC DDS_Item(itempic), Rec, rec_pos, frmMain.picYourTrade, False

                ' If item is a stack - draw the amount you have
                If TradeYourOffer(i).Value > 1 Then
                    y = rec_pos.top + 22
                    x = rec_pos.Left - 4
                    
                    Amount = TradeYourOffer(i).Value
                    
                    ' Draw currency but with k, m, b etc. using a convertion function
                    If Amount < 1000000 Then
                        colour = QBColor(White)
                    ElseIf Amount > 1000000 And Amount < 10000000 Then
                        colour = QBColor(Yellow)
                    ElseIf Amount > 10000000 Then
                        colour = QBColor(BrightGreen)
                    End If
                    
                    DrawText frmMain.picYourTrade.hDC, x, y, ConvertCurrency(Str(Amount)), colour
                End If
            End If
        End If
            
        ' blt their offer
        ItemNum = TradeTheirOffer(i).num

        If ItemNum > 0 And ItemNum <= MAX_ITEMS Then
            itempic = Item(ItemNum).Picture

            If itempic > 0 And itempic <= NumItems Then
                With Rec
                    .top = 0
                    .Bottom = 32
                    .Left = 32
                    .Right = 64
                End With

                With rec_pos
                    .top = InvTop - 24 + ((InvOffsetY + 32) * ((i - 1) \ InvColumns))
                    .Bottom = .top + PIC_Y
                    .Left = InvLeft + ((InvOffsetX + 32) * (((i - 1) Mod InvColumns)))
                    .Right = .Left + PIC_X
                End With

                ' Load item if not loaded, and reset timer
                ItemTimer(itempic) = GetTickCount + SurfaceTimerMax

                If DDS_Item(itempic) Is Nothing Then
                    Call InitDDSurf("Items\" & itempic, DDSD_Item(itempic), DDS_Item(itempic))
                End If

                Engine_BltToDC DDS_Item(itempic), Rec, rec_pos, frmMain.picTheirTrade, False

                ' If item is a stack - draw the amount you have
                If TradeTheirOffer(i).Value > 1 Then
                    y = rec_pos.top + 22
                    x = rec_pos.Left - 4
                    
                    Amount = TradeTheirOffer(i).Value
                    ' Draw currency but with k, m, b etc. using a convertion function
                    If Amount < 1000000 Then
                        colour = QBColor(White)
                    ElseIf Amount > 1000000 And Amount < 10000000 Then
                        colour = QBColor(Yellow)
                    ElseIf Amount > 10000000 Then
                        colour = QBColor(BrightGreen)
                    End If
                    
                    DrawText frmMain.picTheirTrade.hDC, x, y, ConvertCurrency(Str(Amount)), colour
                End If
            End If
        End If
    Next
    
    frmMain.picYourTrade.Refresh
    frmMain.picTheirTrade.Refresh
    
    ' Error handler
    Exit Sub
errorhandler:
    HandleError "BltTrade", "modDirectDraw7", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
    Exit Sub
End Sub

Sub BltPlayerSpells()
Dim i As Long, x As Long, y As Long, spellnum As Long, spellicon As Long
Dim Amount As String
Dim Rec As RECT, rec_pos As RECT
Dim colour As Long
Dim start As Long
Dim last As Long


    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo errorhandler

    If Not InGame Then Exit Sub
    frmMain.picSpells.Cls
    
    start = 1 + (SpellListColumn * 5)
    last = MAX_PLAYER_SPELLS - (15 - (SpellListColumn * 5))

    For i = start To last
        spellnum = PlayerSpells(i)

        If spellnum > 0 And spellnum <= MAX_SPELLS Then
            spellicon = Spell(spellnum).Icon

            If spellicon > 0 And spellicon <= NumSpellIcons Then
            
                With Rec
                    .top = 0
                    .Bottom = 32
                    .Left = 0
                    .Right = 32
                End With
                
                If Not SpellCD(i) = 0 Then
                    Rec.Left = 32
                    Rec.Right = 64
                End If

                With rec_pos
                    .top = SpellTop + ((SpellOffsetY + 32) * ((i - 1) \ SpellColumns)) - (SpellListColumn * 32)
                    .Bottom = .top + PIC_Y
                    .Left = SpellLeft + ((SpellOffsetX + 32) * (((i - 1) Mod SpellColumns)))
                    .Right = .Left + PIC_X
                End With

                ' Load spellicon if not loaded, and reset timer
                SpellIconTimer(spellicon) = GetTickCount + SurfaceTimerMax

                If DDS_SpellIcon(spellicon) Is Nothing Then
                    Call InitDDSurf("SpellIcons\" & spellicon, DDSD_SpellIcon(spellicon), DDS_SpellIcon(spellicon))
                End If

                Engine_BltToDC DDS_SpellIcon(spellicon), Rec, rec_pos, frmMain.picSpells, False
            End If
        End If
    Next
    
    ' Error handler
    Exit Sub
errorhandler:
    HandleError "BltPlayerSpells", "modDirectDraw7", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
    Exit Sub
End Sub

Sub BltPlayerSkills()
Dim i As Long, x As Long, y As Long, spellnum As Long, spellicon As Long
Dim Amount As String
Dim Rec As RECT, rec_pos As RECT
Dim colour As Long

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo errorhandler

    If Not InGame Then Exit Sub
    frmMain.picSkills.Cls
    
    For i = 1 To Skills.Skill_Count - 1
        With Player(MyIndex).Skill(i)
        
            x = i Mod 3
            If x = 0 Then x = 3
            x = x - 1
            x = 33 + 60 * x
            
            y = Fix(i / 3)
            If i Mod 3 = 0 Then
                y = y - 1
            End If
            y = 13 + 26 * y + y * 1.5
            
            If Len(Str(.Level)) - 1 = 1 And Len(Str(.MaxLevel)) - 1 = 1 Then
                DrawText frmMain.picSkills.hDC, x, y, .Level & " / " & .MaxLevel, QBColor(Yellow)
            ElseIf Len(Str(.Level)) - 1 > 1 And Len(Str(.MaxLevel)) - 1 = 1 Then
                DrawText frmMain.picSkills.hDC, x, y, .Level & "/ " & .MaxLevel, QBColor(Yellow)
            ElseIf Len(Str(.Level)) - 1 = 1 And Len(Str(.MaxLevel)) - 1 > 1 Then
                DrawText frmMain.picSkills.hDC, x, y, .Level & " /" & .MaxLevel, QBColor(Yellow)
            Else
                DrawText frmMain.picSkills.hDC, x, y, .Level & "/" & .MaxLevel, QBColor(Yellow)
            End If
            
            frmMain.picSkills.Refresh
        End With
    Next
    

    
    ' Error handler
    Exit Sub
errorhandler:
    HandleError "BltPlayerSpells", "modDirectDraw7", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
    Exit Sub
End Sub

Sub BltClan()
Dim i As Long

    If frmMain.picClan.Visible = False Then Exit Sub

    With frmMain.lstClanMembers
        .Clear
        For i = 1 To MAX_PLAYERS
            If Clan.Member(i).playerIndex > 0 Then
                .AddItem Trim$(Clan.Member(i).Rank) & "  " & Trim$(Player(Clan.Member(i).playerIndex).Name)
            End If
        Next
    End With

End Sub

Sub BltCombat()
Dim i As Long
Dim x As Long
Dim amt As Long
Dim amt2 As Long

    If Player(MyIndex).Equipment(Equipment.weapon).num > 0 Then
        i = Player(MyIndex).Equipment(Equipment.weapon).num
        
        Select Case i
            Case 1
                x = 1
            Case Else
                x = 0
        End Select
    End If
    
    If x > 0 Then
        frmMain.imgSpec.Visible = True
        frmMain.imgSpec_Void.Visible = True
        frmMain.lblSpec.Visible = True
        
        frmMain.imgSpec.width = Player(MyIndex).SpecialAttack
        frmMain.lblSpec.Caption = "Special Attack: " & Player(MyIndex).SpecialAttack & "%"
    Else
        frmMain.imgSpec.Visible = False
        frmMain.imgSpec_Void.Visible = False
        frmMain.lblSpec.Visible = False
    End If

    With Player(MyIndex)
        For i = 1 To Skills.Skill_Count - 1
            If i = Skills.Attack Or i = Skills.Strength Or i = Skills.Defense Or i = Skills.Range Or i = Skills.Magic Or i = Skills.Prayer Or i = Skills.Summoning Then
                For x = 1 To Equipment.Equipment_Count - 1
                    If .Equipment(x).num > 0 Then
                        amt = amt + Item(.Equipment(x).num).SkillBonus(i)
                    End If
                Next
                frmMain.lblSkill(i).Caption = GetSkillName(i) & ": " & amt
            End If
        Next
        
        amt = 0
        
        For i = 1 To CombatStyles.Count - 1
            For x = 1 To Equipment.Equipment_Count - 1
                If .Equipment(x).num > 0 Then
                    amt = amt + Item(.Equipment(x).num).Offense(i)
                    amt2 = amt2 + Item(.Equipment(x).num).Defense(i)
                End If
            Next
            frmMain.lblOffense(i).Caption = GetCombatName(i) & ": " & amt
            frmMain.lblDefense(i).Caption = GetCombatName(i) & ": " & amt2
        Next
    End With

End Sub

Sub BltPicShopItem(ByVal ItemNum As Long)
Dim Rec As RECT, pos As RECT

    frmMain.picShopItem.Cls
    
    If ItemNum > 0 And ItemNum < MAX_ITEMS Then
        If Item(ItemNum).Picture > 0 And Item(ItemNum).Picture < NumItems Then
            
            With Rec
                .top = 0
                .Bottom = 32
                .Left = 32
                .Right = 64
            End With
            
            With pos
                .top = 32
                .Bottom = .top + 32
                .Left = 85
                .Right = .Left + 32
            End With
            
            ' Load item if not loaded, and reset timer
            ItemTimer(Item(ItemNum).Picture) = GetTickCount + SurfaceTimerMax
            
            If DDS_Item(Item(ItemNum).Picture) Is Nothing Then
                Call InitDDSurf("Items\" & Item(ItemNum).Picture, DDSD_Item(Item(ItemNum).Picture), DDS_Item(Item(ItemNum).Picture))
            End If
            
            Engine_BltToDC DDS_Item(Item(ItemNum).Picture), Rec, pos, frmMain.picShopItem, False
        End If
    End If
    

End Sub

Sub BltShop()
Dim i As Long, x As Long, y As Long, ItemNum As Long, itempic As Long
Dim Amount As String
Dim Rec As RECT, rec_pos As RECT
Dim colour As Long

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo errorhandler

    If Not InGame Then Exit Sub
    
    frmMain.picShopItems.Cls

    For i = 1 To MAX_TRADES
        ItemNum = Shop(InShop).TradeItem(i).Item 'GetPlayerInvItemNum(MyIndex, i)
        If ItemNum > 0 And ItemNum <= MAX_ITEMS Then
            itempic = Item(ItemNum).Picture
            If itempic > 0 And itempic <= NumItems Then
            
                With Rec
                    .top = 0
                    .Bottom = 32
                    .Left = 32
                    .Right = 64
                End With
                
                With rec_pos
                    .top = ShopTop + ((ShopOffsetY + 32) * ((i - 1) \ ShopColumns))
                    .Bottom = .top + PIC_Y
                    .Left = ShopLeft + ((ShopOffsetX + 32) * (((i - 1) Mod ShopColumns)))
                    .Right = .Left + PIC_X
                End With
                
                ' Load item if not loaded, and reset timer
                ItemTimer(itempic) = GetTickCount + SurfaceTimerMax
                
                If DDS_Item(itempic) Is Nothing Then
                    Call InitDDSurf("Items\" & itempic, DDSD_Item(itempic), DDS_Item(itempic))
                End If
                
                Engine_BltToDC DDS_Item(itempic), Rec, rec_pos, frmMain.picShopItems, False
                
                ' If item is a stack - draw the amount you have
                If Shop(InShop).TradeItem(i).MaxStock <> -255 Then
                    y = rec_pos.top + 22
                    x = rec_pos.Left - 4
                    Amount = CStr(Shop(InShop).TradeItem(i).Stock)
                    
                    ' Draw currency but with k, m, b etc. using a convertion function
                    If CLng(Amount) < 1000000 Then
                        colour = QBColor(White)
                    ElseIf CLng(Amount) > 1000000 And CLng(Amount) < 10000000 Then
                        colour = QBColor(Yellow)
                    ElseIf CLng(Amount) > 10000000 Then
                        colour = QBColor(BrightGreen)
                    End If
                    
                    If Amount = 0 Then
                        DrawText frmMain.picShopItems.hDC, x, y, "0", colour
                    Else
                        DrawText frmMain.picShopItems.hDC, x, y, ConvertCurrency(Amount), colour
                    End If
                End If
            End If
        End If
    Next
    
    frmMain.picShopItems.Refresh
    
    ' Error handler
    Exit Sub
errorhandler:
    HandleError "BltShop", "modDirectDraw7", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
    Exit Sub
End Sub

Public Sub BltInventoryItem(ByVal x As Long, ByVal y As Long)
Dim Rec As RECT, rec_pos As RECT
Dim ItemNum As Long, itempic As Long

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo errorhandler

    ItemNum = GetPlayerInvItemNum(MyIndex, DragInvSlotNum)

    If ItemNum > 0 And ItemNum <= MAX_ITEMS Then
        itempic = Item(ItemNum).Picture
        
        If itempic = 0 Then Exit Sub

        With Rec
            .top = 0
            .Bottom = .top + PIC_Y
            .Left = DDSD_Item(itempic).lWidth / 2
            .Right = .Left + PIC_X
        End With

        With rec_pos
            .top = 2
            .Bottom = .top + PIC_Y
            .Left = 2
            .Right = .Left + PIC_X
        End With

        ' Load item if not loaded, and reset timer
        ItemTimer(itempic) = GetTickCount + SurfaceTimerMax

        If DDS_Item(itempic) Is Nothing Then
            Call InitDDSurf("Items\" & itempic, DDSD_Item(itempic), DDS_Item(itempic))
        End If

        Engine_BltToDC DDS_Item(itempic), Rec, rec_pos, frmMain.picTempInv, False

        With frmMain.picTempInv
            .top = y
            .Left = x
            .Visible = True
            .ZOrder (0)
        End With
    End If

    ' Error handler
    Exit Sub
errorhandler:
    HandleError "BltInventoryItem", "modDirectDraw7", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
    Exit Sub
End Sub

Public Sub BltDraggedSpell(ByVal x As Long, ByVal y As Long)
Dim Rec As RECT, rec_pos As RECT
Dim spellnum As Long, spellpic As Long

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo errorhandler

    spellnum = PlayerSpells(DragSpell)

    If spellnum > 0 And spellnum <= MAX_SPELLS Then
        spellpic = Spell(spellnum).Icon
        
        If spellpic = 0 Then Exit Sub

        With Rec
            .top = 0
            .Bottom = .top + PIC_Y
            .Left = 0
            .Right = .Left + PIC_X
        End With

        With rec_pos
            .top = 2
            .Bottom = .top + PIC_Y
            .Left = 2
            .Right = .Left + PIC_X
        End With

        ' Load item if not loaded, and reset timer
        SpellIconTimer(spellpic) = GetTickCount + SurfaceTimerMax

        If DDS_SpellIcon(spellpic) Is Nothing Then
            Call InitDDSurf("Spellicons\" & spellpic, DDSD_SpellIcon(spellpic), DDS_SpellIcon(spellpic))
        End If

        Engine_BltToDC DDS_SpellIcon(spellpic), Rec, rec_pos, frmMain.picTempSpell, False

        With frmMain.picTempSpell
            .top = y
            .Left = x
            .Visible = True
            .ZOrder (0)
        End With
    End If
    
    ' Error handler
    Exit Sub
errorhandler:
    HandleError "BltInventoryItem", "modDirectDraw7", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
    Exit Sub
End Sub

Public Sub BltItemDesc(ByVal ItemNum As Long)
Dim Rec As RECT, rec_pos As RECT
Dim itempic As Long

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo errorhandler
    
    frmMain.picItemDescPic.Cls
    
    If ItemNum > 0 And ItemNum <= MAX_ITEMS Then
        itempic = Item(ItemNum).Picture

        If itempic = 0 Then Exit Sub
        
        ' Load item if not loaded, and reset timer
        ItemTimer(itempic) = GetTickCount + SurfaceTimerMax

        If DDS_Item(itempic) Is Nothing Then
            Call InitDDSurf("Items\" & itempic, DDSD_Item(itempic), DDS_Item(itempic))
        End If

        With Rec
            .top = 0
            .Bottom = .top + PIC_Y
            .Left = DDSD_Item(itempic).lWidth / 2
            .Right = .Left + PIC_X
        End With

        With rec_pos
            .top = 0
            .Bottom = 64
            .Left = 0
            .Right = 64
        End With
        Engine_BltToDC DDS_Item(itempic), Rec, rec_pos, frmMain.picItemDescPic, False
    End If

    ' Error handler
    Exit Sub
errorhandler:
    HandleError "BltItemDesc", "modDirectDraw7", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
    Exit Sub
End Sub

Public Sub BltSpellDesc(ByVal spellnum As Long)
Dim Rec As RECT, rec_pos As RECT
Dim spellpic As Long

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo errorhandler
    
    frmMain.picSpellDescPic.Cls

    If spellnum > 0 And spellnum <= MAX_SPELLS Then
        spellpic = Spell(spellnum).Icon

        If spellpic <= 0 Or spellpic > NumSpellIcons Then Exit Sub
        
        ' Load item if not loaded, and reset timer
        SpellIconTimer(spellpic) = GetTickCount + SurfaceTimerMax

        If DDS_SpellIcon(spellpic) Is Nothing Then
            Call InitDDSurf("SpellIcons\" & spellpic, DDSD_SpellIcon(spellpic), DDS_SpellIcon(spellpic))
        End If

        With Rec
            .top = 0
            .Bottom = .top + PIC_Y
            .Left = 0
            .Right = .Left + PIC_X
        End With

        With rec_pos
            .top = 0
            .Bottom = 64
            .Left = 0
            .Right = 64
        End With
        Engine_BltToDC DDS_SpellIcon(spellpic), Rec, rec_pos, frmMain.picSpellDescPic, False
    End If

    ' Error handler
    Exit Sub
errorhandler:
    HandleError "BltSpellDesc", "modDirectDraw7", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
    Exit Sub
End Sub

' ******************
' ** Game Editors **
' ******************
Public Sub EditorMap_BltTileset()
Dim height As Long
Dim width As Long
Dim Tileset As Long
Dim sRECT As DxVBLib.RECT
Dim dRECT As DxVBLib.RECT
    
    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo errorhandler

    ' find tileset number
    Tileset = frmEditor_Map.scrlTileSet.Value
    
    ' exit out if doesn't exist
    If Tileset < 0 Or Tileset > NumTileSets Then Exit Sub
    
    ' make sure it's loaded
    If DDS_Tileset(Tileset) Is Nothing Then
        Call InitDDSurf("tilesets\" & Tileset, DDSD_Tileset(Tileset), DDS_Tileset(Tileset))
    End If
    
    height = DDSD_Tileset(Tileset).lHeight
    width = DDSD_Tileset(Tileset).lWidth
    
    dRECT.top = 0
    dRECT.Bottom = height
    dRECT.Left = 0
    dRECT.Right = width
    
    frmEditor_Map.picBackSelect.height = height
    frmEditor_Map.picBackSelect.width = width
    
    Call Engine_BltToDC(DDS_Tileset(Tileset), sRECT, dRECT, frmEditor_Map.picBackSelect)
    
    ' Error handler
    Exit Sub
errorhandler:
    HandleError "EditorMap_BltTileset", "modDirectDraw7", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
    Exit Sub
End Sub

Public Sub BltTileOutline()
Dim Rec As DxVBLib.RECT
    
    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo errorhandler

    If frmEditor_Map.optBlock.Value Then Exit Sub

    With Rec
        .top = 0
        .Bottom = .top + PIC_Y
        .Left = 0
        .Right = .Left + PIC_X
    End With

    Call Engine_BltFast(ConvertMapX(CurX * PIC_X), ConvertMapY(CurY * PIC_Y), DDS_Misc, Rec, DDBLTFAST_WAIT Or DDBLTFAST_SRCCOLORKEY)
    
    ' Error handler
    Exit Sub
errorhandler:
    HandleError "BltTileOutline", "modDirectDraw7", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
    Exit Sub
End Sub

Public Sub NewCharacterBltSprite()
Dim Sprite As Long
Dim sRECT As DxVBLib.RECT
Dim dRECT As DxVBLib.RECT
Dim width As Long, height As Long
    
    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo errorhandler
    
    If frmMenu.optMale.Value = True Then
        Sprite = 1
    Else
        Sprite = 2
    End If
    
    If Sprite < 1 Or Sprite > NumCharacters Then
        frmMenu.picSprite.Cls
        Exit Sub
    End If
    
    CharacterTimer(Sprite) = GetTickCount + SurfaceTimerMax

    If DDS_Character(Sprite) Is Nothing Then
        Call InitDDSurf("Characters\" & Sprite, DDSD_Character(Sprite), DDS_Character(Sprite))
    End If
    
    width = DDSD_Character(Sprite).lWidth / 4
    height = DDSD_Character(Sprite).lHeight / 4
    
    frmMenu.picSprite.width = width
    frmMenu.picSprite.height = height
    
    sRECT.top = 0
    sRECT.Bottom = sRECT.top + height
    sRECT.Left = 0
    sRECT.Right = sRECT.Left + width
    
    dRECT.top = 0
    dRECT.Bottom = height
    dRECT.Left = 0
    dRECT.Right = width
    
    Call Engine_BltToDC(DDS_Character(Sprite), sRECT, dRECT, frmMenu.picSprite)
    
    ' Error handler
    Exit Sub
errorhandler:
    HandleError "NewCharacterBltSprite", "modDirectDraw7", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
    Exit Sub
End Sub

Public Sub EditorMap_BltMapItem()
Dim ItemNum As Long
Dim sRECT As DxVBLib.RECT
Dim dRECT As DxVBLib.RECT
    
    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo errorhandler

    ItemNum = Item(frmEditor_Map.scrlMapItem.Value).Picture

    If ItemNum < 1 Or ItemNum > NumItems Then
        frmEditor_Map.picMapItem.Cls
        Exit Sub
    End If

    ItemTimer(ItemNum) = GetTickCount + SurfaceTimerMax

    If DDS_Item(ItemNum) Is Nothing Then
        Call InitDDSurf("Items\" & ItemNum, DDSD_Item(ItemNum), DDS_Item(ItemNum))
    End If

    sRECT.top = 0
    sRECT.Bottom = PIC_Y
    sRECT.Left = 0
    sRECT.Right = PIC_X
    dRECT.top = 0
    dRECT.Bottom = PIC_Y
    dRECT.Left = 0
    dRECT.Right = PIC_X
    Call Engine_BltToDC(DDS_Item(ItemNum), sRECT, dRECT, frmEditor_Map.picMapItem)
    
    ' Error handler
    Exit Sub
errorhandler:
    HandleError "EditorMap_BltMapItem", "modDirectDraw7", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
    Exit Sub
End Sub

Public Sub EditorMap_BltKey()
Dim ItemNum As Long
Dim sRECT As DxVBLib.RECT
Dim dRECT As DxVBLib.RECT

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo errorhandler

    ItemNum = Item(frmEditor_Map.scrlMapKey.Value).Picture

    If ItemNum < 1 Or ItemNum > NumItems Then
        frmEditor_Map.picMapKey.Cls
        Exit Sub
    End If

    ItemTimer(ItemNum) = GetTickCount + SurfaceTimerMax

    If DDS_Item(ItemNum) Is Nothing Then
        Call InitDDSurf("Items\" & ItemNum, DDSD_Item(ItemNum), DDS_Item(ItemNum))
    End If

    sRECT.top = 0
    sRECT.Bottom = PIC_Y
    sRECT.Left = 0
    sRECT.Right = PIC_X
    dRECT.top = 0
    dRECT.Bottom = PIC_Y
    dRECT.Left = 0
    dRECT.Right = PIC_X
    Call Engine_BltToDC(DDS_Item(ItemNum), sRECT, dRECT, frmEditor_Map.picMapKey)
    
    ' Error handler
    Exit Sub
errorhandler:
    HandleError "EditorMap_BltKey", "modDirectDraw7", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
    Exit Sub
End Sub

Public Sub EditorItem_BltItem()
Dim ItemNum As Long
Dim sRECT As DxVBLib.RECT
Dim dRECT As DxVBLib.RECT
    
    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo errorhandler

    ItemNum = frmEditor_Item.scrlPic.Value

    If ItemNum < 1 Or ItemNum > NumItems Then
        frmEditor_Item.picItem.Cls
        Exit Sub
    End If

    ItemTimer(ItemNum) = GetTickCount + SurfaceTimerMax

    If DDS_Item(ItemNum) Is Nothing Then
        Call InitDDSurf("Items\" & ItemNum, DDSD_Item(ItemNum), DDS_Item(ItemNum))
    End If

    ' rect for source
    sRECT.top = 0
    sRECT.Bottom = PIC_Y
    sRECT.Left = 0
    sRECT.Right = PIC_X
    
    ' same for destination as source
    dRECT = sRECT
    Call Engine_BltToDC(DDS_Item(ItemNum), sRECT, dRECT, frmEditor_Item.picItem)
    
    ' Error handler
    Exit Sub
errorhandler:
    HandleError "EditorItem_BltItem", "modDirectDraw7", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
    Exit Sub
End Sub

Public Sub EditorSpell_BltIcon()
Dim iconnum As Long
Dim sRECT As DxVBLib.RECT
Dim dRECT As DxVBLib.RECT

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo errorhandler

    iconnum = frmEditor_Spell.scrlIcon.Value
    
    If iconnum < 1 Or iconnum > NumSpellIcons Then
        frmEditor_Spell.picSprite.Cls
        Exit Sub
    End If
    
    SpellIconTimer(iconnum) = GetTickCount + SurfaceTimerMax
    
    If DDS_SpellIcon(iconnum) Is Nothing Then
        Call InitDDSurf("SpellIcons\" & iconnum, DDSD_SpellIcon(iconnum), DDS_SpellIcon(iconnum))
    End If
    
    sRECT.top = 0
    sRECT.Bottom = PIC_Y
    sRECT.Left = 0
    sRECT.Right = PIC_X
    dRECT.top = 0
    dRECT.Bottom = PIC_Y
    dRECT.Left = 0
    dRECT.Right = PIC_X
    
    Call Engine_BltToDC(DDS_SpellIcon(iconnum), sRECT, dRECT, frmEditor_Spell.picSprite)
    
    ' Error handler
    Exit Sub
errorhandler:
    HandleError "EditorSpell_BltIcon", "modDirectDraw7", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
    Exit Sub
End Sub

Public Sub EditorAnim_BltAnim()
Dim Animationnum As Long
Dim sRECT As DxVBLib.RECT
Dim dRECT As DxVBLib.RECT
Dim i As Long
Dim width As Long, height As Long
Dim looptime As Long
Dim FrameCount As Long
Dim ShouldRender As Boolean
    
    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo errorhandler

    For i = 0 To 1
        Animationnum = frmEditor_Animation.scrlSprite(i).Value
        
        If Animationnum < 1 Or Animationnum > NumAnimations Then
            frmEditor_Animation.picSprite(i).Cls
        Else
            looptime = frmEditor_Animation.scrlLoopTime(i)
            FrameCount = frmEditor_Animation.scrlFrameCount(i)
            
            ShouldRender = False
            
            ' check if we need to render new frame
            If AnimEditorTimer(i) + looptime <= GetTickCount Then
                ' check if out of range
                If AnimEditorFrame(i) >= FrameCount Then
                    AnimEditorFrame(i) = 1
                Else
                    AnimEditorFrame(i) = AnimEditorFrame(i) + 1
                End If
                AnimEditorTimer(i) = GetTickCount
                ShouldRender = True
            End If
        
            If ShouldRender Then
                frmEditor_Animation.picSprite(i).Cls
            
                AnimationTimer(Animationnum) = GetTickCount + SurfaceTimerMax
                
                If DDS_Animation(Animationnum) Is Nothing Then
                    Call InitDDSurf("animations\" & Animationnum, DDSD_Animation(Animationnum), DDS_Animation(Animationnum))
                End If
                
                If frmEditor_Animation.scrlFrameCount(i).Value > 0 Then
                    ' total width divided by frame count
                    width = DDSD_Animation(Animationnum).lWidth / frmEditor_Animation.scrlFrameCount(i).Value
                    height = DDSD_Animation(Animationnum).lHeight
                    
                    sRECT.top = 0
                    sRECT.Bottom = height
                    sRECT.Left = (AnimEditorFrame(i) - 1) * width
                    sRECT.Right = sRECT.Left + width
                    
                    dRECT.top = 0
                    dRECT.Bottom = height
                    dRECT.Left = 0
                    dRECT.Right = width
                    
                    Call Engine_BltToDC(DDS_Animation(Animationnum), sRECT, dRECT, frmEditor_Animation.picSprite(i))
                End If
            End If
        End If
    Next
    
    ' Error handler
    Exit Sub
errorhandler:
    HandleError "EditorAnim_BltAnim", "modDirectDraw7", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
    Exit Sub
End Sub

Public Sub EditorResource_BltSprite()
Dim Sprite As Long
Dim sRECT As DxVBLib.RECT
Dim dRECT As DxVBLib.RECT
    
    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo errorhandler

    ' normal sprite
    Sprite = frmEditor_Resource.scrlNormalPic.Value

    If Sprite < 1 Or Sprite > NumResources Then
        frmEditor_Resource.picNormalPic.Cls
    Else
        ResourceTimer(Sprite) = GetTickCount + SurfaceTimerMax
        If DDS_Resource(Sprite) Is Nothing Then
            Call InitDDSurf("Resources\" & Sprite, DDSD_Resource(Sprite), DDS_Resource(Sprite))
        End If
        sRECT.top = 0
        sRECT.Bottom = DDSD_Resource(Sprite).lHeight
        sRECT.Left = 0
        sRECT.Right = DDSD_Resource(Sprite).lWidth
        dRECT.top = 0
        dRECT.Bottom = DDSD_Resource(Sprite).lHeight
        dRECT.Left = 0
        dRECT.Right = DDSD_Resource(Sprite).lWidth
        Call Engine_BltToDC(DDS_Resource(Sprite), sRECT, dRECT, frmEditor_Resource.picNormalPic)
    End If

    ' exhausted sprite
    Sprite = frmEditor_Resource.scrlExhaustedPic.Value

    If Sprite < 1 Or Sprite > NumResources Then
        frmEditor_Resource.picExhaustedPic.Cls
    Else
        ResourceTimer(Sprite) = GetTickCount + SurfaceTimerMax
        If DDS_Resource(Sprite) Is Nothing Then
            Call InitDDSurf("Resources\" & Sprite, DDSD_Resource(Sprite), DDS_Resource(Sprite))
        End If
        sRECT.top = 0
        sRECT.Bottom = DDSD_Resource(Sprite).lHeight
        sRECT.Left = 0
        sRECT.Right = DDSD_Resource(Sprite).lWidth
        dRECT.top = 0
        dRECT.Bottom = DDSD_Resource(Sprite).lHeight
        dRECT.Left = 0
        dRECT.Right = DDSD_Resource(Sprite).lWidth
        Call Engine_BltToDC(DDS_Resource(Sprite), sRECT, dRECT, frmEditor_Resource.picExhaustedPic)
    End If
    
    ' Error handler
    Exit Sub
errorhandler:
    HandleError "EditorResource_BltSprite", "modDirectDraw7", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
    Exit Sub
End Sub

Public Sub Render_Graphics()
Dim x As Long
Dim y As Long
Dim i As Long
Dim Rec As DxVBLib.RECT
Dim rec_pos As DxVBLib.RECT
    
    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo errorhandler
    
    ' check if automation is screwed
    If Not CheckSurfaces Then
        ' exit out and let them know we need to re-init
        ReInitSurfaces = True
        Exit Sub
    Else
        ' if we need to fix the surfaces then do so
        If ReInitSurfaces Then
            ReInitSurfaces = False
            ReInitDD
        End If
    End If
    
    ' don't render
    If frmMain.WindowState = vbMinimized Then Exit Sub
    If GettingMap Then Exit Sub
    
    ' update the viewpoint
    UpdateCamera
    
    ' update animation editor
    If Editor = EDITOR_ANIMATION Then
        EditorAnim_BltAnim
    End If
    
    ' fill it with black
    DDS_BackBuffer.BltColorFill rec_pos, 0
    
    ' blit lower tiles
    If NumTileSets > 0 Then
        For x = TileView.Left To TileView.Right
            For y = TileView.top To TileView.Bottom
                If IsValidMapPoint(x, y) Then
                    Call BltMapTile(x, y)
                End If
            Next
        Next
    End If

    ' render the decals
    For i = 1 To MAX_BYTE
        Call BltBlood(i)
    Next

    ' Blit out the items
    If NumItems > 0 Then
        For i = 1 To MAX_MAP_ITEMS
            If MapItem(i).num > 0 Then
                Call BltItem(i)
            End If
        Next
    End If
    
    ' draw animations
    If NumAnimations > 0 Then
        For i = 1 To MAX_BYTE
            If AnimInstance(i).Used(0) Then
                BltAnimation i, 0
            End If
        Next
    End If
    
    ' projec tile
    ' blt projec tiles for each player
    For i = 1 To MAX_PROJECTILES
        BltProjectile i
    Next

    ' Y-based render. Renders Players, Npcs and Resources based on Y-axis.
    For y = 0 To Map.MaxY
        If NumCharacters > 0 Then
            ' Players
            For i = 1 To Player_HighIndex
                If IsPlaying(i) And GetPlayerMap(i) = GetPlayerMap(MyIndex) Then
                    If Player(i).y = y Then
                        Call BltPlayer(i)
                    End If
                End If
            Next
        
            ' Npcs
            For i = 1 To Npc_HighIndex
                If MapNpc(i).y = y Then
                    Call BltNpc(i)
                End If
            Next
        End If
        
        ' Resources
        If NumResources > 0 Then
            If Resources_Init Then
                If Resource_Index > 0 Then
                    For i = 1 To Resource_Index
                        If MapResource(i).y = y Then
                            Call BltMapResource(i)
                        End If
                    Next
                End If
            End If
        End If
    Next
    
    ' animations
    If NumAnimations > 0 Then
        For i = 1 To MAX_BYTE
            If AnimInstance(i).Used(1) Then
                BltAnimation i, 1
            End If
        Next
    End If

    ' blit out upper tiles
    If NumTileSets > 0 Then
        For x = TileView.Left To TileView.Right
            For y = TileView.top To TileView.Bottom
                If IsValidMapPoint(x, y) Then
                    Call BltMapFringeTile(x, y)
                End If
            Next
        Next
    End If
    
    ' blit out a square at mouse cursor
    If InMapEditor Then
        If frmEditor_Map.optBlock.Value = True Then
            For x = TileView.Left To TileView.Right
                For y = TileView.top To TileView.Bottom
                    If IsValidMapPoint(x, y) Then
                        Call BltDirection(x, y)
                    End If
                Next
            Next
        End If
        Call BltTileOutline
    End If
    
    ' Render the bars
    BltBars
    
    ' Blt the target icon
    If myTarget > 0 Then
        If myTargetType = TARGET_TYPE_PLAYER Then
            BltTarget (Player(myTarget).x * 32) + Player(myTarget).XOffset, (Player(myTarget).y * 32) + Player(myTarget).YOffset
        ElseIf myTargetType = TARGET_TYPE_NPC Then
            BltTarget (MapNpc(myTarget).x * 32) + MapNpc(myTarget).XOffset, (MapNpc(myTarget).y * 32) + MapNpc(myTarget).YOffset
        End If
    End If
    
    ' blt the hover icon
    For i = 1 To Player_HighIndex
        If IsPlaying(i) Then
            If Player(i).Map = Player(MyIndex).Map Then
                If CurX = Player(i).x And CurY = Player(i).y Then
                    If myTargetType = TARGET_TYPE_PLAYER And myTarget = i Then
                        ' dont render lol
                    Else
                        BltHover TARGET_TYPE_PLAYER, i, (Player(i).x * 32) + Player(i).XOffset, (Player(i).y * 32) + Player(i).YOffset
                    End If
                End If
            End If
        End If
    Next
    For i = 1 To Npc_HighIndex
        If MapNpc(i).num > 0 Then
            If CurX = MapNpc(i).x And CurY = MapNpc(i).y Then
                If myTargetType = TARGET_TYPE_NPC And myTarget = i Then
                    ' dont render lol
                Else
                    BltHover TARGET_TYPE_NPC, i, (MapNpc(i).x * 32) + MapNpc(i).XOffset, (MapNpc(i).y * 32) + MapNpc(i).YOffset
                End If
            End If
        End If
    Next

    ' Lock the backbuffer so we can draw text and names
    TexthDC = DDS_BackBuffer.GetDC

    ' draw FPS
    If BFPS Then
        Call DrawText(TexthDC, Camera.Right - (Len("FPS: " & GameFPS) * 8), Camera.top + 1, Trim$("FPS: " & GameFPS), QBColor(Yellow))
    End If

    ' draw cursor, player X and Y locations
    If BLoc Then
        Call DrawText(TexthDC, Camera.Left, Camera.top + 1, Trim$("cur x: " & CurX & " y: " & CurY), QBColor(Yellow))
        Call DrawText(TexthDC, Camera.Left, Camera.top + 15, Trim$("loc x: " & GetPlayerX(MyIndex) & " y: " & GetPlayerY(MyIndex)), QBColor(Yellow))
        Call DrawText(TexthDC, Camera.Left, Camera.top + 27, Trim$(" (map #" & GetPlayerMap(MyIndex) & ")"), QBColor(Yellow))
    End If

    ' draw player names
    For i = 1 To Player_HighIndex
        If IsPlaying(i) And GetPlayerMap(i) = GetPlayerMap(MyIndex) Then
            Call DrawPlayerName(i)
        End If
    Next
    
    ' draw npc names
    For i = 1 To Npc_HighIndex
        If MapNpc(i).num > 0 Then
            Call DrawNpcName(i)
        End If
    Next
    
    For i = 1 To Action_HighIndex
        Call BltActionMsg(i)
    Next i

    ' Blit out map attributes
    If InMapEditor Then
        Call BltMapAttributes
    End If
    
    If SpellSlotNum > 0 Then
        Call DrawText(TexthDC, 33, 33, "Use spell on...", QBColor(Yellow))
    End If

    ' Draw map name
    Call DrawText(TexthDC, DrawMapNameX, DrawMapNameY, Map.Name, DrawMapNameColor)

    ' Release DC
    DDS_BackBuffer.ReleaseDC TexthDC
    
    ' Get rec
    With Rec
        .top = Camera.top
        .Bottom = .top + ScreenY
        .Left = Camera.Left
        .Right = .Left + ScreenX
    End With
    
    ' rec_pos
    With rec_pos
        .Bottom = ((MAX_MAPY + 1) * PIC_Y)
        .Right = ((MAX_MAPX + 1) * PIC_X)
    End With
    
    ' Flip and render
    DX7.GetWindowRect frmMain.picScreen.hWnd, rec_pos
    DDS_Primary.Blt rec_pos, DDS_BackBuffer, Rec, DDBLT_WAIT
    
    ' Error handler
    Exit Sub
    
errorhandler:
    HandleError "Render_Graphics", "modDirectDraw7", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
    Exit Sub
End Sub

Public Sub UpdateCamera()
Dim offsetX As Long
Dim offsetY As Long
Dim StartX As Long
Dim StartY As Long
Dim EndX As Long
Dim EndY As Long

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo errorhandler

    offsetX = Player(MyIndex).XOffset + PIC_X
    offsetY = Player(MyIndex).YOffset + PIC_Y

    StartX = GetPlayerX(MyIndex) - StartXValue
    StartY = GetPlayerY(MyIndex) - StartYValue
    If StartX < 0 Then
        offsetX = 0
        If StartX = -1 Then
            If Player(MyIndex).XOffset > 0 Then
                offsetX = Player(MyIndex).XOffset
            End If
        End If
        StartX = 0
    End If
    If StartY < 0 Then
        offsetY = 0
        If StartY = -1 Then
            If Player(MyIndex).YOffset > 0 Then
                offsetY = Player(MyIndex).YOffset
            End If
        End If
        StartY = 0
    End If
    
    EndX = StartX + EndXValue
    EndY = StartY + EndYValue
    If EndX > Map.MaxX Then
        offsetX = 32
        If EndX = Map.MaxX + 1 Then
            If Player(MyIndex).XOffset < 0 Then
                offsetX = Player(MyIndex).XOffset + PIC_X
            End If
        End If
        EndX = Map.MaxX
        StartX = EndX - MAX_MAPX - 1
    End If
    If EndY > Map.MaxY Then
        offsetY = 32
        If EndY = Map.MaxY + 1 Then
            If Player(MyIndex).YOffset < 0 Then
                offsetY = Player(MyIndex).YOffset + PIC_Y
            End If
        End If
        EndY = Map.MaxY
        StartY = EndY - MAX_MAPY - 1
    End If

    With TileView
        .top = StartY
        .Bottom = EndY
        .Left = StartX
        .Right = EndX
    End With

    With Camera
        .top = offsetY
        .Bottom = .top + ScreenY
        .Left = offsetX
        .Right = .Left + ScreenX
    End With
    
    UpdateDrawMapName

    ' Error handler
    Exit Sub
errorhandler:
    HandleError "UpdateCamera", "modDirectDraw7", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
    Exit Sub
End Sub

Public Function ConvertMapX(ByVal x As Long) As Long
    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo errorhandler

    ConvertMapX = x - (TileView.Left * PIC_X)
    
    ' Error handler
    Exit Function
errorhandler:
    HandleError "ConvertMapX", "modDirectDraw7", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
    Exit Function
End Function

Public Function ConvertMapY(ByVal y As Long) As Long
    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo errorhandler

    ConvertMapY = y - (TileView.top * PIC_Y)
    
    ' Error handler
    Exit Function
errorhandler:
    HandleError "ConvertMapY", "modDirectDraw7", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
    Exit Function
End Function

Public Function InViewPort(ByVal x As Long, ByVal y As Long) As Boolean
    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo errorhandler

    InViewPort = False

    If x < TileView.Left Then Exit Function
    If y < TileView.top Then Exit Function
    If x > TileView.Right Then Exit Function
    If y > TileView.Bottom Then Exit Function
    InViewPort = True
    
    ' Error handler
    Exit Function
errorhandler:
    HandleError "InViewPort", "modDirectDraw7", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
    Exit Function
End Function

Public Function IsValidMapPoint(ByVal x As Long, ByVal y As Long) As Boolean
    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo errorhandler

    IsValidMapPoint = False

    If x < 0 Then Exit Function
    If y < 0 Then Exit Function
    If x > Map.MaxX Then Exit Function
    If y > Map.MaxY Then Exit Function
    IsValidMapPoint = True
        
    ' Error handler
    Exit Function
errorhandler:
    HandleError "IsValidMapPoint", "modDirectDraw7", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
    Exit Function
End Function

Public Sub LoadTilesets()
Dim x As Long
Dim y As Long
Dim i As Long
Dim tilesetInUse() As Boolean
    
    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo errorhandler

    ReDim tilesetInUse(0 To NumTileSets)
    
    For x = 0 To Map.MaxX
        For y = 0 To Map.MaxY
            For i = 1 To MapLayer.Layer_Count - 1
                ' check exists
                If Map.Tile(x, y).Layer(i).Tileset > 0 And Map.Tile(x, y).Layer(i).Tileset <= NumTileSets Then
                    tilesetInUse(Map.Tile(x, y).Layer(i).Tileset) = True
                End If
            Next
        Next
    Next
    
    For i = 1 To NumTileSets
        If tilesetInUse(i) Then
            ' load tileset
            If DDS_Tileset(i) Is Nothing Then
                Call InitDDSurf("tilesets\" & i, DDSD_Tileset(i), DDS_Tileset(i))
            End If
        Else
            ' unload tileset
            Call ZeroMemory(ByVal VarPtr(DDSD_Tileset(i)), LenB(DDSD_Tileset(i)))
            Set DDS_Tileset(i) = Nothing
        End If
    Next
    
    ' Error handler
    Exit Sub
errorhandler:
    HandleError "LoadTilesets", "modDirectDraw7", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
    Exit Sub
End Sub

Sub BltBank()
Dim i As Long, x As Long, y As Long, ItemNum As Long
Dim Amount As String
Dim sRECT As RECT, dRECT As RECT
Dim Sprite As Long, colour As Long

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo errorhandler

    If frmMain.picBank.Visible = True Then
        frmMain.picBank.Cls
        
        For i = 1 To MAX_BANK_TABS
            If Bank.BankTab(i).Item(1).num > 0 Then
                ItemNum = Bank.BankTab(i).Item(1).num
                If ItemNum < MAX_ITEMS Then
                    Sprite = Item(ItemNum).Picture
                    
                    If Sprite <> 0 Then
                        
                        If DDS_Item(Sprite) Is Nothing Then
                            Call InitDDSurf("Items\" & Sprite, DDSD_Item(Sprite), DDS_Item(Sprite))
                        End If
                        
                        With sRECT
                            .top = 0
                            .Bottom = .top + 32
                            .Left = (DDSD_Item(Sprite).lWidth / 4) * 2
                            .Right = .Left + 32
                        End With
                        
                        With dRECT
                            .Left = 34 + (i * 8) + (i - 1) + ((i - 1) * 32) - 4
                            .Right = .Left + 32
                            .top = 7
                            .Bottom = .top + 32
                        End With
                        
                        Engine_BltToDC DDS_Item(Sprite), sRECT, dRECT, frmMain.picBank, False
                    End If
                End If
            End If
        Next
                
        For i = 1 To MAX_BANK
            ItemNum = GetBankItemNum(i)
            If ItemNum > 0 And ItemNum <= MAX_ITEMS Then
            
                Sprite = Item(ItemNum).Picture
                
                If Sprite <= 0 Or Sprite > NumItems Then Exit Sub
                
                If DDS_Item(Sprite) Is Nothing Then
                    Call InitDDSurf("Items\" & Sprite, DDSD_Item(Sprite), DDS_Item(Sprite))
                End If
            
                With sRECT
                    .top = 0
                    .Bottom = .top + PIC_Y
                    .Left = DDSD_Item(Sprite).lWidth / 2
                    .Right = .Left + PIC_X
                End With
                
                With dRECT
                    .top = BankTop + ((BankOffsetY + 32) * ((i - 1) \ BankColumns)) + 1
                    .Bottom = .top + PIC_Y
                    .Left = BankLeft + ((BankOffsetX + 32) * (((i - 1) Mod BankColumns)))
                    .Right = .Left + PIC_X
                End With
                
                Engine_BltToDC DDS_Item(Sprite), sRECT, dRECT, frmMain.picBank, False

                ' If item is a stack - draw the amount you have
                If GetBankItemValue(i) > 1 Then
                    y = dRECT.top + 22
                    x = dRECT.Left - 4
                
                    Amount = CStr(GetBankItemValue(i))
                    ' Draw currency but with k, m, b etc. using a convertion function
                    If CLng(Amount) < 1000000 Then
                        colour = QBColor(White)
                    ElseIf CLng(Amount) > 1000000 And CLng(Amount) < 10000000 Then
                        colour = QBColor(Yellow)
                    ElseIf CLng(Amount) > 10000000 Then
                        colour = QBColor(BrightGreen)
                    End If
                    DrawText frmMain.picBank.hDC, x, y, ConvertCurrency(Amount), colour
                End If
            End If
        Next
    
        frmMain.picBank.Refresh
    End If
    
    ' Error handler
    Exit Sub
errorhandler:
    HandleError "BltBank", "modDirectDraw7", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
    Exit Sub
End Sub

Public Sub BltBankItem(ByVal x As Long, ByVal y As Long)
Dim sRECT As RECT, dRECT As RECT
Dim ItemNum As Long
Dim Sprite As Long
    
    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo errorhandler

    ItemNum = GetBankItemNum(DragBankSlotNum)
    Sprite = Item(GetBankItemNum(DragBankSlotNum)).Picture
    
    If DDS_Item(Sprite) Is Nothing Then
        Call InitDDSurf("Items\" & Sprite, DDSD_Item(Sprite), DDS_Item(Sprite))
    End If
    
    If ItemNum > 0 Then
        If ItemNum <= MAX_ITEMS Then
            With sRECT
                .top = 0
                .Bottom = .top + PIC_Y
                .Left = DDSD_Item(Sprite).lWidth / 2
                .Right = .Left + PIC_X
            End With
        End If
    End If
    
    With dRECT
        .top = 2
        .Bottom = .top + PIC_Y
        .Left = 2
        .Right = .Left + PIC_X
    End With

    Engine_BltToDC DDS_Item(Sprite), sRECT, dRECT, frmMain.picTempBank
    
    With frmMain.picTempBank
        .top = y
        .Left = x
        .Visible = True
        .ZOrder (0)
    End With
    
    ' Error handler
    Exit Sub
errorhandler:
    HandleError "BltBankItem", "modDirectDraw7", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
    Exit Sub
End Sub

' player Projectiles
Public Sub BltProjectile(ByVal Index As Long)
Dim Rec As DxVBLib.RECT
Dim i As Long

    If Index < 1 Or Index > MAX_PROJECTILES Then Exit Sub
    
    With MapProjectile.Projectile(Index)
    
        If .Pic = 0 Then Exit Sub
        
        If GetTickCount > .TravelTime Then
            Select Case .Direction
                Case 0
                    .y = .y + 1
                    If .y > Map.MaxY Then ClearProjectile Index: Exit Sub
                Case 1
                    .y = .y - 1
                    If .y < 0 Then ClearProjectile Index: Exit Sub
                Case 2
                    .x = .x + 1
                    If .x > Map.MaxX Then ClearProjectile Index: Exit Sub
                Case 3
                    .x = .x - 1
                    If .x < 0 Then ClearProjectile Index: Exit Sub
            End Select
            .TravelTime = GetTickCount + .Speed
            .Traveled = .Traveled + 1
            
            If .Traveled > .Range Then ClearProjectile Index: Exit Sub
        End If
        
        If Map.Tile(.x, .y).Type = TILE_TYPE_BLOCKED Then ClearProjectile Index: Exit Sub
        If Map.Tile(.x, .y).Type = TILE_TYPE_OBJECT Then ClearProjectile Index: Exit Sub
        
        For i = 1 To MAX_PLAYERS
            If IsPlaying(i) Then
                If Player(i).Map = Player(MyIndex).Map Then
                    If .x = GetPlayerX(i) And .y = GetPlayerY(Index) Then
                        ClearProjectile Index
                        Exit Sub
                    End If
                End If
            End If
        Next
        
        For i = 1 To MAX_NPCS
            If .x = MapNpc(i).x And .y = MapNpc(i).y Then
                ClearProjectile Index
                Exit Sub
            End If
        Next
        
        If .Pic = 0 Then Exit Sub
        
        If DDS_Projectile(.Pic) Is Nothing Then
            Call InitDDSurf("projectiles\" & .Pic, DDSD_Projectile(.Pic), DDS_Projectile(.Pic))
        End If
        
        
        Rec.top = 0
        Rec.Bottom = SIZE_Y
        Rec.Left = .Direction * SIZE_X
        Rec.Right = Rec.Left + SIZE_X
        
        Call Engine_BltFast(ConvertMapX(.x * PIC_X), ConvertMapY(.y * PIC_Y), DDS_Projectile(.Pic), Rec, DDBLTFAST_WAIT Or DDBLTFAST_SRCCOLORKEY)
    End With
End Sub
