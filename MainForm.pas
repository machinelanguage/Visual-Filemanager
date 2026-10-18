unit MainForm;

interface

uses
  Winapi.Windows, Winapi.ShellAPI, System.SysUtils, System.Classes,
  System.Generics.Collections, System.Generics.Defaults, Vcl.Controls,
  Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.Graphics, Vcl.Dialogs;

type
  TFileEntry = record
    FullName: string;
    DisplayName: string;
    Extension: string;
    Size: Int64;
    ModifiedAt: TDateTime;
  end;

  TFrmVisualFileManager = class(TForm)
  private
    FFiles: TList<TFileEntry>;
    FScanWorker: TThread;
    FRenderItems: TList<Integer>;
    FRenderTimer: TTimer;
    FSearchTimer: TTimer;
    FListLimit: Integer;
    FIconLimit: Integer;
    FRenderPosition: Integer;
    FRenderLimit: Integer;
    FRenderTop: Integer;
    FRenderColumn: Integer;
    FRenderRow: Integer;
    FRenderColumnCount: Integer;
    ToolPanel: TPanel;
    Cards: TScrollBox;
    FolderEdit: TEdit;
    SearchEdit: TEdit;
    SortBox: TComboBox;
    ViewBox: TComboBox;
    StatusLabel: TLabel;
    procedure BuildUi;
    procedure BrowseClick(Sender: TObject);
    procedure ScanClick(Sender: TObject);
    procedure ScanWorkerDone(Sender: TObject);
    procedure SearchChange(Sender: TObject);
    procedure SearchTimerTick(Sender: TObject);
    procedure SortChange(Sender: TObject);
    procedure ViewChange(Sender: TObject);
    procedure RenderTimerTick(Sender: TObject);
    procedure LoadMoreClick(Sender: TObject);
    procedure CardClick(Sender: TObject);
    procedure Render;
    procedure AddListCard(const AFile: TFileEntry; const AIndex,
      ATop: Integer);
    procedure AddIconCard(const AFile: TFileEntry; const AIndex, ALeft,
      ATop: Integer);
    procedure AddLoadMoreButton(const ATop, ARemaining: Integer);
    function ExtensionColor(const AExtension: string): TColor;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

procedure CreateVisualFileManager;

implementation

uses
  System.IOUtils, System.StrUtils, System.Math, Vcl.FileCtrl;

{$R *.dfm}

var
  CurrentSort: Integer;

type
  TFileScanWorker = class(TThread)
  private
    FRootFolder: string;
    FItems: TList<TFileEntry>;
    procedure ScanFolder(const AFolder: string);
    procedure AddFile(const AFileName: string; const ASearch: TSearchRec);
  protected
    procedure Execute; override;
  public
    constructor Create(const ARootFolder: string);
    destructor Destroy; override;
    property Items: TList<TFileEntry> read FItems;
  end;

constructor TFileScanWorker.Create(const ARootFolder: string);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FRootFolder := ARootFolder;
  FItems := TList<TFileEntry>.Create;
end;

destructor TFileScanWorker.Destroy;
begin
  FItems.Free;
  inherited;
end;

procedure TFileScanWorker.AddFile(const AFileName: string;
  const ASearch: TSearchRec);
var
  Item: TFileEntry;
begin
  if Terminated then
    Exit;
  Item.FullName := AFileName;
  Item.DisplayName := ExtractFileName(AFileName);
  Item.Extension := LowerCase(ExtractFileExt(AFileName));
  Item.Size := Int64(ASearch.Size);
  Item.ModifiedAt := FileDateToDateTime(ASearch.Time);
  FItems.Add(Item);
end;

procedure TFileScanWorker.ScanFolder(const AFolder: string);
var
  Search: TSearchRec;
  Path: string;
