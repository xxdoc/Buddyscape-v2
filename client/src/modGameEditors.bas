Attribute VB_Name = "modGameEditors"
Option Explicit
' ////////////////
' // Map Editor //
' ////////////////
Public Sub MapEditorInit()
Dim i As Long
Dim smusic() As String
    
    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo errorhandler

    ' set the width
    frmEditor_Map.width = 7425
    
    ' we're in the map editor
    InMapEditor = True
    
    ' show the form
    frmEditor_Map.Visible = True
    
    ' set the scrolly bars
    frmEditor_Map.scrlTileSet.Max = NumTileSets
    frmEditor_Map.fraTileSet.Caption = "Tileset: " & 1
    frmEditor_Map.scrlTileSet.Value = 1
    
    ' render the tiles
    Call EditorMap_BltTileset
    
    ' set the scrollbars
    frmEditor_Map.scrlPictureY.Max = (frmEditor_Map.picBackSelect.height \ PIC_Y) - (frmEditor_Map.picBack.height \ PIC_Y)
    frmEditor_Map.scrlPictureX.Max = (frmEditor_Map.picBackSelect.width \ PIC_X) - (frmEditor_Map.picBack.width \ PIC_X)
    MapEditorTileScroll
    
    ' set shops for the shop attribute
    frmEditor_Map.cmbShop.AddItem "None"
    For i = 1 To MAX_SHOPS
        frmEditor_Map.cmbShop.AddItem i & ": " & Shop(i).Name
    Next
    
    ' we're not in a shop
    frmEditor_Map.cmbShop.ListIndex = 0
    
    ' Error handler
    Exit Sub
errorhandler:
    HandleError "MapEditorInit", "modGameEditors", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
    Exit Sub
End Sub

Public Sub MapEditorProperties()
Dim x As Long
Dim y As Long
Dim i As Long
    
    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo errorhandler
    
    ' populate the cache if we need to
    If Not hasPopulated Then
        PopulateLists
    End If
    ' add the array to the combo
    frmEditor_MapProperties.lstMusic.Clear
    frmEditor_MapProperties.lstMusic.AddItem "None."
    For i = 1 To UBound(musicCache)
        frmEditor_MapProperties.lstMusic.AddItem musicCache(i)
    Next
    ' finished populating
    
    With frmEditor_MapProperties
        .txtName.Text = Trim$(Map.Name)
        .chkLoseItems.Value = Map.LoseItemsOnDeath
        
        ' find the music we have set
        If .lstMusic.ListCount >= 0 Then
            .lstMusic.ListIndex = 0
            For i = 0 To .lstMusic.ListCount
                If .lstMusic.List(i) = Trim$(Map.Music) Then
                    .lstMusic.ListIndex = i
                End If
            Next
        End If
        
        ' rest of it
        .txtUp.Text = CStr(Map.Up)
        .txtDown.Text = CStr(Map.Down)
        .txtLeft.Text = CStr(Map.Left)
        .txtRight.Text = CStr(Map.Right)
        .cmbMoral.ListIndex = Map.Moral
        .txtBootMap.Text = CStr(Map.BootMap)
        .txtBootX.Text = CStr(Map.BootX)
        .txtBootY.Text = CStr(Map.BootY)
        .lblInstance.Caption = Map.Instance

        ' show the map npcs
        .lstNpcs.Clear
        For x = 1 To MAX_MAP_NPCS
            If Map.Npc(x) > 0 Then
            .lstNpcs.AddItem x & ": " & Trim$(Npc(Map.Npc(x)).Name)
            Else
                .lstNpcs.AddItem x & ": No NPC"
            End If
        Next
        .lstNpcs.ListIndex = 0
        
        ' show the npc selection combo
        .cmbNpc.Clear
        .cmbNpc.AddItem "No NPC"
        For x = 1 To MAX_NPCS
            .cmbNpc.AddItem x & ": " & Trim$(Npc(x).Name)
        Next
        
        ' set the combo box properly
        Dim tmpString() As String
        Dim NpcNum As Long
        tmpString = Split(.lstNpcs.List(.lstNpcs.ListIndex))
        NpcNum = CLng(Left$(tmpString(0), Len(tmpString(0)) - 1))
        .cmbNpc.ListIndex = Map.Npc(NpcNum)
    
        ' show the current map
        .lblMap.Caption = "Current map: " & GetPlayerMap(MyIndex)
        .txtMaxX.Text = Map.MaxX
        .txtMaxY.Text = Map.MaxY
    End With
    
    ' Error handler
    Exit Sub
errorhandler:
    HandleError "MapEditorProperties", "modGameEditors", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
    Exit Sub
End Sub

Public Sub MapEditorSetTile(ByVal x As Long, ByVal y As Long, ByVal CurLayer As Long, Optional ByVal multitile As Boolean = False)
Dim x2 As Long, y2 As Long

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo errorhandler

    If Not multitile Then ' single
        With Map.Tile(x, y)
            ' set layer
            .Layer(CurLayer).x = EditorTileX
            .Layer(CurLayer).y = EditorTileY
            .Layer(CurLayer).Tileset = frmEditor_Map.scrlTileSet.Value
        End With
    Else ' multitile
        y2 = 0 ' starting tile for y axis
        For y = CurY To CurY + EditorTileHeight - 1
            x2 = 0 ' re-set x count every y loop
            For x = CurX To CurX + EditorTileWidth - 1
                If x >= 0 And x <= Map.MaxX Then
                    If y >= 0 And y <= Map.MaxY Then
                        With Map.Tile(x, y)
                            .Layer(CurLayer).x = EditorTileX + x2
                            .Layer(CurLayer).y = EditorTileY + y2
                            .Layer(CurLayer).Tileset = frmEditor_Map.scrlTileSet.Value
                        End With
                    End If
                End If
                x2 = x2 + 1
            Next
            y2 = y2 + 1
        Next
    End If
    
    ' Error handler
    Exit Sub
