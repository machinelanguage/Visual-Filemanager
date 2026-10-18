unit MainForm;

interface

uses
  Winapi.Windows, Winapi.ShellAPI, System.SysUtils, System.Classes,
  System.Generics.Collections, System.Generics.Defaults, Vcl.Controls,
  Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ComCtrls, Vcl.Dialogs;

type
  TFileEntry = record
    FullName: string;
    DisplayName: string;
    Extension: string;
    Size: Int64;
    ModifiedAt: TDateTime;
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
    RenderTimer: TTimer;
    procedure BrowseClick(Sender: TObject);
    procedure ScanClick(Sender: TObject);
    procedure SearchChange(Sender: TObject);
    procedure SearchTimerTick(Sender: TObject);
    procedure SortChange(Sender: TObject);
    procedure ViewChange(Sender: TObject);
    procedure RenderTimerTick(Sender: TObject);
    procedure FileListDblClick(Sender: TObject);
  private
    FFiles: TList<TFileEntry>;
    FScanWorker: TThread;
    FVisibleItems: TList<Integer>;
    FRenderPosition: Integer;
    procedure ScanWorkerDone(Sender: TObject);
    procedure Render;
    procedure AddFileListItem(const AIndex: Integer);
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
begin
  Application.CreateForm(TFrmVisualFileManager, FrmVisualFileManager);
end;

constructor TFrmVisualFileManager.Create(AOwner: TComponent);
begin
  inherited;
  FFiles := TList<TFileEntry>.Create;
  FVisibleItems := TList<Integer>.Create;
  FolderEdit.Text := TPath.GetDocumentsPath;
end;

destructor TFrmVisualFileManager.Destroy;
begin
  RenderTimer.Enabled := False;
  SearchTimer.Enabled := False;
  if Assigned(FScanWorker) then
  begin
    FScanWorker.OnTerminate := nil;
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
    StatusLabel.Caption := 'Tarama arka planda devam ediyor.';
    Exit;
  end;
  if not DirectoryExists(FolderEdit.Text) then
  begin
    ShowMessage('Gecerli bir klasor secin.');
    Exit;
  end;
  RenderTimer.Enabled := False;
  FileList.Items.Clear;
  FFiles.Clear;
  FVisibleItems.Clear;
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
  SearchTimer.Enabled := False;
  SearchTimer.Enabled := True;
end;

procedure TFrmVisualFileManager.SearchTimerTick(Sender: TObject);
begin
  SearchTimer.Enabled := False;
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
    FileList.ViewStyle := vsIcon
  else
    FileList.ViewStyle := vsReport;
  Render;
end;

procedure TFrmVisualFileManager.Render;
var
  I: Integer;
  Query: string;
begin
  RenderTimer.Enabled := False;
  CurrentSort := SortBox.ItemIndex;
  FFiles.Sort(TComparer<TFileEntry>.Construct(CompareEntries));
  FVisibleItems.Clear;
  Query := Trim(SearchEdit.Text);
  for I := 0 to FFiles.Count - 1 do
    if (Query = '') or ContainsText(FFiles[I].DisplayName, Query) then
      FVisibleItems.Add(I);
  FileList.Items.Clear;
  FRenderPosition := 0;
  StatusLabel.Caption := Format('%d dosya bulundu. Listeleniyor...',
    [FVisibleItems.Count]);
  if FVisibleItems.Count = 0 then
    StatusLabel.Caption := 'Dosya bulunamadi.'
  else
    RenderTimer.Enabled := True;
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

procedure TFrmVisualFileManager.AddFileListItem(const AIndex: Integer);
var
  Item: TListItem;
  FileEntry: TFileEntry;
begin
  FileEntry := FFiles[AIndex];
  Item := FileList.Items.Add;
  Item.Caption := FileEntry.DisplayName;
  Item.SubItems.Add(FileEntry.Extension);
  Item.SubItems.Add(FileSizeText(FileEntry.Size));
  Item.SubItems.Add(DateTimeToStr(FileEntry.ModifiedAt));
  Item.SubItems.Add(FileEntry.FullName);
end;

procedure TFrmVisualFileManager.RenderTimerTick(Sender: TObject);
var
  Added: Integer;
begin
  RenderTimer.Enabled := False;
  Added := 0;
  FileList.Items.BeginUpdate;
  try
    while (FRenderPosition < FVisibleItems.Count) and (Added < 150) do
    begin
      AddFileListItem(FVisibleItems[FRenderPosition]);
      Inc(FRenderPosition);
      Inc(Added);
    end;
  finally
    FileList.Items.EndUpdate;
  end;
  if FRenderPosition < FVisibleItems.Count then
    RenderTimer.Enabled := True
  else
    StatusLabel.Caption := Format('%d dosya bulundu.', [FVisibleItems.Count]);
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
