unit MainForm;

interface

uses
  Winapi.Windows, Winapi.ShellAPI, System.SysUtils, System.Classes, System.Types,
  System.Generics.Collections, System.Generics.Defaults, Vcl.Controls, Vcl.Forms, Vcl.StdCtrls,
  Vcl.ComCtrls, Vcl.ExtCtrls, Vcl.Graphics, Vcl.Dialogs, TopicClassifier,
  TopicCatalog;

type
  TFrmVisualFileManager = class(TForm)
  private
    FFiles: TList<TManagedFile>;
    FCatalog: TTopicCatalog;
    FRootFolder: string;
    FThumbnailFolder: string;
    FThumbnailQueue: TList<Integer>;
    FThumbnailWorker: TThread;
    FThumbnailLimit: Integer;
    FUpdatingCategories: Boolean;
    FFlipPhase: Boolean;
    ToolPanel: TPanel;
    TopicTree: TTreeView;
    Cards: TScrollBox;
    FolderEdit: TEdit;
    SearchEdit: TEdit;
    SortBox: TComboBox;
    CategoryBox: TComboBox;
    ViewBox: TComboBox;
    StatusLabel: TLabel;
    FlipTimer: TTimer;
    procedure BuildUi;
    procedure BrowseClick(Sender: TObject);
    procedure ScanClick(Sender: TObject);
    procedure SearchChange(Sender: TObject);
    procedure SortChange(Sender: TObject);
    procedure CategoryChange(Sender: TObject);
    procedure ViewChange(Sender: TObject);
    procedure LoadMoreThumbnailsClick(Sender: TObject);
    procedure QueueThumbnail(const AIndex: Integer);
    procedure StartNextThumbnail;
    procedure ThumbnailWorkerDone(Sender: TObject);
    procedure ShowThumbnail(const AIndex: Integer; const AFileName: string);
    procedure CardClick(Sender: TObject);
    procedure FlipTimerTick(Sender: TObject);
    procedure ScanFolder(const AFolder: string);
    procedure AddFile(const AFileName: string);
    procedure Render;
    procedure AddCard(const AFile: TManagedFile; const AIndex, ATop: Integer);
    procedure AddThumbnail(const AFile: TManagedFile; const AIndex, ALeft,
      ATop: Integer);
    procedure AddLoadMoreButton(const ATop, ARemaining: Integer);
    procedure UpdateCategoryBox;
    function TopicColor(const ATopic: string): TColor;
    function AlternateTopicColor(const ATopic: string): TColor;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

procedure CreateVisualFileManager;

var
  FrmVisualFileManager: TFrmVisualFileManager;

implementation

uses
  System.IOUtils, System.StrUtils, System.Math, Vcl.FileCtrl, ThumbnailSupport;

{$R *.dfm}

var
  CurrentSort: Integer;

type
  TThumbnailWorker = class(TThread)
  private
    FIndex: Integer;
    FFileName: string;
    FTopic: string;
    FCacheFile: string;
    FSuccess: Boolean;
  protected
    procedure Execute; override;
  public
    constructor Create(const AIndex: Integer; const AFileName, ATopic,
      ACacheFile: string);
    property Index: Integer read FIndex;
    property FileName: string read FFileName;
    property CacheFile: string read FCacheFile;
    property Success: Boolean read FSuccess;
  end;

constructor TThumbnailWorker.Create(const AIndex: Integer; const AFileName,
  ATopic, ACacheFile: string);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FIndex := AIndex;
  FFileName := AFileName;
  FTopic := ATopic;
  FCacheFile := ACacheFile;
end;

procedure TThumbnailWorker.Execute;
begin
  if not Terminated then
    FSuccess := CreateThumbnailFile(FFileName, FTopic, FCacheFile);
end;

procedure CreateVisualFileManager;
begin
  Application.CreateForm(TFrmVisualFileManager, FrmVisualFileManager);
end;

constructor TFrmVisualFileManager.Create(AOwner: TComponent);
begin
  inherited;
  FFiles := TList<TManagedFile>.Create;
  FThumbnailQueue := TList<Integer>.Create;
  FThumbnailLimit := 80;
  FCatalog := TTopicCatalog.Create;
  BuildUi;
  if DirectoryExists(FCatalog.LastFolder) then
  begin
    FolderEdit.Text := FCatalog.LastFolder;
    ScanClick(nil);
  end;
end;