errorhandler:
    HandleError "MapEditorSetTile", "modGameEditors", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
    Exit Sub
End Sub

Public Sub MapEditorMouseDown(ByVal Button As Integer, ByVal x As Long, ByVal y As Long, Optional ByVal movedMouse As Boolean = True)
Dim i As Long
Dim CurLayer As Long
Dim tmpDir As Byte

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo errorhandler

    ' find which layer we're on
    For i = 1 To MapLayer.Layer_Count - 1
        If frmEditor_Map.optLayer(i).Value Then
            CurLayer = i
            Exit For
        End If
    Next

    If Not isInBounds Then Exit Sub
    If Button = vbLeftButton Then
        If frmEditor_Map.optLayers.Value Then
            If EditorTileWidth = 1 And EditorTileHeight = 1 Then 'single tile
                MapEditorSetTile CurX, CurY, CurLayer
            Else ' multi tile!
                MapEditorSetTile CurX, CurY, CurLayer, True
            End If
        ElseIf frmEditor_Map.optAttribs.Value Then
            With Map.Tile(CurX, CurY)
                ' blocked tile
                If frmEditor_Map.optBlocked.Value Then .Type = TILE_TYPE_BLOCKED
                ' warp tile
                If frmEditor_Map.optWarp.Value Then
                    .Type = TILE_TYPE_WARP
                    .Data1 = EditorWarpMap
                    .Data2 = EditorWarpX
                    .Data3 = EditorWarpY
                End If
                ' item spawn
                If frmEditor_Map.optItem.Value Then
                    .Type = TILE_TYPE_ITEM
                    .Data1 = ItemEditorNum
                    .Data2 = ItemEditorValue
                    .Data3 = 0
                End If
                ' npc avoid
                If frmEditor_Map.optNpcAvoid.Value Then
                    .Type = TILE_TYPE_NPCAVOID
                    .Data1 = 0
                    .Data2 = 0
                    .Data3 = 0
                End If
                ' key
                If frmEditor_Map.optKey.Value Then
                    .Type = TILE_TYPE_KEY
                    .Data1 = KeyEditorNum
                    .Data2 = KeyEditorTake
                    .Data3 = 0
                End If
                ' key open
                If frmEditor_Map.optKeyOpen.Value Then
                    .Type = TILE_TYPE_KEYOPEN
                    .Data1 = KeyOpenEditorX
                    .Data2 = KeyOpenEditorY
                    .Data3 = 0
                End If
                ' resource
                If frmEditor_Map.optResource.Value Then
                    .Type = TILE_TYPE_RESOURCE
                    .Data1 = ResourceEditorNum
                    .Data2 = 0
                    .Data3 = 0
                End If
                ' door
                If frmEditor_Map.optDoor.Value Then
                    .Type = TILE_TYPE_DOOR
                    .Data1 = EditorWarpMap
                    .Data2 = EditorWarpX
                    .Data3 = EditorWarpY
                End If
                ' npc spawn
                If frmEditor_Map.optNpcSpawn.Value Then
                    .Type = TILE_TYPE_NPCSPAWN
                    .Data1 = SpawnNpcNum
                    .Data2 = SpawnNpcDir
                    .Data3 = 0
                End If
                ' shop
                If frmEditor_Map.optShop.Value Then
                    .Type = TILE_TYPE_SHOP
                    .Data1 = EditorShop
                    .Data2 = 0
                    .Data3 = 0
                End If
                ' bank
                If frmEditor_Map.optBank.Value Then
                    .Type = TILE_TYPE_BANK
                    .Data1 = 0
                    .Data2 = 0
                    .Data3 = 0
                End If
                ' heal
                If frmEditor_Map.optHeal.Value Then
                    .Type = TILE_TYPE_HEAL
                    .Data1 = MapEditorHealType
                    .Data2 = MapEditorHealAmount
                    .Data3 = 0
                End If
                ' trap
                If frmEditor_Map.optTrap.Value Then
                    .Type = TILE_TYPE_TRAP
                    .Data1 = MapEditorHealAmount
                    .Data2 = 0
                    .Data3 = 0
                End If
                ' slide
                If frmEditor_Map.optSlide.Value Then
                    .Type = TILE_TYPE_SLIDE
                    .Data1 = MapEditorSlideDir
                    .Data2 = 0
                    .Data3 = 0
                End If
                If frmEditor_Map.optCustom.Value Then
                    .Type = TILE_TYPE_CUSTOM
                    .Data1 = 0
                    .Data2 = 0
                    .Data3 = 0
                End If
                If frmEditor_Map.optObject.Value Then
                    .Type = TILE_TYPE_OBJECT
                    .Data1 = 0
                    .Data2 = 0
                    .Data3 = 0
                End If
            End With
        ElseIf frmEditor_Map.optBlock.Value Then
            If movedMouse Then Exit Sub
            ' find what tile it is
            x = x - ((x \ 32) * 32)
            y = y - ((y \ 32) * 32)
            ' see if it hits an arrow
            For i = 1 To 4
                If x >= DirArrowX(i) And x <= DirArrowX(i) + 8 Then
                    If y >= DirArrowY(i) And y <= DirArrowY(i) + 8 Then
                        ' flip the value.
                        setDirBlock Map.Tile(CurX, CurY).DirBlock, CByte(i), Not isDirBlocked(Map.Tile(CurX, CurY).DirBlock, CByte(i))
                        Exit Sub
                    End If
                End If
            Next
        End If
    End If

    If Button = vbRightButton Then
        If frmEditor_Map.optLayers.Value Then
            With Map.Tile(CurX, CurY)
                ' clear layer
                .Layer(CurLayer).x = 0
                .Layer(CurLayer).y = 0
                .Layer(CurLayer).Tileset = 0
            End With
        ElseIf frmEditor_Map.optAttribs.Value Then
            With Map.Tile(CurX, CurY)
                ' clear attribute
                .Type = 0
                .Data1 = 0
                .Data2 = 0
                .Data3 = 0
            End With

        End If
    End If

    CacheResources
    
    ' Error handler
    Exit Sub