begin
  if Terminated then
    Exit;
  if FindFirst(IncludeTrailingPathDelimiter(AFolder) + '*', faAnyFile,
    Search) <> 0 then
    Exit;
  try
    repeat
      if Terminated then
        Exit;
      if (Search.Name <> '.') and (Search.Name <> '..') then
      begin
        Path := IncludeTrailingPathDelimiter(AFolder) + Search.Name;
        if (Search.Attr and faDirectory) <> 0 then
        begin
          if (Search.Attr and FILE_ATTRIBUTE_REPARSE_POINT) = 0 then
            ScanFolder(Path);
        end
        else
          AddFile(Path, Search);
      end;
    until FindNext(Search) <> 0;
  finally
    FindClose(Search);
  end;
end;

procedure TFileScanWorker.Execute;
begin
  ScanFolder(FRootFolder);
end;

function CompareEntries(const Left, Right: TFileEntry): Integer;
begin
  case CurrentSort of
    1: Result := CompareValue(Right.ModifiedAt, Left.ModifiedAt);
    2: Result := CompareValue(Right.Size, Left.Size);
    3: Result := CompareText(Left.Extension, Right.Extension);
  else
    Result := CompareText(Left.DisplayName, Right.DisplayName);
  end;
  if Result = 0 then
    Result := CompareText(Left.DisplayName, Right.DisplayName);
end;

procedure CreateVisualFileManager;
var
  Form: TFrmVisualFileManager;
begin
  Application.CreateForm(TFrmVisualFileManager, Form);
end;

constructor TFrmVisualFileManager.Create(AOwner: TComponent);
begin
  inherited;
  FFiles := TList<TFileEntry>.Create;
  FRenderItems := TList<Integer>.Create;
  FListLimit := 100;
  FIconLimit := 80;
  BuildUi;
end;

destructor TFrmVisualFileManager.Destroy;
begin
  FRenderTimer.Enabled := False;
  FSearchTimer.Enabled := False;
  if Assigned(FScanWorker) then
  begin
    FScanWorker.OnTerminate := nil;
    FScanWorker.Terminate;
    FScanWorker.WaitFor;
    FScanWorker.Free;
  end;
  FRenderItems.Free;
  FFiles.Free;
  inherited;
end;

procedure TFrmVisualFileManager.BuildUi;
var
  Button: TButton;
begin
  Caption := 'Dosya Yoneticisi';
  Width := 1180;
  Height := 760;
  Position := poScreenCenter;
  Color := $00F7F7F7;

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
  Button.Caption := 'Klasor Sec';
  Button.SetBounds(514, 13, 86, 27);
  Button.OnClick := BrowseClick;

  Button := TButton.Create(Self);
  Button.Parent := ToolPanel;
  Button.Caption := 'Dosyalari Tara';
  Button.SetBounds(608, 13, 120, 27);
  Button.OnClick := ScanClick;

  SearchEdit := TEdit.Create(Self);
  SearchEdit.Parent := ToolPanel;
  SearchEdit.SetBounds(16, 46, 350, 23);
  SearchEdit.TextHint := 'Dosya adinda ara...';
  SearchEdit.OnChange := SearchChange;

  SortBox := TComboBox.Create(Self);
  SortBox.Parent := ToolPanel;
  SortBox.SetBounds(376, 46, 154, 23);
  SortBox.Style := csDropDownList;
  SortBox.Items.Add('Dosya adi');
  SortBox.Items.Add('En yeni');
  SortBox.Items.Add('Boyut');
  SortBox.Items.Add('Uzanti');
  SortBox.ItemIndex := 0;
  SortBox.OnChange := SortChange;

  ViewBox := TComboBox.Create(Self);
  ViewBox.Parent := ToolPanel;
  ViewBox.SetBounds(540, 46, 130, 23);
  ViewBox.Style := csDropDownList;
  ViewBox.Items.Add('Liste');
  ViewBox.Items.Add('Kucuk simgeler');
  ViewBox.ItemIndex := 0;
  ViewBox.OnChange := ViewChange;

  StatusLabel := TLabel.Create(Self);
  StatusLabel.Parent := ToolPanel;
  StatusLabel.SetBounds(690, 49, 460, 18);
  StatusLabel.Caption := 'Bir klasor secip dosyalari tarayin.';

  Cards := TScrollBox.Create(Self);
  Cards.Parent := Self;
  Cards.Align := alClient;
  Cards.Color := $00F7F7F7;
  Cards.VertScrollBar.Tracking := True;

  FSearchTimer := TTimer.Create(Self);
  FSearchTimer.Interval := 250;
  FSearchTimer.OnTimer := SearchTimerTick;

  FRenderTimer := TTimer.Create(Self);
  FRenderTimer.Interval := 15;
  FRenderTimer.OnTimer := RenderTimerTick;
