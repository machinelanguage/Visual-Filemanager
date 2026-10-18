unit MainForm;

interface

uses
  Winapi.Windows, Winapi.ShellAPI, System.SysUtils, System.Classes,
  System.Generics.Collections, System.Generics.Defaults, System.SyncObjs,
  Vcl.Controls,
  Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ComCtrls, Vcl.Dialogs;

type
  TFileEntry = record
    FullName: string;
    DisplayName: string;
    Extension: string;
    Size: Int64;
    ModifiedAt: TDateTime;
  end;

  TFileScanWorker = class(TThread)
  private
    FRootFolder: string;
    FItems: TList<TFileEntry>;
    FLock: TCriticalSection;
    FReadPosition: Integer;
    FCompleted: Boolean;
    procedure ScanFolder(const AFolder: string);
    procedure AddFile(const AFileName: string; const ASearch: TSearchRec);
  protected
    procedure Execute; override;
  public
    constructor Create(const ARootFolder: string);
    destructor Destroy; override;
    function TakeBatch(const ADestination: TList<TFileEntry>;
      const AMaximum: Integer): Integer;
    function IsCompleted: Boolean;
  end;

  TFrmVisualFileManager = class(TForm)
    ToolPanel: TPanel;
    FolderEdit: TEdit;
    BrowseButton: TButton;
    ScanButton: TButton;
    SearchEdit: TEdit;
    SortBox: TComboBox;
    ViewBox: TComboBox;
    StatusLabel: TLabel;
    FileList: TListView;
    SearchTimer: TTimer;
    ScanTimer: TTimer;
    procedure BrowseClick(Sender: TObject);
    procedure ScanClick(Sender: TObject);
    procedure SearchChange(Sender: TObject);
    procedure SearchTimerTick(Sender: TObject);
    procedure SortChange(Sender: TObject);
    procedure ViewChange(Sender: TObject);
    procedure ScanTimerTick(Sender: TObject);
    procedure FileListData(Sender: TObject; Item: TListItem);
    procedure FileListDblClick(Sender: TObject);
  private
    FFiles: TList<TFileEntry>;
    FScanWorker: TFileScanWorker;
    FVisibleItems: TList<Integer>;
    procedure Render;
    procedure AddVisibleFile(const AIndex: Integer);
    function FileSizeText(const ASize: Int64): string;
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

constructor TFileScanWorker.Create(const ARootFolder: string);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FRootFolder := ARootFolder;
  FItems := TList<TFileEntry>.Create;
  FLock := TCriticalSection.Create;
  FReadPosition := 0;
  FCompleted := False;
end;

destructor TFileScanWorker.Destroy;
begin
  FLock.Free;
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
  FLock.Acquire;
  try
    FItems.Add(Item);
  finally
    FLock.Release;
  end;
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
  try
    ScanFolder(FRootFolder);
  finally
    FLock.Acquire;
    try
      FCompleted := True;
    finally
      FLock.Release;
    end;
  end;
end;

function TFileScanWorker.TakeBatch(const ADestination: TList<TFileEntry>;
  const AMaximum: Integer): Integer;
var
  I, Available: Integer;
begin
  Result := 0;
  FLock.Acquire;
  try
    Available := FItems.Count - FReadPosition;
    Result := Min(AMaximum, Available);
    for I := 0 to Result - 1 do
      ADestination.Add(FItems[FReadPosition + I]);
    Inc(FReadPosition, Result);
  finally
    FLock.Release;
  end;
end;

function TFileScanWorker.IsCompleted: Boolean;
begin
  FLock.Acquire;
  try
    Result := FCompleted and (FReadPosition = FItems.Count);
  finally
    FLock.Release;
  end;
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
begin
  Application.CreateForm(TFrmVisualFileManager, FrmVisualFileManager);
end;

constructor TFrmVisualFileManager.Create(AOwner: TComponent);
begin
  inherited;
  FFiles := TList<TFileEntry>.Create;
  FVisibleItems := TList<Integer>.Create;
  FolderEdit.Text := TPath.GetDocumentsPath;
  FileList.OwnerData := True;
end;

destructor TFrmVisualFileManager.Destroy;
begin
  ScanTimer.Enabled := False;
  SearchTimer.Enabled := False;
  if Assigned(FScanWorker) then
  begin
    FScanWorker.Terminate;
    FScanWorker.WaitFor;
    FScanWorker.Free;
  end;
  FVisibleItems.Free;
  FFiles.Free;
  inherited;
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
    FScanWorker.Terminate;
    StatusLabel.Caption := 'Onceki tarama durduruluyor...';
    Exit;
  end;
  if not DirectoryExists(FolderEdit.Text) then
  begin
    ShowMessage('Gecerli bir klasor secin.');
    Exit;
  end;
  ScanTimer.Enabled := False;
  SearchTimer.Enabled := False;
  FileList.Items.Count := 0;
  FFiles.Clear;
  FVisibleItems.Clear;
  StatusLabel.Caption := 'Dosyalar arka planda taraniyor...';
  FScanWorker := TFileScanWorker.Create(FolderEdit.Text);
  FScanWorker.Start;
  ScanTimer.Enabled := True;
