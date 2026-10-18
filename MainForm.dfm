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
    object SearchEdit: TEdit
      Left = 16
      Top = 46
      Width = 350
      Height = 23
      TabOrder = 3
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
      TabOrder = 4
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
      TabOrder = 5
      Text = 'Liste'
      OnChange = ViewChange
      Items.Strings = (
        'Liste'
        'Kucuk simgeler')
    end
    object StatusLabel: TLabel
      Left = 690
      Top = 49
      Width = 234
      Height = 13
      Caption = 'Bir klasor secip dosyalari tarayin.'
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
    ReadOnly = True
    RowSelect = True
    TabOrder = 1
    ViewStyle = vsReport
    OnDblClick = FileListDblClick
  end
  object SearchTimer: TTimer
    Enabled = False
    Interval = 250
    OnTimer = SearchTimerTick
    Left = 1040
    Top = 16
  end
  object RenderTimer: TTimer
    Enabled = False
    Interval = 15
    OnTimer = RenderTimerTick
    Left = 1080
    Top = 16
  end
end