errorhandler:
    HandleError "MapEditorMouseDown", "modGameEditors", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
    Exit Sub
End Sub

Public Sub MapEditorChooseTile(Button As Integer, x As Single, y As Single)
    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo errorhandler

    If Button = vbLeftButton Then
        EditorTileWidth = 1
        EditorTileHeight = 1
        
        EditorTileX = x \ PIC_X
        EditorTileY = y \ PIC_Y
        
        frmEditor_Map.shpSelected.top = EditorTileY * PIC_Y
        frmEditor_Map.shpSelected.Left = EditorTileX * PIC_X
        
        frmEditor_Map.shpSelected.width = PIC_X
        frmEditor_Map.shpSelected.height = PIC_Y
    End If
    
    ' Error handler
    Exit Sub
errorhandler:
    HandleError "MapEditorChooseTile", "modGameEditors", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
    Exit Sub
End Sub

Public Sub MapEditorDrag(Button As Integer, x As Single, y As Single)
    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo errorhandler

    If Button = vbLeftButton Then
        ' convert the pixel number to tile number
        x = (x \ PIC_X) + 1
        y = (y \ PIC_Y) + 1
        ' check it's not out of bounds
        If x < 0 Then x = 0
        If x > frmEditor_Map.picBackSelect.width / PIC_X Then x = frmEditor_Map.picBackSelect.width / PIC_X
        If y < 0 Then y = 0
        If y > frmEditor_Map.picBackSelect.height / PIC_Y Then y = frmEditor_Map.picBackSelect.height / PIC_Y
        ' find out what to set the width + height of map editor to
        If x > EditorTileX Then ' drag right
            EditorTileWidth = x - EditorTileX
        Else ' drag left
            ' TO DO
        End If
        If y > EditorTileY Then ' drag down
            EditorTileHeight = y - EditorTileY
        Else ' drag up
            ' TO DO
        End If
        frmEditor_Map.shpSelected.width = EditorTileWidth * PIC_X
        frmEditor_Map.shpSelected.height = EditorTileHeight * PIC_Y
    End If

    ' Error handler
    Exit Sub
errorhandler:
    HandleError "MapEditorDrag", "modGameEditors", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
    Exit Sub
End Sub

Public Sub MapEditorTileScroll()
    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo errorhandler

    ' horizontal scrolling
    If frmEditor_Map.picBackSelect.width < frmEditor_Map.picBack.width Then
        frmEditor_Map.scrlPictureX.Enabled = False
    Else
        frmEditor_Map.scrlPictureX.Enabled = True
        frmEditor_Map.picBackSelect.Left = (frmEditor_Map.scrlPictureX.Value * PIC_X) * -1
    End If
    
    ' vertical scrolling
    If frmEditor_Map.picBackSelect.height < frmEditor_Map.picBack.height Then
        frmEditor_Map.scrlPictureY.Enabled = False
    Else
        frmEditor_Map.scrlPictureY.Enabled = True
        frmEditor_Map.picBackSelect.top = (frmEditor_Map.scrlPictureY.Value * PIC_Y) * -1
    End If

    ' Error handler
    Exit Sub
errorhandler:
    HandleError "MapEditorTileScroll", "modGameEditors", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
    Exit Sub
End Sub

Public Sub MapEditorSend()
    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo errorhandler

    Call SendMap
    InMapEditor = False
    Unload frmEditor_Map
    
    ' Error handler
    Exit Sub
errorhandler:
    HandleError "MapEditorSend", "modGameEditors", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
    Exit Sub
End Sub

Public Sub MapEditorCancel()
Dim Buffer As clsBuffer

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo errorhandler

    Set Buffer = New clsBuffer
    Buffer.WriteLong CNeedMap
    Buffer.WriteLong 1
    SendData Buffer.ToArray()
    InMapEditor = False
    Unload frmEditor_Map
    
    ' Error handler
    Exit Sub
errorhandler:
    HandleError "MapEditorCancel", "modGameEditors", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
    Exit Sub
End Sub

Public Sub MapEditorClearLayer()
Dim i As Long
Dim x As Long
Dim y As Long
Dim CurLayer As Long

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo errorhandler

    ' find which layer we're on
    For i = 1 To MapLayer.Layer_Count - 1
        If frmEditor_Map.optLayer(i).Value Then
            CurLayer = i
            Exit For
        End If
    Next
    
    If CurLayer = 0 Then Exit Sub

    ' ask to clear layer
    If MsgBox("Are you sure you wish to clear this layer?", vbYesNo, Options.Game_Name) = vbYes Then
        For x = 0 To Map.MaxX
            For y = 0 To Map.MaxY
                Map.Tile(x, y).Layer(CurLayer).x = 0
                Map.Tile(x, y).Layer(CurLayer).y = 0
                Map.Tile(x, y).Layer(CurLayer).Tileset = 0
            Next
        Next
    End If
    
    ' Error handler
    Exit Sub