end;

procedure TFrmVisualFileManager.BrowseClick(Sender: TObject);
var
  Folder: string;
begin
  Folder := FolderEdit.Text;
  if SelectDirectory('Taranacak klasoru secin', '', Folder) then
    FolderEdit.Text := Folder;
end;

procedure TFrmVisualFileManager.ScanClick(Sender: TObject);
begin
  if Assigned(FScanWorker) then
  begin
    StatusLabel.Caption := 'Tarama arka planda devam ediyor.';
    Exit;
  end;
  if not DirectoryExists(FolderEdit.Text) then
  begin
    ShowMessage('Gecerli bir klasor secin.');
    Exit;
  end;
  FRenderTimer.Enabled := False;
  FFiles.Clear;
  FRenderItems.Clear;
  while Cards.ControlCount > 0 do
    Cards.Controls[0].Free;
  StatusLabel.Caption := 'Dosyalar arka planda taraniyor...';
  FScanWorker := TFileScanWorker.Create(FolderEdit.Text);
  FScanWorker.OnTerminate := ScanWorkerDone;
  FScanWorker.Start;
end;

procedure TFrmVisualFileManager.ScanWorkerDone(Sender: TObject);
var
  Worker: TFileScanWorker;
  I: Integer;
begin
  Worker := TFileScanWorker(Sender);
  FScanWorker := nil;
  for I := 0 to Worker.Items.Count - 1 do
    FFiles.Add(Worker.Items[I]);
  Worker.Free;
  Render;
end;

procedure TFrmVisualFileManager.SearchChange(Sender: TObject);
begin
  FSearchTimer.Enabled := False;
  FSearchTimer.Enabled := True;
end;

procedure TFrmVisualFileManager.SearchTimerTick(Sender: TObject);
begin
  FSearchTimer.Enabled := False;
  if not Assigned(FScanWorker) then
    Render;
end;

procedure TFrmVisualFileManager.SortChange(Sender: TObject);
begin
  if not Assigned(FScanWorker) then
    Render;
end;

procedure TFrmVisualFileManager.ViewChange(Sender: TObject);
begin
  if ViewBox.ItemIndex = 1 then
    FIconLimit := 80
  else
    FListLimit := 100;
  Render;
end;

procedure TFrmVisualFileManager.Render;
var
  I: Integer;
  Item: TFileEntry;
  Query: string;
begin
  FRenderTimer.Enabled := False;
  CurrentSort := SortBox.ItemIndex;
  FFiles.Sort(TComparer<TFileEntry>.Construct(CompareEntries));
  FRenderItems.Clear;
  Query := Trim(SearchEdit.Text);
  for I := 0 to FFiles.Count - 1 do
  begin
    Item := FFiles[I];
    if (Query = '') or ContainsText(Item.DisplayName, Query) then
      FRenderItems.Add(I);
  end;
  while Cards.ControlCount > 0 do
    Cards.Controls[0].Free;
  if ViewBox.ItemIndex = 1 then
    FRenderLimit := Min(FIconLimit, FRenderItems.Count)
  else
    FRenderLimit := Min(FListLimit, FRenderItems.Count);
  FRenderPosition := 0;
  FRenderTop := 12;
  FRenderColumn := 0;
  FRenderRow := 0;
  FRenderColumnCount := Max(1, (Cards.ClientWidth - 28) div 206);
  StatusLabel.Caption := Format('%d dosya bulundu. Gosteriliyor...',
    [FFiles.Count]);
  if FRenderLimit = 0 then
    RenderTimerTick(FRenderTimer)
  else
    FRenderTimer.Enabled := True;