end;

procedure TFrmVisualFileManager.ScanTimerTick(Sender: TObject);
var
  PreviousCount, Added: Integer;
begin
  if not Assigned(FScanWorker) then
  begin
    ScanTimer.Enabled := False;
    Exit;
  end;
  PreviousCount := FFiles.Count;
  Added := FScanWorker.TakeBatch(FFiles, 250);
  if (Added > 0) and (Trim(SearchEdit.Text) = '') and
    (SortBox.ItemIndex = 0) then
  begin
    while PreviousCount < FFiles.Count do
    begin
      AddVisibleFile(PreviousCount);
      Inc(PreviousCount);
    end;
    FileList.Items.Count := FVisibleItems.Count;
  end;
  StatusLabel.Caption := Format('%d dosya tarandi...', [FFiles.Count]);
  if FScanWorker.IsCompleted then
  begin
    ScanTimer.Enabled := False;
    FScanWorker.WaitFor;
    FScanWorker.Free;
    FScanWorker := nil;
    Render;
  end;
end;

procedure TFrmVisualFileManager.SearchChange(Sender: TObject);
begin
  SearchTimer.Enabled := False;
  SearchTimer.Enabled := True;
end;

procedure TFrmVisualFileManager.SearchTimerTick(Sender: TObject);
begin
  SearchTimer.Enabled := False;
  if Assigned(FScanWorker) then
    StatusLabel.Caption := 'Arama tarama tamamlandiginda uygulanacak.'
  else
    Render;
end;

procedure TFrmVisualFileManager.SortChange(Sender: TObject);
begin
  if Assigned(FScanWorker) then
    StatusLabel.Caption := 'Siralama tarama tamamlandiginda uygulanacak.'
  else
    Render;
end;

procedure TFrmVisualFileManager.ViewChange(Sender: TObject);
begin
  if ViewBox.ItemIndex = 1 then
    FileList.ViewStyle := vsIcon
  else
    FileList.ViewStyle := vsReport;
end;

procedure TFrmVisualFileManager.AddVisibleFile(const AIndex: Integer);
begin
  FVisibleItems.Add(AIndex);
end;

procedure TFrmVisualFileManager.Render;
var
  I: Integer;
  Query: string;
begin
  CurrentSort := SortBox.ItemIndex;
  FFiles.Sort(TComparer<TFileEntry>.Construct(CompareEntries));
  FVisibleItems.Clear;
  Query := Trim(SearchEdit.Text);
  for I := 0 to FFiles.Count - 1 do
    if (Query = '') or ContainsText(FFiles[I].DisplayName, Query) then
      AddVisibleFile(I);
  FileList.Items.Count := FVisibleItems.Count;
  if FVisibleItems.Count = 0 then
    StatusLabel.Caption := 'Dosya bulunamadi.'
  else
    StatusLabel.Caption := Format('%d dosya bulundu.', [FVisibleItems.Count]);
end;

function TFrmVisualFileManager.FileSizeText(const ASize: Int64): string;
begin
  if ASize >= Int64(1024) * 1024 * 1024 then
    Result := FormatFloat('0.00 GB', ASize / (1024 * 1024 * 1024))
  else if ASize >= Int64(1024) * 1024 then
    Result := FormatFloat('0.00 MB', ASize / (1024 * 1024))
  else if ASize >= 1024 then
    Result := FormatFloat('0.00 KB', ASize / 1024)
  else
    Result := IntToStr(ASize) + ' B';
end;

procedure TFrmVisualFileManager.FileListData(Sender: TObject;
  Item: TListItem);
var
  FileIndex: Integer;
  FileEntry: TFileEntry;
begin
  if (Item.Index < 0) or (Item.Index >= FVisibleItems.Count) then
    Exit;
  FileIndex := FVisibleItems[Item.Index];
  FileEntry := FFiles[FileIndex];
  Item.Caption := FileEntry.DisplayName;
  Item.SubItems.Clear;
  Item.SubItems.Add(FileEntry.Extension);
  Item.SubItems.Add(FileSizeText(FileEntry.Size));
  Item.SubItems.Add(DateTimeToStr(FileEntry.ModifiedAt));
  Item.SubItems.Add(FileEntry.FullName);
end;

procedure TFrmVisualFileManager.FileListDblClick(Sender: TObject);
var
  Position, Index: Integer;
begin
  if not Assigned(FileList.Selected) then
    Exit;
  Position := FileList.Selected.Index;
  if (Position < 0) or (Position >= FVisibleItems.Count) then
    Exit;
  Index := FVisibleItems[Position];
  ShellExecute(Handle, 'open', PChar(FFiles[Index].FullName), nil, nil,
    SW_SHOWNORMAL);
end;

end.