errorhandler:
    HandleError "MapEditorClearLayer", "modGameEditors", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
    Exit Sub
End Sub

Public Sub MapEditorFillLayer()
Dim i As Long
Dim x As Long
Dim y As Long
Dim CurLayer As Long

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo errorhandler

    ' find which layer we're on
    For i = 1 To MapLayer.Layer_Count - 1
        If frmEditor_Map.optLayer(i).Value Then
            CurLayer = i
            Exit For
        End If
    Next

    ' Ground layer
    If MsgBox("Are you sure you wish to fill this layer?", vbYesNo, Options.Game_Name) = vbYes Then
        For x = 0 To Map.MaxX
            For y = 0 To Map.MaxY
                Map.Tile(x, y).Layer(CurLayer).x = EditorTileX
                Map.Tile(x, y).Layer(CurLayer).y = EditorTileY
                Map.Tile(x, y).Layer(CurLayer).Tileset = frmEditor_Map.scrlTileSet.Value
            Next
        Next
    End If
    
    ' Error handler
    Exit Sub
errorhandler:
    HandleError "MapEditorFillLayer", "modGameEditors", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
    Exit Sub
End Sub

Public Sub MapEditorClearAttribs()
Dim x As Long
Dim y As Long

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo errorhandler

    If MsgBox("Are you sure you wish to clear the attributes on this map?", vbYesNo, Options.Game_Name) = vbYes Then

        For x = 0 To Map.MaxX
            For y = 0 To Map.MaxY
                Map.Tile(x, y).Type = 0
            Next
        Next

    End If

    ' Error handler
    Exit Sub
errorhandler:
    HandleError "MapEditorClearAttribs", "modGameEditors", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
    Exit Sub
End Sub

Public Sub MapEditorLeaveMap()
    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo errorhandler

    If InMapEditor Then
        If MsgBox("Save changes to current map?", vbYesNo) = vbYes Then
            Call MapEditorSend
        Else
            Call MapEditorCancel
        End If
    End If

    ' Error handler
    Exit Sub
errorhandler:
    HandleError "MapEditorLeaveMap", "modGameEditors", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
    Exit Sub
End Sub

' /////////////////
' // Item Editor //
' /////////////////
Public Sub ItemEditorInit()
Dim i As Long
Dim SoundSet As Boolean
    
    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo errorhandler

    If frmEditor_Item.Visible = False Then Exit Sub
    EditorIndex = frmEditor_Item.lstIndex.ListIndex + 1
    
    ' populate the cache if we need to
    If Not hasPopulated Then
        PopulateLists
    End If
    ' add the array to the combo
    frmEditor_Item.cmbSound.Clear
    frmEditor_Item.cmbSound.AddItem "None."
    For i = 1 To UBound(soundCache)
        frmEditor_Item.cmbSound.AddItem soundCache(i)
    Next
    ' finished populating

    With Item(EditorIndex)
        frmEditor_Item.txtName.Text = Trim$(.Name)
        If .Picture > frmEditor_Item.scrlPic.Max Then .Picture = 0
        frmEditor_Item.scrlPic.Value = .Picture
        frmEditor_Item.cmbType.ListIndex = .ItemType
        frmEditor_Item.scrlAnim.Value = .Animation
        frmEditor_Item.txtDesc.Text = Trim$(.Description)
        frmEditor_Item.chkStackable.Value = .Stackable
        frmEditor_Item.chkTradable.Value = .Tradable
        frmEditor_Item.chkTwoHanded.Value = .isTwoHander
        
        ' find the sound we have set
        If frmEditor_Item.cmbSound.ListCount >= 0 Then
            For i = 0 To frmEditor_Item.cmbSound.ListCount
                If frmEditor_Item.cmbSound.List(i) = Trim$(.Sound) Then
                    frmEditor_Item.cmbSound.ListIndex = i
                    SoundSet = True
                End If
            Next
            If Not SoundSet Or frmEditor_Item.cmbSound.ListIndex = -1 Then frmEditor_Item.cmbSound.ListIndex = 0
        End If

        ' Type specific settings
        If (frmEditor_Item.cmbType.ListIndex > ITEM_TYPE_NONE) And (frmEditor_Item.cmbType.ListIndex <= ITEM_TYPE_RING) Then
            frmEditor_Item.fraEquipment.Visible = True
            frmEditor_Item.scrlDamage.Value = .Damage
            frmEditor_Item.cmbTool.ListIndex = .EquipmentType
            frmEditor_Item.cmbWeaponType.ListIndex = .CombatType - 1

            If .Speed < 100 Then .Speed = 100
            frmEditor_Item.scrlSpeed.Value = .Speed
            
            frmEditor_Item.scrlPaperdoll = .Paperdoll(1)
            
            ' projectiles
            If frmEditor_Item.cmbType.ListIndex = ITEM_TYPE_WEAPON Then
                With Item(EditorIndex).Projectile
                    frmEditor_Item.scrlProjectilePic.Value = .Pic
                    frmEditor_Item.scrlProjectileRange.Value = .Range
                    frmEditor_Item.scrlProjectileSpeed.Value = .Speed
                End With
            End If
            
        Else
            frmEditor_Item.fraEquipment.Visible = False
        End If

        If frmEditor_Item.cmbType.ListIndex = ITEM_TYPE_CONSUME Then
            frmEditor_Item.fraVitals.Visible = True
            frmEditor_Item.scrlAddHp.Value = .AddVital(Vitals.HitPoints)
            frmEditor_Item.scrlAddMP.Value = .AddVital(Vitals.Prayer)
            frmEditor_Item.scrlAddExp.Value = .AddVital(Vitals.Summoning)
        Else
            frmEditor_Item.fraVitals.Visible = False
        End If
        
        frmEditor_Item.scrlReward.Value = 1
        frmEditor_Item.scrlBonus.Value = 1
        frmEditor_Item.scrlMakingReq.Value = 1
        
        For i = 1 To CombatStyles.Count - 1
            frmEditor_Item.scrlOffense(i).Value = .Offense(i)
            frmEditor_Item.scrlDefense(i).Value = .Defense(i)
        Next

        ' Basic requirements
        frmEditor_Item.scrlAccessReq.Value = .AccessRequired
        
        ' Info
        frmEditor_Item.scrlPrice.Value = .MonetaryValue
         
        EditorIndex = frmEditor_Item.lstIndex.ListIndex + 1
    End With

    Call EditorItem_BltItem
    Item_Changed(EditorIndex) = True
    
    ' Error handler
    Exit Sub
