object FrmVisualFileManager: TFrmVisualFileManager
  Left = 0
  Top = 0
  Caption = 'Dosya Yoneticisi'
  ClientHeight = 760
  ClientWidth = 1180
  Constraints.MinHeight = 520
  Constraints.MinWidth = 480
  Color = $00D9E2EA
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  Position = poScreenCenter
  OnResize = FormResize
  OnShow = FormShow
  PixelsPerInch = 96
  TextHeight = 13
  object ToolPanel: TPanel
    Left = 0
    Top = 0
    Width = 1180
    Height = 104
    Align = alTop
    BevelOuter = bvRaised
    BevelWidth = 2
    Color = $00EAF0F5
    ParentBackground = False
    TabOrder = 0
    object PathGroupBevel: TBevel
      Left = 8
      Top = 7
      Width = 824
      Height = 39
      Shape = bsBox
      Style = bsRaised
    end
    object ViewGroupBevel: TBevel
      Left = 8
      Top = 40
      Width = 1160
      Height = 35
      Shape = bsBox
      Style = bsRaised
    end
    object ActionGroupBevel: TBevel
      Left = 834
      Top = 7
      Width = 108
      Height = 39
      Shape = bsBox
      Style = bsRaised
    end
    object FolderEdit: TEdit
      Left = 16
      Top = 14
      Width = 490
      Height = 21
      TabOrder = 0
    end
    object BrowseButton: TButton
      Left = 514
      Top = 13
      Width = 86
      Height = 27
      Caption = 'Klasor Sec'
      TabOrder = 1
      OnClick = BrowseClick
    end
    object ScanButton: TButton
      Left = 608
      Top = 13
      Width = 120
      Height = 27
      Caption = 'Dosyalari Tara'
      TabOrder = 2
      OnClick = ScanClick
    end
    object StopButton: TButton
      Left = 736
      Top = 13
      Width = 92
      Height = 27
      Caption = 'Taramayi Durdur'
      Enabled = False
      TabOrder = 3
      OnClick = StopClick
    end
    object DeleteButton: TButton
      Left = 840
      Top = 13
      Width = 100
      Height = 27
      Caption = 'Dosyayi Sil'
      TabOrder = 4
      OnClick = DeleteClick
    end
    object SearchEdit: TEdit
      Left = 16
      Top = 46
      Width = 350
      Height = 21
      TabOrder = 4
      TextHint = 'Dosya adinda ara...'
      OnChange = SearchChange
    end
    object SortBox: TComboBox
      Left = 376
      Top = 46
      Width = 154
      Height = 21
      Style = csDropDownList
      ItemIndex = 0
      TabOrder = 5
      Text = 'En yeni'
      OnChange = SortChange
      Items.Strings = (
        'En yeni'
        'Dosya adi'
        'Boyut'
        'Uzanti')
    end
    object ViewBox: TComboBox
      Left = 540
      Top = 46
      Width = 130
      Height = 21
      Style = csDropDownList
      ItemIndex = 0
      TabOrder = 6
      Text = 'Liste'
      OnChange = ViewChange
      Items.Strings = (
        'Liste'
        'Kucuk resim izgara')
    end
    object FilterBox: TComboBox
      Left = 680
      Top = 46
      Width = 150
      Height = 21
      Style = csDropDownList
      ItemIndex = 0
      TabOrder = 7
      Text = 'Medya ve PDF'
      OnChange = FilterChange
      Items.Strings = (
        'Medya ve PDF'
        'Tum dosyalar'
        'Resimler'
        'Videolar'
        'PDF'
        'Ses dosyalari')
    end
    object ClickModeBox: TComboBox
      Left = 840
      Top = 46
      Width = 130
      Height = 21
      Style = csDropDownList
      ItemIndex = 0
      TabOrder = 8
      Text = 'Cift tikla ac'
      OnChange = ClickModeChange
      Items.Strings = (
        'Cift tikla ac'
        'Tek tikla ac')
    end
    object FolderGroupBox: TComboBox
      Left = 980
      Top = 46
      Width = 180
      Height = 21
      Style = csDropDownList
      ItemIndex = 0
      TabOrder = 9
      Text = 'Duz liste'
      OnChange = FolderGroupChange
      Items.Strings = (
        'Duz liste'
        'Alt klasore gore grupla')
    end
  end
  object FileAreaPanel: TPanel
    Left = 0
    Top = 104
    Width = 1180
    Height = 656
    Align = alClient
    BevelInner = bvLowered
    BevelOuter = bvRaised
    BevelWidth = 2
    Color = $00C7D2DC
    ParentBackground = False
    TabOrder = 1
    object FileList: TListView
      Left = 3
      Top = 3
      Width = 1174
      Height = 650
      Align = alClient
      Columns = <
        item
          Caption = 'Dosya adi'
          Width = 320
        end
        item
          Caption = 'Uzanti'
          Width = 90
        end
        item
          Caption = 'Boyut'
          Width = 105
        end
        item
          Caption = 'Son degisiklik'
          Width = 150
        end
        item
          Caption = 'Klasor'
          Width = 220
        end
        item
          Caption = 'Tam yol'
          Width = 360
        end>
      BorderStyle = bsNone
      Color = clWhite
      LargeImages = ThumbnailImages
      OwnerData = True
      ReadOnly = True
      RowSelect = True
      TabOrder = 0
      ViewStyle = vsReport
      OnClick = FileListClick
      OnData = FileListData
      OnDblClick = FileListDblClick
      OnMouseEnter = FileListMouseEnter
    end
  end
  object StatusPanel: TPanel
    Left = 0
    Top = 732
    Width = 1180
    Height = 28
    Align = alBottom
    BevelInner = bvLowered
    BevelOuter = bvRaised
    BevelWidth = 1
    Color = $00E6EDF3
    ParentBackground = False
    TabOrder = 2
    object StatusLabel: TLabel
      Left = 12
      Top = 7
      Width = 1000
      Height = 13
      Caption = 'Medya veya PDF klasoru secin.'
      Font.Color = $00435463
      Font.Style = [fsBold]
      ParentFont = False
    end
    object AnimationBox: TComboBox
      Left = 1000
      Top = 2
      Width = 168
      Height = 24
      Style = csDropDownList
      ItemIndex = 1
      TabOrder = 0
      Text = 'Kademeli yukleme'
      OnChange = ThumbnailAnimationChange
      Items.Strings = (
        'Anlik yukleme'
        'Kademeli yukleme'
        'Dalga yukleme'
        'Soldan saga kay'
        'Sagdan sola kay'
        'Fade in'
        'Fade out')
    end
    object AnimationDurationBox: TComboBox
      Left = 892
      Top = 2
      Width = 100
      Height = 24
      Style = csDropDownList
      ItemIndex = 1
      TabOrder = 1
      Text = '250 ms'
      OnChange = AnimationDurationChange
      Items.Strings = (
        '120 ms'
        '250 ms'
        '450 ms'
        '700 ms')
    end
    object AnimationDistanceBox: TComboBox
      Left = 784
      Top = 2
      Width = 100
      Height = 24
      Style = csDropDownList
      ItemIndex = 1
      TabOrder = 2
      Text = 'Normal'
      OnChange = AnimationDistanceChange
      Items.Strings = (
        'Yakin'
        'Normal'
        'Uzak'
        'Cok uzak')
    end
    object BackgroundColorBox: TColorBox
      Left = 676
      Top = 2
      Width = 100
      Height = 24
      Selected = $00D9E2EA
      Style = [cbStandardColors, cbExtendedColors, cbCustomColor]
      TabOrder = 3
      OnChange = BackgroundColorChange
    end

  end
  object SearchTimer: TTimer
    Enabled = False
    Interval = 250
    OnTimer = SearchTimerTick
    Left = 1104
    Top = 272
  end
  object ScanTimer: TTimer
    Enabled = False
    Interval = 60
    OnTimer = ScanTimerTick
    Left = 1016
    Top = 280
  end
  object ThumbnailTimer: TTimer
    Enabled = False
    Interval = 30
    OnTimer = ThumbnailTimerTick
    Left = 904
    Top = 280
  end
  object ThumbnailEffectTimer: TTimer
    Enabled = False
    Interval = 16
    OnTimer = ThumbnailEffectTimerTick
    Left = 824
    Top = 280
  end
  object MonitorTimer: TTimer
    Enabled = False
    Interval = 30000
    OnTimer = MonitorTimerTick
    Left = 896
    Top = 200
  end
  object ThumbnailImages: TImageList
    ColorDepth = cd32Bit
    Height = 120
    Width = 160
    Left = 1016
    Top = 208
  end
  object ThumbnailStagingImages: TImageList
    ColorDepth = cd32Bit
    Height = 120
    Width = 160
    Left = 1112
    Top = 200
  end
end
