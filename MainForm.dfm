object FrmVisualFileManager: TFrmVisualFileManager
  Left = 0
  Top = 0
  Caption = 'Dosya Yoneticisi'
  ClientHeight = 760
  ClientWidth = 1180
  Color = 16250871
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  Position = poScreenCenter
  PixelsPerInch = 96
  TextHeight = 13
  OnShow = FormShow
  object ToolPanel: TPanel
    Left = 0
    Top = 0
    Width = 1180
    Height = 76
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    object FolderEdit: TEdit
      Left = 16
      Top = 14
      Width = 490
      Height = 25
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
    object SearchEdit: TEdit
      Left = 16
      Top = 46
      Width = 350
      Height = 23
      TabOrder = 4
      TextHint = 'Dosya adinda ara...'
      OnChange = SearchChange
    end
    object SortBox: TComboBox
      Left = 376
      Top = 46
      Width = 154
      Height = 23
      Style = csDropDownList
      ItemIndex = 0
      TabOrder = 5
      Text = 'Dosya adi'
      OnChange = SortChange
      Items.Strings = (
        'Dosya adi'
        'En yeni'
        'Boyut'
        'Uzanti')
    end
    object ViewBox: TComboBox
      Left = 540
      Top = 46
      Width = 130
      Height = 23
      Style = csDropDownList
      ItemIndex = 0
      TabOrder = 6
      Text = 'Liste'
      OnChange = ViewChange
      Items.Strings = (
        'Liste'
        'Kucuk simgeler')
    end
    object FilterBox: TComboBox
      Left = 680
      Top = 46
      Width = 150
      Height = 23
      Style = csDropDownList
      ItemIndex = 0
      TabOrder = 7
      Text = 'Medya ve PDF'
      OnChange = FilterChange
      Items.Strings = (
        'Medya ve PDF'
        'Tum dosyalar')
    end
    object ClickModeBox: TComboBox
      Left = 840
      Top = 46
      Width = 130
      Height = 23
      Style = csDropDownList
      ItemIndex = 0
      TabOrder = 8
      Text = 'Cift tikla ac'
      OnChange = ClickModeChange
      Items.Strings = (
        'Cift tikla ac'
        'Tek tikla ac')
    end
    object StatusLabel: TLabel
      Left = 980
      Top = 49
      Width = 234
      Height = 13
      Caption = 'Medya veya PDF klasoru secin.'
    end
  end
  object FileList: TListView
    Left = 0
    Top = 76
    Width = 1180
    Height = 684
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
        Caption = 'Tam yol'
        Width = 480
      end>
    LargeImages = ThumbnailImages
    OwnerData = True
    ReadOnly = True
    RowSelect = True
    TabOrder = 1
    ViewStyle = vsReport
    OnClick = FileListClick
    OnData = FileListData
    OnDblClick = FileListDblClick
    OnMouseEnter = FileListMouseEnter
  end
  object SearchTimer: TTimer
    Enabled = False
    Interval = 250
    OnTimer = SearchTimerTick
    Left = 1040
    Top = 16
  end
  object ScanTimer: TTimer
    Enabled = False
    Interval = 60
    OnTimer = ScanTimerTick
    Left = 1080
    Top = 16
  end
  object ThumbnailTimer: TTimer
    Enabled = False
    Interval = 30
    OnTimer = ThumbnailTimerTick
    Left = 1120
    Top = 16
  end
  object ThumbnailImages: TImageList
    ColorDepth = cd32Bit
    Height = 120
    Width = 160
    Left = 1040
    Top = 48
  end
  object ThumbnailStagingImages: TImageList
    ColorDepth = cd32Bit
    Height = 120
    Width = 160
    Left = 1080
    Top = 48
  end
end