errorhandler:
    HandleError "ItemEditorInit", "modGameEditors", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
    Exit Sub
End Sub

Public Sub ItemEditorOk()
Dim i As Long

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo errorhandler

    For i = 1 To MAX_ITEMS
        If Item_Changed(i) Then
            Call SendSaveItem(i)
        End If
    Next
    
    Unload frmEditor_Item
    Editor = 0
    ClearChanged_Item
    
    ' Error handler
    Exit Sub
errorhandler:
    HandleError "ItemEditorOk", "modGameEditors", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
    Exit Sub
End Sub

Public Sub ItemEditorCancel()
    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo errorhandler

    Editor = 0
    Unload frmEditor_Item
    ClearChanged_Item
    ClearItems
    SendRequestItems
    
    ' Error handler
    Exit Sub
errorhandler:
    HandleError "ItemEditorCancel", "modGameEditors", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
    Exit Sub
End Sub

Public Sub ClearChanged_Item()
    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo errorhandler

    ZeroMemory Item_Changed(1), MAX_ITEMS * 2 ' 2 = boolean length
    
    ' Error handler
    Exit Sub
errorhandler:
    HandleError "ClearChanged_Item", "modGameEditors", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
    Exit Sub
End Sub

' /////////////////
' // Animation Editor //
' /////////////////
Public Sub AnimationEditorInit()
Dim i As Long
Dim SoundSet As Boolean
    
    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo errorhandler

    If frmEditor_Animation.Visible = False Then Exit Sub
    EditorIndex = frmEditor_Animation.lstIndex.ListIndex + 1
    
    ' populate the cache if we need to
    If Not hasPopulated Then
        PopulateLists
    End If
    ' add the array to the combo
    frmEditor_Animation.cmbSound.Clear
    frmEditor_Animation.cmbSound.AddItem "None."
    For i = 1 To UBound(soundCache)
        frmEditor_Animation.cmbSound.AddItem soundCache(i)
    Next
    ' finished populating

    With Animation(EditorIndex)
        frmEditor_Animation.txtName.Text = Trim$(.Name)
        
        ' find the sound we have set
        If frmEditor_Animation.cmbSound.ListCount >= 0 Then
            For i = 0 To frmEditor_Animation.cmbSound.ListCount
                If frmEditor_Animation.cmbSound.List(i) = Trim$(.Sound) Then
                    frmEditor_Animation.cmbSound.ListIndex = i
                    SoundSet = True
                End If
            Next
            If Not SoundSet Or frmEditor_Animation.cmbSound.ListIndex = -1 Then frmEditor_Animation.cmbSound.ListIndex = 0
        End If
        
        For i = 0 To 1
            frmEditor_Animation.scrlSprite(i).Value = .Sprite(i)
            frmEditor_Animation.scrlFrameCount(i).Value = .Frames(i)
            frmEditor_Animation.scrlLoopCount(i).Value = .LoopCount(i)
            
            If .looptime(i) > 0 Then
                frmEditor_Animation.scrlLoopTime(i).Value = .looptime(i)
            Else
                frmEditor_Animation.scrlLoopTime(i).Value = 45
            End If
            
        Next
         
        EditorIndex = frmEditor_Animation.lstIndex.ListIndex + 1
    End With

    Call EditorAnim_BltAnim
    Animation_Changed(EditorIndex) = True
    
    ' Error handler
    Exit Sub
errorhandler:
    HandleError "AnimationEditorInit", "modGameEditors", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
    Exit Sub
End Sub

Public Sub AnimationEditorOk()
Dim i As Long

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo errorhandler

    For i = 1 To MAX_ANIMATIONS
        If Animation_Changed(i) Then
            Call SendSaveAnimation(i)
        End If
    Next
    
    Unload frmEditor_Animation
    Editor = 0
    ClearChanged_Animation
    
    ' Error handler
    Exit Sub
errorhandler:
    HandleError "AnimationEditorOk", "modGameEditors", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
    Exit Sub
End Sub

Public Sub AnimationEditorCancel()
    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo errorhandler

    Editor = 0
    Unload frmEditor_Animation
    ClearChanged_Animation
    ClearAnimations
    SendRequestAnimations
    
    ' Error handler
    Exit Sub
errorhandler:
    HandleError "AnimationEditorCancel", "modGameEditors", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
    Exit Sub
End Sub

Public Sub ClearChanged_Animation()
    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo errorhandler

    ZeroMemory Animation_Changed(1), MAX_ANIMATIONS * 2 ' 2 = boolean length
    
    ' Error handler
    Exit Sub
errorhandler:
    HandleError "ClearChanged_Animation", "modGameEditors", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
    Exit Sub