end;

function TFrmVisualFileManager.ExtensionColor(
  const AExtension: string): TColor;
var
  Value: Cardinal;
  I: Integer;
begin
  Value := 2166136261;
  for I := 1 to Length(AExtension) do
  begin
    Value := Value xor Ord(AExtension[I]);
    Value := Value * 16777619;
  end;
  Result := RGB(70 + (Value and $5F), 70 + ((Value shr 8) and $5F),
    70 + ((Value shr 16) and $5F));
end;

procedure TFrmVisualFileManager.AddListCard(const AFile: TFileEntry;
  const AIndex, ATop: Integer);
var
  Card, Accent: TPanel;
  NameLabel, DetailLabel: TLabel;
begin
  Card := TPanel.Create(Self);
  Card.Parent := Cards;
  Card.SetBounds(14, ATop, Cards.ClientWidth - 34, 72);
  Card.Anchors := [akLeft, akTop, akRight];
  Card.BevelOuter := bvNone;
  Card.Color := clWhite;
  Card.Tag := AIndex;
  Card.OnClick := CardClick;

  Accent := TPanel.Create(Self);
  Accent.Parent := Card;
  Accent.SetBounds(0, 0, 7, Card.Height);
  Accent.BevelOuter := bvNone;
  Accent.Color := ExtensionColor(AFile.Extension);
  Accent.Tag := AIndex;
  Accent.OnClick := CardClick;

  NameLabel := TLabel.Create(Self);
  NameLabel.Parent := Card;
  NameLabel.SetBounds(20, 10, Card.Width - 32, 18);
  NameLabel.Font.Style := [fsBold];
  NameLabel.Caption := AFile.DisplayName;
  NameLabel.Tag := AIndex;
  NameLabel.OnClick := CardClick;

  DetailLabel := TLabel.Create(Self);
  DetailLabel.Parent := Card;
  DetailLabel.SetBounds(20, 34, Card.Width - 32, 18);
  DetailLabel.Font.Color := clGray;
  DetailLabel.Caption := Format('%s  |  %s  |  %d KB',
    [AFile.Extension, DateTimeToStr(AFile.ModifiedAt), AFile.Size div 1024]);
  DetailLabel.Tag := AIndex;
  DetailLabel.OnClick := CardClick;
end;

procedure TFrmVisualFileManager.AddIconCard(const AFile: TFileEntry;
  const AIndex, ALeft, ATop: Integer);
var
  Card, IconPanel: TPanel;
  TypeLabel, NameLabel, DetailLabel: TLabel;
