unit MainForm;

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes, System.Types,
  System.Generics.Collections, System.Generics.Defaults, Vcl.Controls, Vcl.Forms, Vcl.StdCtrls,
  Vcl.ComCtrls, Vcl.ExtCtrls, Vcl.Graphics, Vcl.Dialogs, TopicClassifier;

type
  TFrmVisualFileManager = class(TForm)
  private
    FFiles: TList<TManagedFile>;
    FRootFolder: string;
    ToolPanel: TPanel;
    TopicTree: TTreeView;
    Cards: TScrollBox;
    FolderEdit: TEdit;
    SearchEdit: TEdit;
    SortBox: TComboBox;
    StatusLabel: TLabel;
    procedure BuildUi;
    procedure BrowseClick(Sender: TObject);
    procedure ScanClick(Sender: TObject);
    procedure SearchChange(Sender: TObject);
    procedure SortChange(Sender: TObject);
    procedure ScanFolder(const AFolder: string);
    procedure AddFile(const AFileName: string);
    procedure Render;
    procedure AddCard(const AFile: TManagedFile; const ATop: Integer);
    function TopicColor(const ATopic: string): TColor;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

procedure CreateVisualFileManager;

var
  FrmVisualFileManager: TFrmVisualFileManager;

implementation

uses
  System.IOUtils, System.StrUtils, System.Math, Vcl.FileCtrl;

{$R *.dfm}

var
  CurrentSort: Integer;

procedure CreateVisualFileManager;
begin
  Application.CreateForm(TFrmVisualFileManager, FrmVisualFileManager);
end;

constructor TFrmVisualFileManager.Create(AOwner: TComponent);
begin
  inherited;
  FFiles := TList<TManagedFile>.Create;
  BuildUi;
end;

destructor TFrmVisualFileManager.Destroy;
begin
  FFiles.Free;
  inherited;
end;

procedure TFrmVisualFileManager.BuildUi;
var
  Button: TButton;
begin
  Caption := 'Konusal Dosya Yöneticisi';
  Width := 1200;
  Height := 760;
  Color := $00F7F7F7;
  Position := poScreenCenter;
  ToolPanel := TPanel.Create(Self);
  ToolPanel.Parent := Self;
  ToolPanel.Align := alTop;
  ToolPanel.Height := 76;
  ToolPanel.BevelOuter := bvNone;
  FolderEdit := TEdit.Create(Self);
  FolderEdit.Parent := ToolPanel;
  FolderEdit.SetBounds(16, 14, 490, 25);
  FolderEdit.Text := TPath.GetDocumentsPath;
  Button := TButton.Create(Self);
  Button.Parent := ToolPanel;
  Button.Caption := 'Klasör Seç';
  Button.SetBounds(514, 13, 86, 27);
  Button.OnClick := BrowseClick;
  Button := TButton.Create(Self);
  Button.Parent := ToolPanel;
  Button.Caption := 'Tara ve Sınıflandır';
  Button.SetBounds(608, 13, 142, 27);
  Button.OnClick := ScanClick;
  SearchEdit := TEdit.Create(Self);
  SearchEdit.Parent := ToolPanel;
  SearchEdit.SetBounds(16, 46, 350, 23);
  SearchEdit.TextHint := 'Dosya veya içerikte ara...';
  SearchEdit.OnChange := SearchChange;
  SortBox := TComboBox.Create(Self);
  SortBox.Parent := ToolPanel;
  SortBox.SetBounds(376, 46, 174, 23);
  SortBox.Style := csDropDownList;
  SortBox.Items.Add('Konu, sonra ad');
  SortBox.Items.Add('Dosya adı');
  SortBox.Items.Add('En yeni');
  SortBox.Items.Add('Boyut');
  SortBox.ItemIndex := 0;
  SortBox.OnChange := SortChange;
  StatusLabel := TLabel.Create(Self);
  StatusLabel.Parent := ToolPanel;
  StatusLabel.SetBounds(570, 49, 520, 18);
  StatusLabel.Caption := 'Bir klasör seçip taramayı başlatın.';
  TopicTree := TTreeView.Create(Self);
  TopicTree.Parent := Self;
  TopicTree.Align := alLeft;
  TopicTree.Width := 190;
  TopicTree.ReadOnly := True;
  Cards := TScrollBox.Create(Self);
  Cards.Parent := Self;
  Cards.Align := alClient;
  Cards.Color := $00F7F7F7;
  Cards.VertScrollBar.Tracking := True;
end;

procedure TFrmVisualFileManager.BrowseClick(Sender: TObject);
var
  Folder: string;
begin
  Folder := FolderEdit.Text;
  if SelectDirectory('Taranacak klasörü seçin', '', Folder) then
    FolderEdit.Text := Folder;
end;

procedure TFrmVisualFileManager.AddFile(const AFileName: string);
var
  Item: TManagedFile;
  Info: TWin32FileAttributeData;
begin
  Item.FullName := AFileName;
  Item.DisplayName := ExtractFileName(AFileName);
  Item.Extension := LowerCase(ExtractFileExt(AFileName));
  if GetFileAttributesEx(PChar(AFileName), GetFileExInfoStandard, @Info) then
  begin
    Item.Size := (Int64(Info.nFileSizeHigh) shl 32) + Info.nFileSizeLow;
    Item.ModifiedAt := FileDateToDateTime(FileAge(AFileName));
  end
  else
  begin
    Item.Size := 0;
    Item.ModifiedAt := 0;
  end;
  Item.Preview := ReadIndexableText(AFileName);
  Item.Topic := ClassifyFile(AFileName, Item.Preview, Item.Confidence);
  FFiles.Add(Item);
end;