End Sub

' ////////////////
' // Npc Editor //
' ////////////////
Public Sub NpcEditorInit()
Dim i As Long
Dim SoundSet As Boolean
    
    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo errorhandler

    If frmEditor_NPC.Visible = False Then Exit Sub
    EditorIndex = frmEditor_NPC.lstIndex.ListIndex + 1
    
    ' populate the cache if we need to
    If Not hasPopulated Then
        PopulateLists
    End If
    ' add the array to the combo
    frmEditor_NPC.cmbSound.Clear
    frmEditor_NPC.cmbSound.AddItem "None."
    For i = 1 To UBound(soundCache)
        frmEditor_NPC.cmbSound.AddItem soundCache(i)
    Next
    ' finished populating
    
    With frmEditor_NPC
        .txtName.Text = Trim$(Npc(EditorIndex).Name)
        If Npc(EditorIndex).Sprite < 0 Or Npc(EditorIndex).Sprite > .scrlSprite.Max Then Npc(EditorIndex).Sprite = 0
        .scrlSprite.Value = Npc(EditorIndex).Sprite
        .txtSpawnSecs.Text = CStr(Npc(EditorIndex).RespawnRate)
        .cmbBehaviour.ListIndex = Npc(EditorIndex).Type
        .scrlRange.Value = Npc(EditorIndex).SightRange
        .scrlDrop.Value = 1
        .txtDropChance.Text = CStr(Npc(EditorIndex).Drop(1).Chance)
        .scrlDropItem.Value = Npc(EditorIndex).Drop(1).Item
        .txtDropValue.Text = Npc(EditorIndex).Drop(1).Amount
        .txtEXP.Text = Npc(EditorIndex).RewardXP
        .txtLevel.Text = Npc(EditorIndex).Level
        .scrlDamage.Value = Npc(EditorIndex).Damage
        .lblTeam.Caption = "Team: " & Npc(EditorIndex).Team
        If Npc(EditorIndex).AttackSpeed < 100 Then Npc(EditorIndex).AttackSpeed = 100
        .scrlSpeed.Value = Npc(EditorIndex).AttackSpeed
        
        ' find the sound we have set
        If .cmbSound.ListCount >= 0 Then
            For i = 0 To .cmbSound.ListCount
                If .cmbSound.List(i) = Trim$(Npc(EditorIndex).Sound) Then
                    .cmbSound.ListIndex = i
                    SoundSet = True
                End If
            Next
            If Not SoundSet Or .cmbSound.ListIndex = -1 Then .cmbSound.ListIndex = 0
        End If
        
        .scrlBonus.Value = 1
        .txtBonus.Text = Npc(EditorIndex).Skill(1)
        
        For i = 1 To 3
            .scrlOffense(i).Value = Npc(EditorIndex).Offense(i)
            .scrlDefense(i).Value = Npc(EditorIndex).Defense(i)
        Next
    End With
    
    NPC_Changed(EditorIndex) = True
    
    ' Error handler
    Exit Sub
errorhandler:
    HandleError "NpcEditorInit", "modGameEditors", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
    Exit Sub
End Sub

Public Sub NpcEditorOk()
Dim i As Long

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo errorhandler

    For i = 1 To MAX_NPCS
        If NPC_Changed(i) Then
            Call SendSaveNpc(i)
        End If
    Next
    
    Unload frmEditor_NPC
    Editor = 0
    ClearChanged_NPC
    
    ' Error handler
    Exit Sub
errorhandler:
    HandleError "NpcEditorOk", "modGameEditors", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
    Exit Sub
End Sub

Public Sub NpcEditorCancel()
    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo errorhandler

    Editor = 0
    Unload frmEditor_NPC
    ClearChanged_NPC
    ClearNpcs
    SendRequestNPCS
    
    ' Error handler
    Exit Sub
errorhandler:
    HandleError "NpcEditorCancel", "modGameEditors", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
    Exit Sub
End Sub

Public Sub ClearChanged_NPC()
    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo errorhandler

    ZeroMemory NPC_Changed(1), MAX_NPCS * 2 ' 2 = boolean length
    
    ' Error handler
    Exit Sub
errorhandler:
    HandleError "ClearChanged_NPC", "modGameEditors", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
    Exit Sub
End Sub

' ////////////////
' // Resource Editor //
' ////////////////
Public Sub ResourceEditorInit()
Dim i As Long
Dim SoundSet As Boolean

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo errorhandler

    If frmEditor_Resource.Visible = False Then Exit Sub
    EditorIndex = frmEditor_Resource.lstIndex.ListIndex + 1
    
    ' populate the cache if we need to
    If Not hasPopulated Then
        PopulateLists
    End If
    ' add the array to the combo
    frmEditor_Resource.cmbSound.Clear
    frmEditor_Resource.cmbSound.AddItem "None."
    For i = 1 To UBound(soundCache)
        frmEditor_Resource.cmbSound.AddItem soundCache(i)
    Next
    ' finished populating
    
    With frmEditor_Resource
        .scrlExhaustedPic.Max = NumResources
        .scrlNormalPic.Max = NumResources
        .scrlAnimation.Max = MAX_ANIMATIONS
        
        .txtName.Text = Trim$(Resource(EditorIndex).Name)
        .txtMessage.Text = Trim$(Resource(EditorIndex).SuccessMessage)
        .txtMessage2.Text = Trim$(Resource(EditorIndex).EmptyMessage)
        .scrlNormalPic.Value = Resource(EditorIndex).ResourceImage
        .scrlExhaustedPic.Value = Resource(EditorIndex).ExhaustedImage
        .scrlTool.Value = Resource(EditorIndex).ToolRequired
        .scrlRespawn.Value = Resource(EditorIndex).RespawnTime
        .scrlAnimation.Value = Resource(EditorIndex).Animation
        
        ' find the sound we have set
        If .cmbSound.ListCount >= 0 Then
            For i = 0 To .cmbSound.ListCount
                If .cmbSound.List(i) = Trim$(Resource(EditorIndex).Sound) Then
                    .cmbSound.ListIndex = i
                    SoundSet = True
                End If
            Next
            If Not SoundSet Or .cmbSound.ListIndex = -1 Then .cmbSound.ListIndex = 0
        End If
    End With
        
    Call EditorResource_BltSprite
    
    Resource_Changed(EditorIndex) = True
    
    ' Error handler
    Exit Sub