begin
  Card := TPanel.Create(Self);
  Card.Parent := Cards;
  Card.SetBounds(ALeft, ATop, 190, 156);
  Card.BevelOuter := bvNone;
  Card.Color := clWhite;
  Card.Tag := AIndex;
  Card.OnClick := CardClick;

  IconPanel := TPanel.Create(Self);
  IconPanel.Parent := Card;
  IconPanel.SetBounds(12, 12, 166, 58);
  IconPanel.BevelOuter := bvNone;
  IconPanel.Color := ExtensionColor(AFile.Extension);
  IconPanel.Tag := AIndex;
  IconPanel.OnClick := CardClick;

  TypeLabel := TLabel.Create(Self);
  TypeLabel.Parent := IconPanel;
  TypeLabel.SetBounds(0, 15, IconPanel.Width, 24);
  TypeLabel.Alignment := taCenter;
  TypeLabel.Font.Color := clWhite;
  TypeLabel.Font.Style := [fsBold];
  TypeLabel.Font.Size := 14;
  TypeLabel.Caption := UpperCase(Copy(AFile.Extension, 2, 8));
  if TypeLabel.Caption = '' then
    TypeLabel.Caption := 'DOSYA';
  TypeLabel.Tag := AIndex;
  TypeLabel.OnClick := CardClick;

  NameLabel := TLabel.Create(Self);
  NameLabel.Parent := Card;
  NameLabel.SetBounds(12, 78, 166, 38);
  NameLabel.AutoSize := False;
  NameLabel.WordWrap := True;
  NameLabel.Font.Style := [fsBold];
  NameLabel.Caption := AFile.DisplayName;
  NameLabel.Tag := AIndex;
  NameLabel.OnClick := CardClick;

  DetailLabel := TLabel.Create(Self);
  DetailLabel.Parent := Card;
  DetailLabel.SetBounds(12, 124, 166, 17);
  DetailLabel.Font.Color := clGray;
  DetailLabel.Caption := IntToStr(AFile.Size div 1024) + ' KB';
  DetailLabel.Tag := AIndex;
  DetailLabel.OnClick := CardClick;
end;

procedure TFrmVisualFileManager.RenderTimerTick(Sender: TObject);
var
  Added, Index, LeftPos: Integer;
begin
  FRenderTimer.Enabled := False;
  Added := 0;
  while (FRenderPosition < FRenderLimit) and (Added < 20) do
  begin
    Index := FRenderItems[FRenderPosition];
    if ViewBox.ItemIndex = 1 then
    begin
      LeftPos := 14 + (FRenderColumn * 206);
      AddIconCard(FFiles[Index], Index, LeftPos, 12 + (FRenderRow * 172));
      Inc(FRenderColumn);
      if FRenderColumn >= FRenderColumnCount then
      begin
        FRenderColumn := 0;
        Inc(FRenderRow);
      end;
    end
    else
    begin
      AddListCard(FFiles[Index], Index, FRenderTop);
      Inc(FRenderTop, 84);
    end;
    Inc(FRenderPosition);
    Inc(Added);
  end;
  if FRenderPosition < FRenderLimit then
  begin
    FRenderTimer.Enabled := True;
    Exit;
  end;
  if FRenderItems.Count > FRenderLimit then
    if ViewBox.ItemIndex = 1 then
      AddLoadMoreButton(12 + ((FRenderRow + 1) * 172),
        FRenderItems.Count - FRenderLimit)
    else
      AddLoadMoreButton(FRenderTop, FRenderItems.Count - FRenderLimit);
  StatusLabel.Caption := Format('%d dosya bulundu.', [FFiles.Count]);
end;

procedure TFrmVisualFileManager.AddLoadMoreButton(const ATop,
  ARemaining: Integer);
var
  Button: TButton;
begin
  Button := TButton.Create(Self);
  Button.Parent := Cards;
  Button.SetBounds(14, ATop, 200, 30);
  Button.Caption := IntToStr(ARemaining) + ' dosya daha yukle';
  Button.OnClick := LoadMoreClick;
end;

procedure TFrmVisualFileManager.LoadMoreClick(Sender: TObject);
begin
  if ViewBox.ItemIndex = 1 then
    Inc(FIconLimit, 80)
  else
    Inc(FListLimit, 100);
  Render;
end;

procedure TFrmVisualFileManager.CardClick(Sender: TObject);
var
  Index: Integer;
begin
  Index := TControl(Sender).Tag;
  if (Index < 0) or (Index >= FFiles.Count) then
    Exit;
  ShellExecute(Handle, 'open', PChar(FFiles[Index].FullName), nil, nil,
    SW_SHOWNORMAL);
end;

end.