destructor TFrmVisualFileManager.Destroy;
begin
  if Assigned(FThumbnailWorker) then
  begin
    FThumbnailWorker.OnTerminate := nil;
    FThumbnailWorker.Terminate;
    FThumbnailWorker.WaitFor;
    FThumbnailWorker.Free;
  end;
  FThumbnailQueue.Free;
  FCatalog.Free;
  FFiles.Free;
  inherited;
end;

procedure TFrmVisualFileManager.BuildUi;
var
  Button: TButton;
begin
  Caption := 'Konusal Dosya Y'#246'neticisi';
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
  Button.Caption := 'Klas'#246'r Se'#231;
  Button.SetBounds(514, 13, 86, 27);
  Button.OnClick := BrowseClick;
  Button := TButton.Create(Self);
  Button.Parent := ToolPanel;
  Button.Caption := 'Tara ve S'#305'n'#305'fland'#305'r';
  Button.SetBounds(608, 13, 142, 27);
  Button.OnClick := ScanClick;
  SearchEdit := TEdit.Create(Self);
  SearchEdit.Parent := ToolPanel;
  SearchEdit.SetBounds(16, 46, 350, 23);
  SearchEdit.TextHint := 'Dosya veya i'#231'erikte ara...';
  SearchEdit.OnChange := SearchChange;
  SortBox := TComboBox.Create(Self);
  SortBox.Parent := ToolPanel;
  SortBox.SetBounds(376, 46, 174, 23);
  SortBox.Style := csDropDownList;
  SortBox.Items.Add('Konu, sonra ad');
  SortBox.Items.Add('Dosya ad'#305);
  SortBox.Items.Add('En yeni');
  SortBox.Items.Add('Boyut');
  SortBox.ItemIndex := 0;
  SortBox.OnChange := SortChange;
  CategoryBox := TComboBox.Create(Self);
  CategoryBox.Parent := ToolPanel;
  CategoryBox.SetBounds(560, 46, 190, 23);
  CategoryBox.Style := csDropDownList;
  CategoryBox.OnChange := CategoryChange;
  CategoryBox.Items.Add('T'#252'm Kategoriler');
  CategoryBox.ItemIndex := 0;
  ViewBox := TComboBox.Create(Self);
  ViewBox.Parent := ToolPanel;
  ViewBox.SetBounds(760, 46, 130, 23);
  ViewBox.Style := csDropDownList;
  ViewBox.Items.Add('Liste');
  ViewBox.Items.Add('Kucuk resimler');
  ViewBox.ItemIndex := 0;
  ViewBox.OnChange := ViewChange;
  StatusLabel := TLabel.Create(Self);
  StatusLabel.Parent := ToolPanel;
  StatusLabel.SetBounds(900, 49, 280, 18);
  StatusLabel.ShowHint := True;
  StatusLabel.Hint := 'Katalog: ' + FCatalog.CatalogFileName;
  StatusLabel.Caption := 'Bir klas'#246'r se'#231'ip taramay'#305' ba'#351'lat'#305'n.';
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
  FlipTimer := TTimer.Create(Self);
  FlipTimer.Interval := 550;
  FlipTimer.OnTimer := FlipTimerTick;
end;

procedure TFrmVisualFileManager.BrowseClick(Sender: TObject);
var
  Folder: string;
begin
  Folder := FolderEdit.Text;
  if SelectDirectory('Taranacak klas'#246'r'#252' se'#231'in', '', Folder) then
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
  if IsIndexable(AFileName) and not CanReadIndexableFile(AFileName) then
  begin
    Item.Preview := #304#231'erik okunamad'#305': bulut dosyas'#305'n'#305' '#231'evrimd'#305#351#305' kullan'#305'labilir yap'#305'n.';
    Item.Topic := 'Bulut Dosyas'#305' Haz'#305'r De'#287'il';
    Item.Summary := 'Konu: ' + Item.Topic + #13#10 +
      #214'zet: Dosya bulut saglayicisindan indirilemedi.' + #13#10 +
      'Detay: Dosyayi cevrimdisi kullanilabilir yapin.';
    Item.Confidence := 0;
    FFiles.Add(Item);
    Exit;
  end;
  Item.Preview := ReadIndexableText(AFileName);
  if not FCatalog.TryGetTopic(Item.FullName, Item.Size, Item.ModifiedAt,
    Item.Topic, Item.Confidence) then
  begin
    Item.Topic := ClassifyFile(AFileName, Item.Preview, Item.Confidence);
    FCatalog.SaveTopic(Item.FullName, Item.Size, Item.ModifiedAt, Item.Topic,
      Item.Confidence);
  end;
  if Item.Extension = '.pdf' then
    Item.Summary := BuildThreeLineSummary(Item.Topic, Item.Preview)
  else
    Item.Summary := Copy(Item.Preview, 1, 250);
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
          if SameText(ExcludeTrailingPathDelimiter(Path),
            ExcludeTrailingPathDelimiter(FThumbnailFolder)) then
            Continue;
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
    ShowMessage('Ge'#231'erli bir klas'#246'r se'#231'in.');
    Exit;
  end;
  Screen.Cursor := crHourGlass;
  try
    FFiles.Clear;
    FThumbnailQueue.Clear;
    FThumbnailLimit := 80;
    FThumbnailFolder := TPath.Combine(FolderEdit.Text, 'thumbnail');
    ForceDirectories(FThumbnailFolder);
    FRootFolder := FolderEdit.Text;
    FCatalog.SetLastFolder(FRootFolder);
    ScanFolder(FRootFolder);
    FCatalog.Save;
    Render;
  finally
    Screen.Cursor := crDefault;
  end;
end;

procedure TFrmVisualFileManager.UpdateCategoryBox;
var
  Categories: TStringList;
  I, OldIndex: Integer;
  OldTopic: string;
begin
  OldIndex := CategoryBox.ItemIndex;
  OldTopic := CategoryBox.Text;
  Categories := TStringList.Create;
  try
    Categories.Sorted := True;
    Categories.Duplicates := dupIgnore;
    for I := 0 to FFiles.Count - 1 do
      Categories.Add(FFiles[I].Topic);
    FUpdatingCategories := True;
    try
      CategoryBox.Items.BeginUpdate;
      try
        CategoryBox.Items.Clear;
        CategoryBox.Items.Add('T'#252'm Kategoriler');
        CategoryBox.Items.AddStrings(Categories);
        OldIndex := CategoryBox.Items.IndexOf(OldTopic);
        if OldIndex < 0 then
          OldIndex := 0;
        CategoryBox.ItemIndex := OldIndex;
      finally
        CategoryBox.Items.EndUpdate;
      end;
    finally
      FUpdatingCategories := False;
    end;
  finally
    Categories.Free;
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
  I, TopPos, LeftPos, Column, Row, ColumnCount, MatchCount, ShownCount: Integer;
  Node: TTreeNode;
  Item: TManagedFile;
  Query, TopicFilter: string;
begin
  CurrentSort := SortBox.ItemIndex;
  FFiles.Sort(TComparer<TManagedFile>.Construct(CompareFiles));
  UpdateCategoryBox;
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
  Column := 0;
  Row := 0;
  MatchCount := 0;
  ShownCount := 0;
  ColumnCount := Max(1, (Cards.ClientWidth - 28) div 206);
  Query := LowerCase(Trim(SearchEdit.Text));
  TopicFilter := CategoryBox.Text;
  for I := 0 to FFiles.Count - 1 do
  begin
    Item := FFiles[I];
    if ((CategoryBox.ItemIndex = 0) or SameText(Item.Topic, TopicFilter)) and
      ((Query = '') or ContainsText(LowerCase(Item.DisplayName), Query) or
      ContainsText(LowerCase(Item.Preview), Query)) then
    begin
      Inc(MatchCount);
      if (ViewBox.ItemIndex = 1) and (ShownCount >= FThumbnailLimit) then
        Continue;
      if ViewBox.ItemIndex = 1 then
      begin
        LeftPos := 14 + (Column * 206);
        TopPos := 12 + (Row * 190);
        AddThumbnail(Item, I, LeftPos, TopPos);
        Inc(Column);
        if Column >= ColumnCount then
        begin
          Column := 0;
          Inc(Row);
        end;
      end
      else
      begin
        AddCard(Item, I, TopPos);
        Inc(TopPos, 132);
      end;
      Inc(ShownCount);
    end;
  end;
  if (ViewBox.ItemIndex = 1) and (MatchCount > ShownCount) then
    AddLoadMoreButton(12 + ((Row + 1) * 190), MatchCount - ShownCount);
  StatusLabel.Caption := Format('%d dosya bulundu. Katalog: %s',
    [FFiles.Count, FCatalog.CatalogFileName]);
end;

function TFrmVisualFileManager.TopicColor(const ATopic: string): TColor;
begin
  if ATopic = 'Bulut Dosyas'#305' Haz'#305'r De'#287'il' then Result := $006B7280
  else if ATopic = 'E'#287'itim ve '#214#287'retim' then Result := $00A1662F
  else if ATopic = 'G'#305'da ve Tarifler' then Result := $0038A8A0
  else if ATopic = 'E-Ticaret ve Lojistik' then Result := $00D97706
  else if ATopic = 'OCR Bekliyor' then Result := $006B7280
  else if ATopic = 'Finans' then Result := $004EA3F1
  else if ATopic = 'Hukuk' then Result := $007A55C2
  else if ATopic = 'Projeler' then Result := $0038A169
  else if ATopic = 'Medya' then Result := $003D8CFF
  else if ATopic = 'Ki'#351'isel' then Result := $00805AD5
  else Result := $00808080;
end;

function TFrmVisualFileManager.AlternateTopicColor(const ATopic: string): TColor;
var
  Base: TColor;
begin
  Base := ColorToRGB(TopicColor(ATopic));
  Result := RGB((GetRValue(Base) + 255) div 2, (GetGValue(Base) + 255) div 2,
    (GetBValue(Base) + 255) div 2);
end;

procedure TFrmVisualFileManager.AddCard(const AFile: TManagedFile;
  const AIndex, ATop: Integer);
var
  Card, Badge: TPanel;
  NameLabel, DetailLabel, SummaryLabel: TLabel;
begin
  Card := TPanel.Create(Self);
  Card.Parent := Cards;
  Card.SetBounds(14, ATop, Cards.ClientWidth - 34, 116);
  Card.Anchors := [akLeft, akTop, akRight];
  Card.BevelOuter := bvNone;
  Card.Color := clWhite;
  Card.Tag := AIndex;
  Card.OnClick := CardClick;
  Badge := TPanel.Create(Self);
  Badge.Parent := Card;
  Badge.SetBounds(0, 0, 8, Card.Height);
  Badge.Color := TopicColor(AFile.Topic);
  Badge.BevelOuter := bvNone;
  Badge.Tag := AIndex;
  Badge.Hint := 'FlipBadge';
  Badge.OnClick := CardClick;
  NameLabel := TLabel.Create(Self);
  NameLabel.Parent := Card;
  NameLabel.SetBounds(20, 10, Card.Width - 30, 18);
  NameLabel.Font.Style := [fsBold];
  NameLabel.Caption := AFile.DisplayName + '   [' + AFile.Topic + ']';
  NameLabel.Tag := AIndex;
  NameLabel.OnClick := CardClick;
  DetailLabel := TLabel.Create(Self);
  DetailLabel.Parent := Card;
  DetailLabel.SetBounds(20, 31, Card.Width - 30, 16);
  DetailLabel.Font.Color := clGray;
  DetailLabel.Caption := Format('%s  |  %s  |  %d KB  |  g'#252'ven: %d',
    [AFile.Extension, DateTimeToStr(AFile.ModifiedAt), AFile.Size div 1024,
    AFile.Confidence]);
  DetailLabel.Tag := AIndex;
  DetailLabel.OnClick := CardClick;
  SummaryLabel := TLabel.Create(Self);
  SummaryLabel.Parent := Card;
  SummaryLabel.SetBounds(20, 51, Card.Width - 30, 55);
  SummaryLabel.Font.Color := $00606060;
  SummaryLabel.AutoSize := False;
  SummaryLabel.WordWrap := True;
  SummaryLabel.Caption := AFile.Summary;
  SummaryLabel.Tag := AIndex;
  SummaryLabel.OnClick := CardClick;
end;

procedure TFrmVisualFileManager.AddThumbnail(const AFile: TManagedFile;
  const AIndex, ALeft, ATop: Integer);
var
  Card, Badge, PreviewBox: TPanel;
  TypeLabel, NameLabel, TopicLabel, SummaryLabel: TLabel;
  ThumbImage: TImage;
  CacheFile: string;
begin
  Card := TPanel.Create(Self);
  Card.Parent := Cards;
  Card.SetBounds(ALeft, ATop, 190, 174);
  Card.BevelOuter := bvNone;
  Card.Color := clWhite;
  Card.Tag := AIndex;
  Card.OnClick := CardClick;
  Badge := TPanel.Create(Self);
  Badge.Parent := Card;
  Badge.SetBounds(0, 0, Card.Width, 6);
  Badge.Color := TopicColor(AFile.Topic);
  Badge.BevelOuter := bvNone;
  Badge.Tag := AIndex;
  Badge.Hint := 'FlipBadge';
  Badge.OnClick := CardClick;
  PreviewBox := TPanel.Create(Self);
  PreviewBox.Parent := Card;
  PreviewBox.SetBounds(12, 18, 166, 64);
  PreviewBox.BevelOuter := bvNone;
  PreviewBox.Color := AlternateTopicColor(AFile.Topic);
  PreviewBox.Tag := AIndex;
  PreviewBox.OnClick := CardClick;
  TypeLabel := TLabel.Create(Self);
  TypeLabel.Parent := PreviewBox;
  TypeLabel.SetBounds(0, 15, PreviewBox.Width, 30);
  TypeLabel.Alignment := taCenter;
  TypeLabel.Font.Style := [fsBold];
  TypeLabel.Font.Size := 16;
  TypeLabel.Caption := UpperCase(Copy(AFile.Extension, 2, 8));
  TypeLabel.Tag := AIndex;
  TypeLabel.Hint := 'ThumbnailType';
  TypeLabel.OnClick := CardClick;
  CacheFile := ThumbnailCacheFileName(FThumbnailFolder, AFile.FullName,
    AFile.Size, AFile.ModifiedAt);
  ThumbImage := TImage.Create(Self);
  ThumbImage.Parent := PreviewBox;
  ThumbImage.Align := alClient;
  ThumbImage.Stretch := True;
  ThumbImage.Proportional := True;
  ThumbImage.Tag := AIndex;
  ThumbImage.Hint := 'ThumbnailImage';
  ThumbImage.OnClick := CardClick;
  ThumbImage.Visible := False;
  if FileExists(CacheFile) then
  begin
    try
      ThumbImage.Picture.LoadFromFile(CacheFile);
      ThumbImage.Visible := True;
      TypeLabel.Visible := False;
    except
      QueueThumbnail(AIndex);
    end;
  end
  else
    QueueThumbnail(AIndex);
  NameLabel := TLabel.Create(Self);
  NameLabel.Parent := Card;
  NameLabel.SetBounds(12, 90, 166, 32);
  NameLabel.AutoSize := False;
  NameLabel.WordWrap := True;
  NameLabel.Font.Style := [fsBold];
  NameLabel.Caption := AFile.DisplayName;
  NameLabel.Tag := AIndex;
  NameLabel.OnClick := CardClick;
  TopicLabel := TLabel.Create(Self);
  TopicLabel.Parent := Card;
  TopicLabel.SetBounds(12, 124, 166, 16);
  TopicLabel.Font.Color := TopicColor(AFile.Topic);
  TopicLabel.Caption := AFile.Topic;
  TopicLabel.Tag := AIndex;
  TopicLabel.OnClick := CardClick;
  SummaryLabel := TLabel.Create(Self);
  SummaryLabel.Parent := Card;
  SummaryLabel.SetBounds(12, 143, 166, 25);
  SummaryLabel.AutoSize := False;
  SummaryLabel.WordWrap := True;
  SummaryLabel.Font.Color := clGray;
  SummaryLabel.Caption := Copy(StringReplace(AFile.Summary, sLineBreak, ' ',
    [rfReplaceAll]), 1, 74);
  SummaryLabel.Tag := AIndex;
  SummaryLabel.OnClick := CardClick;
end;

procedure TFrmVisualFileManager.AddLoadMoreButton(const ATop,
  ARemaining: Integer);
var
  Button: TButton;
begin
  Button := TButton.Create(Self);
  Button.Parent := Cards;
  Button.SetBounds(14, ATop, 190, 30);
  Button.Caption := IntToStr(ARemaining) + ' dosya daha yukle';
  Button.OnClick := LoadMoreThumbnailsClick;
end;

procedure TFrmVisualFileManager.QueueThumbnail(const AIndex: Integer);
begin
  if (AIndex < 0) or (AIndex >= FFiles.Count) then
    Exit;
  if FThumbnailQueue.IndexOf(AIndex) < 0 then
    FThumbnailQueue.Add(AIndex);
  StartNextThumbnail;
end;

procedure TFrmVisualFileManager.StartNextThumbnail;
var
  Index: Integer;
  CacheFile: string;
begin
  if Assigned(FThumbnailWorker) or (FThumbnailQueue.Count = 0) then
    Exit;
  Index := FThumbnailQueue[0];
  FThumbnailQueue.Delete(0);
  if (Index < 0) or (Index >= FFiles.Count) then
  begin
    StartNextThumbnail;
    Exit;
  end;
  CacheFile := ThumbnailCacheFileName(FThumbnailFolder, FFiles[Index].FullName,
    FFiles[Index].Size, FFiles[Index].ModifiedAt);
  if FileExists(CacheFile) then
  begin
    ShowThumbnail(Index, CacheFile);
    StartNextThumbnail;
    Exit;
  end;
  FThumbnailWorker := TThumbnailWorker.Create(Index, FFiles[Index].FullName,
    FFiles[Index].Topic, CacheFile);
  FThumbnailWorker.OnTerminate := ThumbnailWorkerDone;
  FThumbnailWorker.Start;
end;

procedure TFrmVisualFileManager.ThumbnailWorkerDone(Sender: TObject);
var
  Worker: TThumbnailWorker;
begin
  Worker := TThumbnailWorker(Sender);
  FThumbnailWorker := nil;
  if Worker.Success and (Worker.Index >= 0) and (Worker.Index < FFiles.Count) and
    SameText(FFiles[Worker.Index].FullName, Worker.FileName) then
    ShowThumbnail(Worker.Index, Worker.CacheFile);
  Worker.Free;
  StartNextThumbnail;
end;

procedure TFrmVisualFileManager.ShowThumbnail(const AIndex: Integer;
  const AFileName: string);
var
  I, J, K: Integer;
  Card: TWinControl;
  Control: TControl;
begin
  for I := 0 to Cards.ControlCount - 1 do
  begin
    Card := TWinControl(Cards.Controls[I]);
    for J := 0 to Card.ControlCount - 1 do
      if Card.Controls[J] is TPanel then
        for K := 0 to TWinControl(Card.Controls[J]).ControlCount - 1 do
        begin
          Control := TWinControl(Card.Controls[J]).Controls[K];
          if (Control is TImage) and (Control.Tag = AIndex) and
            (Control.Hint = 'ThumbnailImage') then
          begin
            try
              TImage(Control).Picture.LoadFromFile(AFileName);
              TImage(Control).Visible := True;
            except
              TImage(Control).Visible := False;
            end;
          end
          else if (Control is TLabel) and (Control.Tag = AIndex) and
            (Control.Hint = 'ThumbnailType') then
            TLabel(Control).Visible := False;
        end;
  end;
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

procedure TFrmVisualFileManager.FlipTimerTick(Sender: TObject);
var
  I, J, Index: Integer;
  Card: TWinControl;
  Control: TControl;
begin
  if ViewBox.ItemIndex = 1 then
    Exit;
  FFlipPhase := not FFlipPhase;
  for I := 0 to Cards.ControlCount - 1 do
  begin
    Card := TWinControl(Cards.Controls[I]);
    for J := 0 to Card.ControlCount - 1 do
    begin
      Control := Card.Controls[J];
      if (Control is TPanel) and (Control.Hint = 'FlipBadge') then
      begin
        Index := Control.Tag;
        if (Index >= 0) and (Index < FFiles.Count) then
          if FFlipPhase then
            TPanel(Control).Color := TopicColor(FFiles[Index].Topic)
          else
            TPanel(Control).Color := AlternateTopicColor(FFiles[Index].Topic);
      end;
    end;
  end;
end;

procedure TFrmVisualFileManager.SearchChange(Sender: TObject);
begin
  Render;
end;

procedure TFrmVisualFileManager.SortChange(Sender: TObject);
begin
  Render;
end;

procedure TFrmVisualFileManager.CategoryChange(Sender: TObject);
begin
  if not FUpdatingCategories then
    Render;
end;

procedure TFrmVisualFileManager.ViewChange(Sender: TObject);
begin
  if ViewBox.ItemIndex = 1 then
    FThumbnailLimit := 80;
  Render;
end;

procedure TFrmVisualFileManager.LoadMoreThumbnailsClick(Sender: TObject);
begin
  Inc(FThumbnailLimit, 80);
  Render;
end;

end.