errorhandler:
    HandleError "ResourceEditorInit", "modGameEditors", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
    Exit Sub
End Sub

Public Sub ResourceEditorOk()
Dim i As Long

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo errorhandler

    For i = 1 To MAX_RESOURCES
        If Resource_Changed(i) Then
            Call SendSaveResource(i)
        End If
    Next
    
    Unload frmEditor_Resource
    Editor = 0
    ClearChanged_Resource
    
    ' Error handler
    Exit Sub
errorhandler:
    HandleError "ResourceEditorOk", "modGameEditors", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
    Exit Sub
End Sub

Public Sub ResourceEditorCancel()
    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo errorhandler

    Editor = 0
    Unload frmEditor_Resource
    ClearChanged_Resource
    ClearResources
    SendRequestResources
    
    ' Error handler
    Exit Sub
errorhandler:
    HandleError "ResourceEditorCancel", "modGameEditors", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
    Exit Sub
End Sub

Public Sub ClearChanged_Resource()
    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo errorhandler

    ZeroMemory Resource_Changed(1), MAX_RESOURCES * 2 ' 2 = boolean length
    
    ' Error handler
    Exit Sub
errorhandler:
    HandleError "ClearChanged_Resource", "modGameEditors", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
    Exit Sub
End Sub

' /////////////////
' // Shop Editor //
' /////////////////
Public Sub ShopEditorInit()
Dim i As Long
Dim x As Long
    
    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo errorhandler

    If frmEditor_Shop.Visible = False Then Exit Sub
    EditorIndex = frmEditor_Shop.lstIndex.ListIndex + 1
    
    frmEditor_Shop.txtName.Text = Trim$(Shop(EditorIndex).Name)
    frmEditor_Shop.txtBuyVerb.Text = Trim$(Shop(EditorIndex).BuyVerb)
    frmEditor_Shop.scrlCurrency.Value = Shop(EditorIndex).ShopCurrency
    frmEditor_Shop.scrlGUI.Value = Shop(EditorIndex).InterfaceNum
    frmEditor_Shop.chkOnlyBuyItemsInStock.Value = Shop(EditorIndex).OnlyBuyItemsInStock
    If Shop(EditorIndex).BuyRate > 0 Then
        frmEditor_Shop.scrlBuy.Value = Shop(EditorIndex).BuyRate
    Else
        frmEditor_Shop.scrlBuy.Value = 100
    End If
    
    frmEditor_Shop.cmbItem.Clear
    frmEditor_Shop.cmbItem.AddItem "None"
    
    For x = 1 To MAX_SHOP_ITEM_COSTS
        frmEditor_Shop.cmbCostItem(x).Clear
        frmEditor_Shop.cmbCostItem(x).AddItem "None"
    Next

    For i = 1 To MAX_ITEMS
        frmEditor_Shop.cmbItem.AddItem i & ": " & Trim$(Item(i).Name)
        For x = 1 To MAX_SHOP_ITEM_COSTS
            frmEditor_Shop.cmbCostItem(x).AddItem i & ": " & Trim$(Item(i).Name)
        Next
    Next

    frmEditor_Shop.cmbItem.ListIndex = 0
    For x = 1 To MAX_SHOP_ITEM_COSTS
        frmEditor_Shop.cmbCostItem(x).ListIndex = 0
    Next
    
    UpdateShopTrade
    
    Shop_Changed(EditorIndex) = True
    
    ' Error handler
    Exit Sub
errorhandler:
    HandleError "ShopEditorInit", "modGameEditors", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
    Exit Sub
End Sub

Public Sub UpdateShopTrade(Optional ByVal tmpPos As Long = 0)
Dim i As Long
Dim x As Long, Text As String, CostText As String

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo errorhandler

    frmEditor_Shop.lstTradeItem.Clear

    For i = 1 To MAX_TRADES
        CostText = vbNullString
        With Shop(EditorIndex).TradeItem(i)
            ' if none, show as none
            If .Item = 0 Then
                Text = "Empty Trade Slot"
            Else
                 Text = i & ": " & 1 & "x " & Trim$(Item(.Item).Name) & " for "
                 For x = 1 To MAX_SHOP_ITEM_COSTS
                    If .CostItem(x) > 0 Then
                        CostText = CostText & .CostValue(x) & "x " & Trim$(Item(.CostItem(x)).Name & " ")
                    End If
                 Next
                 If CostText = vbNullString Then CostText = " free"
            End If
        End With
        frmEditor_Shop.lstTradeItem.AddItem Text & CostText
    Next

    frmEditor_Shop.lstTradeItem.ListIndex = tmpPos
    
    ' Error handler
    Exit Sub
errorhandler:
    HandleError "UpdateShopTrade", "modGameEditors", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
    Exit Sub
End Sub