procedure TFrmVisualFileManager.ScanFolder(const AFolder: string);
var
  Search: TSearchRec;
  Path: string;
begin
  if FindFirst(IncludeTrailingPathDelimiter(AFolder) + '*', faAnyFile, Search) = 0 then
  try
    repeat
      if (Search.Name <> '.') and (Search.Name <> '..') then
      begin
        Path := IncludeTrailingPathDelimiter(AFolder) + Search.Name;
        if (Search.Attr and faDirectory) <> 0 then
        begin
          if (Search.Attr and FILE_ATTRIBUTE_REPARSE_POINT) = 0 then
            ScanFolder(Path);
        end
        else
          AddFile(Path);
      end;
    until FindNext(Search) <> 0;
  finally
    FindClose(Search);
  end;
end;

procedure TFrmVisualFileManager.ScanClick(Sender: TObject);
begin
  if not DirectoryExists(FolderEdit.Text) then
  begin
    ShowMessage('Geçerli bir klasör seçin.');
    Exit;
  end;
  Screen.Cursor := crHourGlass;
  try
    FFiles.Clear;
    FRootFolder := FolderEdit.Text;
    ScanFolder(FRootFolder);
    Render;
  finally
    Screen.Cursor := crDefault;
  end;
end;

function CompareFiles(const Left, Right: TManagedFile): Integer;
begin
  case CurrentSort of
    1: Result := CompareText(Left.DisplayName, Right.DisplayName);
    2: Result := CompareValue(Right.ModifiedAt, Left.ModifiedAt);
    3: Result := CompareValue(Right.Size, Left.Size);
  else
    begin
      Result := CompareText(Left.Topic, Right.Topic);
      if Result = 0 then
        Result := CompareText(Left.DisplayName, Right.DisplayName);
    end;
  end;
end;

procedure TFrmVisualFileManager.Render;
var
  I, TopPos: Integer;
  Node: TTreeNode;
  Item: TManagedFile;
  Query: string;
begin
  CurrentSort := SortBox.ItemIndex;
  FFiles.Sort(TComparer<TManagedFile>.Construct(CompareFiles));
  TopicTree.Items.BeginUpdate;
  try
    TopicTree.Items.Clear;
    for I := 0 to FFiles.Count - 1 do
    begin
      Node := TopicTree.Items.GetFirstNode;
      while (Node <> nil) and not SameText(Node.Text, FFiles[I].Topic) do
        Node := Node.GetNextSibling;
      if Node = nil then
        TopicTree.Items.Add(nil, FFiles[I].Topic);
    end;
  finally
    TopicTree.Items.EndUpdate;
  end;
  while Cards.ControlCount > 0 do Cards.Controls[0].Free;
  TopPos := 12;
  Query := LowerCase(Trim(SearchEdit.Text));
  for I := 0 to FFiles.Count - 1 do
  begin
    Item := FFiles[I];
    if (Query = '') or ContainsText(LowerCase(Item.DisplayName), Query) or
      ContainsText(LowerCase(Item.Preview), Query) then
    begin
      AddCard(Item, TopPos);
      Inc(TopPos, 95);
    end;
  end;
  StatusLabel.Caption := Format('%d dosya bulundu. İçerik indekslenen biçimler: TXT, PDF, DOCX.',
    [FFiles.Count]);
end;

function TFrmVisualFileManager.TopicColor(const ATopic: string): TColor;
begin
  if ATopic = 'Finans' then Result := $004EA3F1
  else if ATopic = 'Hukuk' then Result := $007A55C2
  else if ATopic = 'Projeler' then Result := $0038A169
  else if ATopic = 'Medya' then Result := $003D8CFF
  else if ATopic = 'Kişisel' then Result := $00805AD5
  else Result := $00808080;
end;

procedure TFrmVisualFileManager.AddCard(const AFile: TManagedFile; const ATop: Integer);
var
  Card, Badge: TPanel;
  NameLabel, DetailLabel, PreviewLabel: TLabel;
begin
  Card := TPanel.Create(Self);
  Card.Parent := Cards;
  Card.SetBounds(14, ATop, Cards.ClientWidth - 34, 78);
  Card.Anchors := [akLeft, akTop, akRight];
  Card.BevelOuter := bvNone;
  Card.Color := clWhite;
  Badge := TPanel.Create(Self);
  Badge.Parent := Card;
  Badge.SetBounds(0, 0, 8, Card.Height);
  Badge.Color := TopicColor(AFile.Topic);
  Badge.BevelOuter := bvNone;
  NameLabel := TLabel.Create(Self);
  NameLabel.Parent := Card;
  NameLabel.SetBounds(20, 10, Card.Width - 30, 18);
  NameLabel.Font.Style := [fsBold];
  NameLabel.Caption := AFile.DisplayName + '   [' + AFile.Topic + ']';
  DetailLabel := TLabel.Create(Self);
  DetailLabel.Parent := Card;
  DetailLabel.SetBounds(20, 31, Card.Width - 30, 16);
  DetailLabel.Font.Color := clGray;
  DetailLabel.Caption := Format('%s  |  %s  |  %d KB  |  güven: %d',
    [AFile.Extension, DateTimeToStr(AFile.ModifiedAt), AFile.Size div 1024,
    AFile.Confidence]);
  PreviewLabel := TLabel.Create(Self);
  PreviewLabel.Parent := Card;
  PreviewLabel.SetBounds(20, 51, Card.Width - 30, 16);
  PreviewLabel.Font.Color := $00606060;
  PreviewLabel.Caption := Copy(AFile.Preview, 1, 150);
end;

procedure TFrmVisualFileManager.SearchChange(Sender: TObject);
begin
  Render;
end;

procedure TFrmVisualFileManager.SortChange(Sender: TObject);
begin
  Render;
end;

end.