Public Sub ShopEditorOk()
Dim i As Long

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo errorhandler

    For i = 1 To MAX_SHOPS
        If Shop_Changed(i) Then
            Call SendSaveShop(i)
        End If
    Next
    
    Unload frmEditor_Shop
    Editor = 0
    ClearChanged_Shop
    
    ' Error handler
    Exit Sub
errorhandler:
    HandleError "ShopEditorOk", "modGameEditors", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
    Exit Sub
End Sub

Public Sub ShopEditorCancel()
    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo errorhandler

    Editor = 0
    Unload frmEditor_Shop
    ClearChanged_Shop
    ClearShops
    SendRequestShops
    
    ' Error handler
    Exit Sub
errorhandler:
    HandleError "ShopEditorCancel", "modGameEditors", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
    Exit Sub
End Sub

Public Sub ClearChanged_Shop()
    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo errorhandler

    ZeroMemory Shop_Changed(1), MAX_SHOPS * 2 ' 2 = boolean length
    
    ' Error handler
    Exit Sub
errorhandler:
    HandleError "ClearChanged_Shop", "modGameEditors", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
    Exit Sub
End Sub

' //////////////////
' // Spell Editor //
' //////////////////
Public Sub SpellEditorInit()
Dim i As Long
Dim SoundSet As Boolean
    
    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo errorhandler

    If frmEditor_Spell.Visible = False Then Exit Sub
    EditorIndex = frmEditor_Spell.lstIndex.ListIndex + 1
    
    ' populate the cache if we need to
    If Not hasPopulated Then
        PopulateLists
    End If
    ' add the array to the combo
    frmEditor_Spell.cmbSound.Clear
    frmEditor_Spell.cmbSound.AddItem "None."
    For i = 1 To UBound(soundCache)
        frmEditor_Spell.cmbSound.AddItem soundCache(i)
    Next
    ' finished populating
    
    With frmEditor_Spell
        ' set max values
        .scrlAnimCast.Max = MAX_ANIMATIONS
        .scrlAnim.Max = MAX_ANIMATIONS
        .scrlAOE.Max = MAX_BYTE
        .scrlRange.Max = MAX_BYTE
        
        ' set values
        .txtName.Text = Trim$(Spell(EditorIndex).Name)
        .txtDesc.Text = Trim$(Spell(EditorIndex).Description)
        .scrlCast.Value = Spell(EditorIndex).CastingTime
        .scrlCool.Value = Spell(EditorIndex).CooldownTime
        .scrlIcon.Value = Spell(EditorIndex).Icon
        .scrlRange.Value = Spell(EditorIndex).Range
        .txtDamage.Text = Spell(EditorIndex).Damage
        .chkAOE.Value = Spell(EditorIndex).AoE
        .scrlAOE.Value = Spell(EditorIndex).AoERange
        .scrlAnimCast.Value = Spell(EditorIndex).CastAnim
        .scrlAnim.Value = Spell(EditorIndex).HitAnim
        .scrlStun.Value = Spell(EditorIndex).StunDuration
        
        ' find the sound we have set
        If .cmbSound.ListCount >= 0 Then
            For i = 0 To .cmbSound.ListCount
                If .cmbSound.List(i) = Trim$(Spell(EditorIndex).Sound) Then
                    .cmbSound.ListIndex = i
                    SoundSet = True
                End If
            Next
            If Not SoundSet Or .cmbSound.ListIndex = -1 Then .cmbSound.ListIndex = 0
        End If
    End With
    
    EditorSpell_BltIcon
    
    Spell_Changed(EditorIndex) = True
    
    ' Error handler
    Exit Sub
errorhandler:
    HandleError "SpellEditorInit", "modGameEditors", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
    Exit Sub
End Sub

Public Sub SpellEditorOk()
Dim i As Long

    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo errorhandler

    For i = 1 To MAX_SPELLS
        If Spell_Changed(i) Then
            Call SendSaveSpell(i)
        End If
    Next
    
    Unload frmEditor_Spell
    Editor = 0
    ClearChanged_Spell
    
    ' Error handler
    Exit Sub
errorhandler:
    HandleError "SpellEditorOk", "modGameEditors", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
    Exit Sub
End Sub

Public Sub SpellEditorCancel()
    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo errorhandler

    Editor = 0
    Unload frmEditor_Spell
    ClearChanged_Spell
    ClearSpells
    SendRequestSpells
    
    ' Error handler
    Exit Sub
errorhandler:
    HandleError "SpellEditorCancel", "modGameEditors", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
    Exit Sub
End Sub

Public Sub ClearChanged_Spell()
    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo errorhandler

    ZeroMemory Spell_Changed(1), MAX_SPELLS * 2 ' 2 = boolean length
    
    ' Error handler
    Exit Sub
errorhandler:
    HandleError "ClearChanged_Spell", "modGameEditors", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
    Exit Sub
End Sub

Public Sub ClearAttributeDialogue()
    ' If debug mode, handle error then exit out
    If Options.Debug = 1 Then On Error GoTo errorhandler

    frmEditor_Map.fraNpcSpawn.Visible = False
    frmEditor_Map.fraResource.Visible = False
    frmEditor_Map.fraMapItem.Visible = False
    frmEditor_Map.fraMapKey.Visible = False
    frmEditor_Map.fraKeyOpen.Visible = False
    frmEditor_Map.fraMapWarp.Visible = False
    frmEditor_Map.fraShop.Visible = False
    
    ' Error handler
    Exit Sub
errorhandler:
    HandleError "ClearAttributeDialogue", "modGameEditors", Err.Number, Err.Description, Err.Source, Err.HelpContext
    Err.Clear
    Exit Sub
End Sub
