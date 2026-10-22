unit MainForm;

interface

uses
  Winapi.Windows, Winapi.Messages, Winapi.ShellAPI, Winapi.CommCtrl, System.SysUtils,
  System.Classes,
  System.Generics.Collections, System.Generics.Defaults, System.SyncObjs,
  Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ComCtrls,
  Vcl.Dialogs, Vcl.ImgList, System.IniFiles;

type
  TFileTypeFilter = (ftMediaPdf, ftAllFiles, ftImages, ftVideos, ftPdf,
    ftAudio);

  TNotifyInfo = packed record
    NextEntryOffset: DWORD;
    Action: DWORD;
    FileNameLength: DWORD;
    FileName: array[0..0] of WideChar;
  end;
  PNotifyInfo = ^TNotifyInfo;

  TFileEntry = record
    FullName: string;
    DisplayName: string;
    Extension: string;
    FolderName: string;
    Size: Int64;
    ModifiedAt: TDateTime;
  end;

  TFileScanWorker = class(TThread)
  private
    FRootFolder: string;
    FThumbnailFolder: string;
    FFileFilter: TFileTypeFilter;
    FItems: TList<TFileEntry>;
    FLock: TCriticalSection;
    FReadPosition: Integer;
    FCompleted: Boolean;
    procedure ScanFolder(const AFolder: string);
    procedure AddFile(const AFileName: string; const ASearch: TSearchRec);
    function IsIncludedFile(const AFileName: string): Boolean;
  protected
    procedure Execute; override;
  public
    constructor Create(const ARootFolder, AThumbnailFolder: string;
      const AFileFilter: TFileTypeFilter);
    destructor Destroy; override;
    function TakeBatch(const ADestination: TList<TFileEntry>;
      const AMaximum: Integer): Integer;
    function IsCompleted: Boolean;
  end;

  TDirectoryMonitorWorker = class(TThread)
  private
    FRootFolder: string;
    FChanges: TList<string>;
    FChangesLock: TCriticalSection;
    FHandleLock: TCriticalSection;
    FDirectoryHandle: THandle;
    procedure AddChange(const AFileName: string);
  protected
    procedure Execute; override;
  public
    constructor Create(const ARootFolder: string);
    destructor Destroy; override;
    procedure Stop;
    function TakeChanges(const ADestination: TList<string>): Integer;
  end;

  TVideoThumbnailWorker = class(TThread)
  private
    FIndex: Integer;
    FFileName: string;
    FOutputFile: string;
    FSuccess: Boolean;
    FErrorText: string;
  protected
    procedure Execute; override;
  public
    constructor Create(const AIndex: Integer; const AFileName,
      AOutputFile: string);
    function IsFinished: Boolean;
    property Index: Integer read FIndex;
    property FileName: string read FFileName;
    property Success: Boolean read FSuccess;
    property ErrorText: string read FErrorText;
  end;

  TFrmVisualFileManager = class(TForm)
    ToolPanel: TPanel;
    FolderEdit: TEdit;
    BrowseButton: TButton;
    ScanButton: TButton;
    StopButton: TButton;
    ClickModeBox: TComboBox;
    FolderGroupBox: TComboBox;
    SearchEdit: TEdit;
    SortBox: TComboBox;
    ViewBox: TComboBox;
    FilterBox: TComboBox;
    StatusLabel: TLabel;
    FileList: TListView;
    SearchTimer: TTimer;
    ScanTimer: TTimer;
    ThumbnailTimer: TTimer;
    MonitorTimer: TTimer;
    ThumbnailImages: TImageList;
    ThumbnailStagingImages: TImageList;
    procedure FormShow(Sender: TObject);
    procedure BrowseClick(Sender: TObject);
    procedure ScanClick(Sender: TObject);
    procedure StopClick(Sender: TObject);
    procedure ClickModeChange(Sender: TObject);
    procedure FolderGroupChange(Sender: TObject);
    procedure SearchChange(Sender: TObject);
    procedure SearchTimerTick(Sender: TObject);
    procedure SortChange(Sender: TObject);
    procedure ViewChange(Sender: TObject);
    procedure FilterChange(Sender: TObject);
    procedure ScanTimerTick(Sender: TObject);
    procedure ThumbnailTimerTick(Sender: TObject);
    procedure MonitorTimerTick(Sender: TObject);
    procedure FileListData(Sender: TObject; Item: TListItem);
    procedure FileListClick(Sender: TObject);
    procedure FileListMouseEnter(Sender: TObject);
    procedure FileListDblClick(Sender: TObject);
  private
    FFiles: TList<TFileEntry>;
    FScanWorker: TFileScanWorker;
    FVideoWorker: TVideoThumbnailWorker;
    FMonitorWorker: TDirectoryMonitorWorker;
    FVisibleItems: TList<Integer>;
    FThumbnailQueue: TList<Integer>;
    FThumbnailQueuePosition: Integer;
    FThumbnailIndexes: TDictionary<string, Integer>;
    FQueuedThumbnailFiles: TDictionary<string, Boolean>;
    FPlaceholderIndexes: TDictionary<string, Integer>;
    FKnownFiles: TDictionary<string, Boolean>;
    FRootFolder: string;
    FThumbnailFolder: string;
    FThumbnailRefreshCount: Integer;
    FLastThumbnailRefreshTick: Cardinal;
    FThumbnailImagesDirty: Boolean;
    FPendingScanFolder: string;
    FPendingFileFilter: TFileTypeFilter;
    FStartupScanDone: Boolean;
    FLastScanUiTick: Cardinal;
    procedure LoadSettings;
    procedure SaveSettings;
    function SettingsFileName: string;
    procedure RefreshThumbnails(const AForce: Boolean = False);
    procedure PublishThumbnails;
    procedure PreparePlaceholderImages;
    function PlaceholderImageIndex(const AFile: TFileEntry): Integer;
    function PlaceholderKey(const AFile: TFileEntry): string;
    function SelectedFileFilter: TFileTypeFilter;
    procedure StartScan(const AFolder: string;
      const AFileFilter: TFileTypeFilter);
    procedure StartFolderMonitor;
    procedure StopFolderMonitor;
    procedure AddMonitoredFile(const AFileName: string);
    procedure RemoveDuplicateFiles;
    procedure OpenSelectedFile;
    procedure Render;
    procedure AddVisibleFile(const AIndex: Integer);
    procedure SortVisibleByNewest;
    procedure QueueThumbnail(const AIndex: Integer);
    procedure QueueThumbnailPage(const AVisibleIndex: Integer);
    procedure StartVideoThumbnail(const AIndex: Integer);
    procedure CompleteVideoThumbnail;
    function IsVideoFile(const AFile: TFileEntry): Boolean;
    procedure LoadOrCreateThumbnail(const AIndex: Integer);
    procedure RedrawThumbnailItem(const AFileIndex: Integer);
    function FileSizeText(const ASize: Int64): string;
    function ThumbnailFileName(const AFile: TFileEntry): string;
    function HashText(const AValue: string): Cardinal;
    procedure CreateThumbnail(const AFile: TFileEntry; const AOutput: string);
    procedure CreateGenericThumbnail(const AFile: TFileEntry;
      const AOutput: string);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

procedure CreateVisualFileManager;

var
  FrmVisualFileManager: TFrmVisualFileManager;

implementation

uses
  System.IOUtils, System.StrUtils, System.Math, Vcl.FileCtrl, Vcl.Graphics,
  Vcl.Imaging.jpeg, Vcl.Imaging.pngimage, Vcl.Imaging.GIFImg;

{$R *.dfm}

var
  CurrentSort: Integer;
  CurrentGroupByFolder: Boolean;

function CanonicalFileName(const AFileName: string): string;
begin
  Result := LowerCase(ExpandFileName(AFileName));
end;

function FfmpegExecutable: string;
var
  ApplicationFolder, Candidate: string;
begin
  Result := '';
  ApplicationFolder := ExtractFilePath(ParamStr(0));
  Candidate := TPath.Combine(ApplicationFolder, 'ffmpeg.exe');
  if FileExists(Candidate) then
    Result := Candidate
  else
  begin
    Candidate := TPath.Combine(ApplicationFolder, 'ffmpeg\\bin\\ffmpeg.exe');
    if FileExists(Candidate) then
      Result := Candidate;
  end;
end;

function ExtractVideoFrame(const AFileName, AOutputFile: string;
  out AErrorText: string): Boolean;
var
  StartupInfo: TStartupInfo;
  ProcessInfo: TProcessInformation;
  ExitCode: Cardinal;
  CommandLine, FfmpegFile: string;
begin
  Result := False;
  AErrorText := '';
  FfmpegFile := FfmpegExecutable;
  if FfmpegFile = '' then
  begin
    AErrorText := 'ffmpeg.exe uygulama klasorunde bulunamadi.';
    Exit;
  end;
  if FileExists(AOutputFile) then
    DeleteFile(AOutputFile);
  CommandLine := '"' + FfmpegFile + '" -y -ss 00:00:00.500 -i "' +
    AFileName + '" ';
  CommandLine := CommandLine + '-frames:v 1 -vf "scale=160:120:';
  CommandLine := CommandLine + 'force_original_aspect_ratio=decrease,';
  CommandLine := CommandLine + 'pad=160:120:(ow-iw)/2:(oh-ih)/2:white" ';
  CommandLine := CommandLine + '-q:v 4 "' + AOutputFile + '"';
  ZeroMemory(@StartupInfo, SizeOf(StartupInfo));
  StartupInfo.cb := SizeOf(StartupInfo);
  StartupInfo.dwFlags := STARTF_USESHOWWINDOW;
  StartupInfo.wShowWindow := SW_HIDE;
  ZeroMemory(@ProcessInfo, SizeOf(ProcessInfo));
  if not CreateProcess(nil, PChar(CommandLine), nil, nil, False,
    CREATE_NO_WINDOW, nil, nil, StartupInfo, ProcessInfo) then
  begin
    AErrorText := SysErrorMessage(GetLastError);
    Exit;
  end;
  try
    case WaitForSingleObject(ProcessInfo.hProcess, 8000) of
      WAIT_OBJECT_0:
        begin
          GetExitCodeProcess(ProcessInfo.hProcess, ExitCode);
          Result := (ExitCode = 0) and FileExists(AOutputFile);
          if not Result then
            AErrorText := 'FFmpeg cikis kodu: ' + IntToStr(ExitCode);
        end;
      WAIT_TIMEOUT:
        begin
          TerminateProcess(ProcessInfo.hProcess, 1);
          AErrorText := 'FFmpeg 8 saniye icinde kare uretemedi.';
        end;
    else
      AErrorText := 'FFmpeg bekleme hatasi: ' +
        SysErrorMessage(GetLastError);
    end;
  finally
    CloseHandle(ProcessInfo.hThread);
    CloseHandle(ProcessInfo.hProcess);
  end;
end;

constructor TDirectoryMonitorWorker.Create(const ARootFolder: string);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FRootFolder := ARootFolder;
  FDirectoryHandle := INVALID_HANDLE_VALUE;
  FChanges := TList<string>.Create;
  FChangesLock := TCriticalSection.Create;
  FHandleLock := TCriticalSection.Create;
end;

destructor TDirectoryMonitorWorker.Destroy;
begin
  Stop;
  FHandleLock.Free;
  FChangesLock.Free;
  FChanges.Free;
  inherited;
end;

procedure TDirectoryMonitorWorker.AddChange(const AFileName: string);
begin
  FChangesLock.Acquire;
  try
    FChanges.Add(AFileName);
  finally
    FChangesLock.Release;
  end;
end;

function TDirectoryMonitorWorker.TakeChanges(
  const ADestination: TList<string>): Integer;
var
  I: Integer;
begin
  FChangesLock.Acquire;
  try
    Result := FChanges.Count;
    for I := 0 to FChanges.Count - 1 do
      ADestination.Add(FChanges[I]);
    FChanges.Clear;
  finally
    FChangesLock.Release;
  end;
end;

procedure TDirectoryMonitorWorker.Stop;
var
  DirectoryHandle: THandle;
begin
  Terminate;
  FHandleLock.Acquire;
  try
    DirectoryHandle := FDirectoryHandle;
  finally
    FHandleLock.Release;
  end;
  if DirectoryHandle <> INVALID_HANDLE_VALUE then
    CancelIoEx(DirectoryHandle, nil);
end;

procedure TDirectoryMonitorWorker.Execute;
var
  DirectoryHandle, EventHandle: THandle;
  Buffer: array[0..16383] of Byte;
  Overlapped: TOverlapped;
  BytesReturned: DWORD;
  NotifyInfo: PNotifyInfo;
  ChangedName: string;
begin
  DirectoryHandle := CreateFile(PChar(FRootFolder), FILE_LIST_DIRECTORY,
    FILE_SHARE_READ or FILE_SHARE_WRITE or FILE_SHARE_DELETE, nil, OPEN_EXISTING,
    FILE_FLAG_BACKUP_SEMANTICS or FILE_FLAG_OVERLAPPED, 0);
  if DirectoryHandle = INVALID_HANDLE_VALUE then
    Exit;

  FHandleLock.Acquire;
  try
    FDirectoryHandle := DirectoryHandle;
  finally
    FHandleLock.Release;
  end;
  EventHandle := CreateEvent(nil, True, False, nil);
  try
    while not Terminated do
    begin
      ZeroMemory(@Overlapped, SizeOf(Overlapped));
      Overlapped.hEvent := EventHandle;
      ResetEvent(EventHandle);
      BytesReturned := 0;
      if not ReadDirectoryChangesW(DirectoryHandle, @Buffer[0], SizeOf(Buffer),
        True, FILE_NOTIFY_CHANGE_FILE_NAME, @BytesReturned, @Overlapped, nil) then
      begin
        { With FILE_FLAG_OVERLAPPED Windows normally returns ERROR_IO_PENDING.
          It means the background notification is now waiting, not an error. }
        if GetLastError <> ERROR_IO_PENDING then
          Exit;
      end;
      WaitForSingleObject(EventHandle, INFINITE);
      if Terminated then
        Exit;
      if not GetOverlappedResult(DirectoryHandle, Overlapped, BytesReturned,
        False) then
        Continue;
      NotifyInfo := PNotifyInfo(@Buffer[0]);
      repeat
        if (NotifyInfo.Action = FILE_ACTION_ADDED) or
          (NotifyInfo.Action = FILE_ACTION_RENAMED_NEW_NAME) then
        begin
          SetString(ChangedName, PWideChar(@NotifyInfo.FileName[0]),
            NotifyInfo.FileNameLength div SizeOf(WideChar));
          AddChange(TPath.Combine(FRootFolder, ChangedName));
        end;
        if NotifyInfo.NextEntryOffset = 0 then
          Break;
        NotifyInfo := PNotifyInfo(PByte(NotifyInfo) + NotifyInfo.NextEntryOffset);
      until False;
    end;
  finally
    CloseHandle(EventHandle);
    FHandleLock.Acquire;
    try
      FDirectoryHandle := INVALID_HANDLE_VALUE;
    finally
      FHandleLock.Release;
    end;
    CloseHandle(DirectoryHandle);
  end;
end;

constructor TVideoThumbnailWorker.Create(const AIndex: Integer;
  const AFileName, AOutputFile: string);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FIndex := AIndex;
  FFileName := AFileName;
  FOutputFile := AOutputFile;
end;

function TVideoThumbnailWorker.IsFinished: Boolean;
begin
  { The thread handle is signalled only after Execute has completely returned.
    No shared completion flag or critical section is necessary. }
  Result := WaitForSingleObject(Handle, 0) = WAIT_OBJECT_0;
end;

procedure TVideoThumbnailWorker.Execute;
begin
  if not Terminated then
    FSuccess := ExtractVideoFrame(FFileName, FOutputFile, FErrorText);
end;

constructor TFileScanWorker.Create(const ARootFolder, AThumbnailFolder: string;
  const AFileFilter: TFileTypeFilter);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FRootFolder := ARootFolder;
  FThumbnailFolder := AThumbnailFolder;
  FFileFilter := AFileFilter;
  FItems := TList<TFileEntry>.Create;
  FLock := TCriticalSection.Create;
end;

destructor TFileScanWorker.Destroy;
begin
  FLock.Free;
  FItems.Free;
  inherited;
end;

function MatchesFileFilter(const AFileName: string;
  const AFileFilter: TFileTypeFilter): Boolean;
var
  Extension: string;
begin
  Extension := LowerCase(ExtractFileExt(AFileName));
  case AFileFilter of
    ftAllFiles:
      Result := True;
    ftImages:
      Result := MatchText(Extension, ['.jpg', '.jpeg', '.png', '.bmp', '.gif']);
    ftVideos:
      Result := MatchText(Extension, ['.mp4', '.avi', '.mkv', '.mov', '.wmv']);
    ftPdf:
      Result := SameText(Extension, '.pdf');
    ftAudio:
      Result := MatchText(Extension, ['.mp3', '.wav', '.flac']);
  else
    Result := MatchText(Extension, ['.pdf', '.jpg', '.jpeg', '.png', '.bmp',
      '.gif', '.mp4', '.avi', '.mkv', '.mov', '.wmv', '.mp3', '.wav', '.flac']);
  end;
end;

function TFileScanWorker.IsIncludedFile(const AFileName: string): Boolean;
begin
  Result := MatchesFileFilter(AFileName, FFileFilter);
end;

procedure TFileScanWorker.AddFile(const AFileName: string;
  const ASearch: TSearchRec);
var
  Item: TFileEntry;
begin
  if Terminated or not IsIncludedFile(AFileName) then
    Exit;
  Item.FullName := AFileName;
  Item.DisplayName := ExtractFileName(AFileName);
  Item.Extension := LowerCase(ExtractFileExt(AFileName));
  Item.FolderName := ExtractFileDir(AFileName);
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
          if not SameText(ExcludeTrailingPathDelimiter(Path),
            ExcludeTrailingPathDelimiter(FThumbnailFolder)) and
            ((Search.Attr and FILE_ATTRIBUTE_REPARSE_POINT) = 0) then
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
  if CurrentGroupByFolder then
  begin
    Result := CompareText(Left.FolderName, Right.FolderName);
    if Result <> 0 then
      Exit;
  end;
  case CurrentSort of
    0: Result := CompareValue(Right.ModifiedAt, Left.ModifiedAt);
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
  FThumbnailQueue := TList<Integer>.Create;
  FThumbnailIndexes := TDictionary<string, Integer>.Create;
  FQueuedThumbnailFiles := TDictionary<string, Boolean>.Create;
  FPlaceholderIndexes := TDictionary<string, Integer>.Create;
  FKnownFiles := TDictionary<string, Boolean>.Create;
  LoadSettings;
end;

destructor TFrmVisualFileManager.Destroy;
begin
  SaveSettings;
  ScanTimer.Enabled := False;
  SearchTimer.Enabled := False;
  ThumbnailTimer.Enabled := False;
  StopFolderMonitor;
  if Assigned(FScanWorker) then
  begin
    FScanWorker.Terminate;
    FScanWorker.WaitFor;
    FScanWorker.Free;
  end;
  if Assigned(FVideoWorker) then
  begin
    FVideoWorker.OnTerminate := nil;
    FVideoWorker.Terminate;
    FVideoWorker.WaitFor;
    FVideoWorker.Free;
  end;
  FKnownFiles.Free;
  FPlaceholderIndexes.Free;
  FQueuedThumbnailFiles.Free;
  FThumbnailIndexes.Free;
  FThumbnailQueue.Free;
  FVisibleItems.Free;
  FFiles.Free;
  inherited;
end;

function TFrmVisualFileManager.SettingsFileName: string;
begin
  Result := TPath.Combine(TPath.GetDocumentsPath, 'VisualFileManager.ini');
end;

procedure TFrmVisualFileManager.LoadSettings;
var
  Ini: TIniFile;
  SavedFolder: string;
  SavedView, SavedClickMode, SavedFilter, SavedGroup: Integer;
begin
  FolderEdit.Text := TPath.GetDocumentsPath;
  Ini := TIniFile.Create(SettingsFileName);
  try
    SavedFolder := Ini.ReadString('General', 'LastFolder', '');
    if DirectoryExists(SavedFolder) then
      FolderEdit.Text := SavedFolder;
    SavedView := Ini.ReadInteger('General', 'ViewMode', 0);
    if (SavedView >= 0) and (SavedView < ViewBox.Items.Count) then
      ViewBox.ItemIndex := SavedView
    else
      ViewBox.ItemIndex := 0;
    SavedClickMode := Ini.ReadInteger('General', 'ClickMode', 0);
    if (SavedClickMode >= 0) and (SavedClickMode < ClickModeBox.Items.Count) then
      ClickModeBox.ItemIndex := SavedClickMode
    else
      ClickModeBox.ItemIndex := 0;
    { Startup always begins with newest files first. }
    SortBox.ItemIndex := 0;
    SavedFilter := Ini.ReadInteger('General', 'FileFilter', 0);
    if (SavedFilter >= 0) and (SavedFilter < FilterBox.Items.Count) then
      FilterBox.ItemIndex := SavedFilter
    else
      FilterBox.ItemIndex := 0;
    SavedGroup := Ini.ReadInteger('General', 'FolderGrouping', 0);
    if (SavedGroup >= 0) and (SavedGroup < FolderGroupBox.Items.Count) then
      FolderGroupBox.ItemIndex := SavedGroup
    else
      FolderGroupBox.ItemIndex := 0;
  finally
    Ini.Free;
  end;
  CurrentGroupByFolder := FolderGroupBox.ItemIndex = 1;
  ViewChange(nil);
end;

procedure TFrmVisualFileManager.SaveSettings;
var
  Ini: TIniFile;
begin
  Ini := TIniFile.Create(SettingsFileName);
  try
    Ini.WriteString('General', 'LastFolder', FolderEdit.Text);
    Ini.WriteInteger('General', 'ViewMode', ViewBox.ItemIndex);
    Ini.WriteInteger('General', 'ClickMode', ClickModeBox.ItemIndex);
    Ini.WriteInteger('General', 'SortMode', SortBox.ItemIndex);
    Ini.WriteInteger('General', 'FileFilter', FilterBox.ItemIndex);
    Ini.WriteInteger('General', 'FolderGrouping', FolderGroupBox.ItemIndex);
  finally
    Ini.Free;
  end;
end;

procedure TFrmVisualFileManager.RefreshThumbnails(const AForce: Boolean);
begin
  { Thumbnails are staged while scanning.  Do not redraw the visible list for
    every image; that is the source of icon-view flicker. }
  if AForce and not Assigned(FScanWorker) and
    (FThumbnailQueuePosition >= FThumbnailQueue.Count) then
    PublishThumbnails;
end;

procedure TFrmVisualFileManager.PublishThumbnails;
begin
  if not FThumbnailImagesDirty then
    Exit;

  if FileList.HandleAllocated then
    SendMessage(FileList.Handle, WM_SETREDRAW, 0, 0);
  try
    FileList.LargeImages := nil;
    ThumbnailImages.Assign(ThumbnailStagingImages);
    FileList.LargeImages := ThumbnailImages;
    { OwnerData lists cache item images. Resetting the virtual item count makes
      OnData run now, instead of waiting for the final Render call. }
    FileList.Items.Count := FVisibleItems.Count;
    FThumbnailImagesDirty := False;
  finally
    if FileList.HandleAllocated then
    begin
      SendMessage(FileList.Handle, WM_SETREDRAW, 1, 0);
      FileList.Invalidate;
    end;
  end;
end;

procedure TFrmVisualFileManager.FormShow(Sender: TObject);
begin
  if FStartupScanDone then
    Exit;
  FStartupScanDone := True;
  if DirectoryExists(FolderEdit.Text) then
    ScanClick(nil);
end;

function TFrmVisualFileManager.PlaceholderKey(
  const AFile: TFileEntry): string;
begin
  if MatchText(AFile.Extension, ['.jpg', '.jpeg', '.png', '.bmp', '.gif']) then
    Result := 'image'
  else if MatchText(AFile.Extension, ['.mp4', '.avi', '.mkv', '.mov', '.wmv']) then
    Result := 'video'
  else if SameText(AFile.Extension, '.pdf') then
    Result := 'pdf'
  else if MatchText(AFile.Extension, ['.mp3', '.wav', '.flac']) then
    Result := 'audio'
  else
    Result := 'file';
end;

function TFrmVisualFileManager.PlaceholderImageIndex(
  const AFile: TFileEntry): Integer;
begin
  if not FPlaceholderIndexes.TryGetValue(PlaceholderKey(AFile), Result) then
    Result := -1;
end;

procedure TFrmVisualFileManager.PreparePlaceholderImages;
  procedure AddPlaceholder(const AKey, AText: string; const AColor: TColor);
  var
    Bitmap: TBitmap;
    ImageIndex: Integer;
  begin
    Bitmap := TBitmap.Create;
    try
      Bitmap.SetSize(160, 120);
      Bitmap.Canvas.Brush.Color := clWhite;
      Bitmap.Canvas.FillRect(Rect(0, 0, 160, 120));
      Bitmap.Canvas.Brush.Color := AColor;
      Bitmap.Canvas.FillRect(Rect(0, 0, 160, 26));
      Bitmap.Canvas.Font.Color := AColor;
      Bitmap.Canvas.Font.Style := [fsBold];
      Bitmap.Canvas.Font.Size := 16;
      Bitmap.Canvas.TextOut(14, 46, AText);
      Bitmap.Canvas.Font.Style := [];
      Bitmap.Canvas.Font.Size := 8;
      Bitmap.Canvas.Font.Color := clGray;
      Bitmap.Canvas.TextOut(14, 82, 'Kucuk resim hazirlaniyor');
      ImageIndex := ThumbnailImages.Add(Bitmap, nil);
      ThumbnailStagingImages.Add(Bitmap, nil);
      FPlaceholderIndexes.Add(AKey, ImageIndex);
    finally
      Bitmap.Free;
    end;
  end;
begin
  AddPlaceholder('image', 'RESIM', $00C07020);
  AddPlaceholder('video', 'VIDEO', $003040C0);
  AddPlaceholder('pdf', 'PDF', $002060C0);
  AddPlaceholder('audio', 'SES', $008040C0);
  AddPlaceholder('file', 'DOSYA', $00606060);
end;

function TFrmVisualFileManager.SelectedFileFilter: TFileTypeFilter;
begin
  Result := TFileTypeFilter(FilterBox.ItemIndex);
end;

procedure TFrmVisualFileManager.StopFolderMonitor;
begin
  MonitorTimer.Enabled := False;
  if Assigned(FMonitorWorker) then
  begin
    FMonitorWorker.Stop;
    FMonitorWorker.WaitFor;
    FMonitorWorker.Free;
    FMonitorWorker := nil;
  end;
end;

procedure TFrmVisualFileManager.StartFolderMonitor;
begin
  StopFolderMonitor;
  if not DirectoryExists(FRootFolder) then
    Exit;
  FMonitorWorker := TDirectoryMonitorWorker.Create(FRootFolder);
  FMonitorWorker.Start;
  MonitorTimer.Enabled := True;
end;

procedure TFrmVisualFileManager.AddMonitoredFile(const AFileName: string);
var
  Search: TSearchRec;
  Item: TFileEntry;
  FileKey: string;
  I: Integer;
begin
  FileKey := CanonicalFileName(AFileName);
  if not FileExists(AFileName) or
    SameText(ExcludeTrailingPathDelimiter(ExtractFileDir(AFileName)),
      ExcludeTrailingPathDelimiter(FThumbnailFolder)) or
    not MatchesFileFilter(AFileName, SelectedFileFilter) or
    FKnownFiles.ContainsKey(FileKey) then
    Exit;

  { ReadDirectoryChangesW can report an add and a rename for one physical
    file. The list check is a second guard against duplicate notifications. }
  for I := 0 to FFiles.Count - 1 do
    if SameText(FFiles[I].FullName, AFileName) then
      Exit;

  if FindFirst(AFileName, faAnyFile, Search) <> 0 then
    Exit;
  try
    if (Search.Attr and faDirectory) <> 0 then
      Exit;
    Item.FullName := AFileName;
    Item.DisplayName := ExtractFileName(AFileName);
    Item.Extension := LowerCase(ExtractFileExt(AFileName));
    Item.FolderName := ExtractFileDir(AFileName);
    Item.Size := Int64(Search.Size);
    Item.ModifiedAt := FileDateToDateTime(Search.Time);
    FFiles.Add(Item);
    FKnownFiles.Add(FileKey, True);
  finally
    FindClose(Search);
  end;
end;

procedure TFrmVisualFileManager.StartScan(const AFolder: string;
  const AFileFilter: TFileTypeFilter);
begin
  StopFolderMonitor;
  FRootFolder := ExcludeTrailingPathDelimiter(AFolder);
  FThumbnailFolder := TPath.Combine(FRootFolder, 'thumbnail');
  ForceDirectories(FThumbnailFolder);
  ScanTimer.Enabled := False;
  SearchTimer.Enabled := False;
  ThumbnailTimer.Enabled := False;
  FileList.Items.Count := 0;
  FFiles.Clear;
  FVisibleItems.Clear;
  FThumbnailQueue.Clear;
  FThumbnailQueuePosition := 0;
  FThumbnailIndexes.Clear;
  FQueuedThumbnailFiles.Clear;
  FPlaceholderIndexes.Clear;
  FKnownFiles.Clear;
  ThumbnailImages.Clear;
  ThumbnailStagingImages.Clear;
  PreparePlaceholderImages;
  FThumbnailImagesDirty := False;
  StatusLabel.Caption := 'Dosyalar arka planda taraniyor...';
  FScanWorker := TFileScanWorker.Create(FRootFolder, FThumbnailFolder,
    AFileFilter);
  FScanWorker.Priority := tpLower;
  FLastScanUiTick := 0;
  FScanWorker.Start;
  ScanTimer.Enabled := True;
  StopButton.Enabled := True;
end;

procedure TFrmVisualFileManager.BrowseClick(Sender: TObject);
var
  Folder: string;
begin
  Folder := FolderEdit.Text;
  if SelectDirectory('Taranacak klasoru secin', '', Folder) then
  begin
    FolderEdit.Text := Folder;
    ScanClick(nil);
  end;
end;

procedure TFrmVisualFileManager.ScanClick(Sender: TObject);
var
  RequestedFolder: string;
begin
  RequestedFolder := ExcludeTrailingPathDelimiter(FolderEdit.Text);
  if not DirectoryExists(RequestedFolder) then
  begin
    ShowMessage('Gecerli bir klasor secin.');
    Exit;
  end;

  if Assigned(FScanWorker) then
  begin
    FPendingScanFolder := RequestedFolder;
    FPendingFileFilter := SelectedFileFilter;
    FScanWorker.Terminate;
    StatusLabel.Caption := 'Onceki tarama durduruluyor, yeni tarama bekliyor...';
    Exit;
  end;

  StartScan(RequestedFolder, SelectedFileFilter);
end;

procedure TFrmVisualFileManager.StopClick(Sender: TObject);
begin
  FPendingScanFolder := '';
  if Assigned(FScanWorker) then
  begin
    FScanWorker.Terminate;
    StatusLabel.Caption := 'Tarama durduruluyor...';
  end;
end;

procedure TFrmVisualFileManager.ClickModeChange(Sender: TObject);
begin
  SaveSettings;
end;

procedure TFrmVisualFileManager.ScanTimerTick(Sender: TObject);
var
  PreviousCount, Added, I: Integer;
  NextFolder: string;
  NextFileFilter: TFileTypeFilter;
begin
  if not Assigned(FScanWorker) then
  begin
    ScanTimer.Enabled := False;
    Exit;
  end;
  PreviousCount := FFiles.Count;
  { Keep this UI-side batch intentionally small. File discovery remains in
    TFileScanWorker; this timer only merges already-discovered entries. }
  Added := FScanWorker.TakeBatch(FFiles, 25);
  for I := PreviousCount to FFiles.Count - 1 do
    FKnownFiles.AddOrSetValue(CanonicalFileName(FFiles[I].FullName), True);
  if (Added > 0) and (Trim(SearchEdit.Text) = '') then
  begin
    while PreviousCount < FFiles.Count do
    begin
      AddVisibleFile(PreviousCount);
      Inc(PreviousCount);
    end;
    SortVisibleByNewest;
    if (FLastScanUiTick = 0) or
      (Cardinal(GetTickCount - FLastScanUiTick) >= 200) then
    begin
      FileList.Items.Count := FVisibleItems.Count;
      FLastScanUiTick := GetTickCount;
    end;
    QueueThumbnailPage(0);
  end;
  StatusLabel.Caption := Format('%d dosya tarandi...', [FFiles.Count]);
  if FThumbnailQueuePosition < FThumbnailQueue.Count then
    ThumbnailTimer.Enabled := True;
  if FScanWorker.IsCompleted then
  begin
    ScanTimer.Enabled := False;
    FScanWorker.WaitFor;
    FScanWorker.Free;
    FScanWorker := nil;
    StopButton.Enabled := False;

    NextFolder := FPendingScanFolder;
    NextFileFilter := FPendingFileFilter;
    FPendingScanFolder := '';
    if NextFolder <> '' then
      StartScan(NextFolder, NextFileFilter)
    else
    begin
      Render;
      StartFolderMonitor;
    end;
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
  SaveSettings;
  if Assigned(FScanWorker) then
    StatusLabel.Caption := 'Siralama tarama tamamlandiginda uygulanacak.'
  else
    Render;
end;

procedure TFrmVisualFileManager.ViewChange(Sender: TObject);
begin
  SaveSettings;
  if ViewBox.ItemIndex = 1 then
  begin
    FileList.ViewStyle := vsIcon;
    QueueThumbnailPage(0);
  end
  else
    FileList.ViewStyle := vsReport;
end;

procedure TFrmVisualFileManager.FilterChange(Sender: TObject);
begin
  SaveSettings;
  StatusLabel.Caption := 'Dosya tipi filtresi degisti. Dosyalari Tara ile yenileyin.';
end;

procedure TFrmVisualFileManager.FolderGroupChange(Sender: TObject);
begin
  CurrentGroupByFolder := FolderGroupBox.ItemIndex = 1;
  SaveSettings;
  if Assigned(FScanWorker) then
    StatusLabel.Caption := 'Klasor gruplamasi tarama tamamlaninca uygulanacak.'
  else
    Render;
end;

procedure TFrmVisualFileManager.AddVisibleFile(const AIndex: Integer);
begin
  FVisibleItems.Add(AIndex);
end;

procedure TFrmVisualFileManager.SortVisibleByNewest;
begin
  if (SortBox.ItemIndex <> 0) or CurrentGroupByFolder then
    Exit;
  FVisibleItems.Sort(TComparer<Integer>.Construct(
    function(const Left, Right: Integer): Integer
    begin
      Result := CompareValue(FFiles[Right].ModifiedAt, FFiles[Left].ModifiedAt);
      if Result = 0 then
        Result := CompareText(FFiles[Left].DisplayName, FFiles[Right].DisplayName);
    end));
end;

procedure TFrmVisualFileManager.QueueThumbnail(const AIndex: Integer);
var
  FileName: string;
begin
  if (AIndex < 0) or (AIndex >= FFiles.Count) then
    Exit;
  FileName := FFiles[AIndex].FullName;
  if FThumbnailIndexes.ContainsKey(FileName) or
    FQueuedThumbnailFiles.ContainsKey(FileName) then
    Exit;
  FQueuedThumbnailFiles.Add(FileName, True);
  FThumbnailQueue.Add(AIndex);
end;

procedure TFrmVisualFileManager.QueueThumbnailPage(const AVisibleIndex: Integer);
const
  ThumbnailPageSize = 12;
var
  FirstIndex, LastIndex, I: Integer;
begin
  if FVisibleItems.Count = 0 then
    Exit;
  FirstIndex := (Max(0, AVisibleIndex) div ThumbnailPageSize) *
    ThumbnailPageSize;
  LastIndex := Min(FVisibleItems.Count - 1, FirstIndex + ThumbnailPageSize - 1);
  for I := FirstIndex to LastIndex do
    QueueThumbnail(FVisibleItems[I]);
  if FThumbnailQueuePosition < FThumbnailQueue.Count then
    ThumbnailTimer.Enabled := True;
end;

function TFrmVisualFileManager.IsVideoFile(const AFile: TFileEntry): Boolean;
begin
  Result := MatchText(AFile.Extension, ['.mp4', '.avi', '.mkv', '.mov',
    '.wmv']);
end;

procedure TFrmVisualFileManager.StartVideoThumbnail(const AIndex: Integer);
begin
  FVideoWorker := TVideoThumbnailWorker.Create(AIndex,
    FFiles[AIndex].FullName, ThumbnailFileName(FFiles[AIndex]));
  FVideoWorker.Start;
end;

procedure TFrmVisualFileManager.CompleteVideoThumbnail;
var
  Worker: TVideoThumbnailWorker;
  FileIndex: Integer;
begin
  Worker := FVideoWorker;
  if not Assigned(Worker) or not Worker.IsFinished then
    Exit;

  FVideoWorker := nil;
  Worker.WaitFor;
  FileIndex := Worker.Index;
  if (FileIndex >= 0) and (FileIndex < FFiles.Count) and
    SameText(FFiles[FileIndex].FullName, Worker.FileName) then
  begin
    LoadOrCreateThumbnail(FileIndex);
    RedrawThumbnailItem(FileIndex);
    if not Worker.Success then
      StatusLabel.Caption := 'MP4 kare cikarilamadi: ' + Worker.ErrorText;
  end;
  Worker.Free;
end;

procedure TFrmVisualFileManager.Render;
var
  I: Integer;
  Query: string;
begin
  CurrentSort := SortBox.ItemIndex;
  FFiles.Sort(TComparer<TFileEntry>.Construct(CompareEntries));
  FVisibleItems.Clear;
  FThumbnailQueue.Clear;
  FQueuedThumbnailFiles.Clear;
  FThumbnailQueuePosition := 0;
  Query := Trim(SearchEdit.Text);
  for I := 0 to FFiles.Count - 1 do
  begin
    if (Query = '') or ContainsText(FFiles[I].DisplayName, Query) then
      AddVisibleFile(I);
  end;
  QueueThumbnailPage(0);
  FileList.Items.Count := FVisibleItems.Count;
  if FVisibleItems.Count = 0 then
    StatusLabel.Caption := 'Dosya bulunamadi.'
  else
    StatusLabel.Caption := Format('%d dosya bulundu.', [FVisibleItems.Count]);
  ThumbnailTimer.Enabled := FThumbnailQueue.Count > 0;
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

function TFrmVisualFileManager.HashText(const AValue: string): Cardinal;
var
  I: Integer;
begin
  Result := 2166136261;
  for I := 1 to Length(AValue) do
  begin
    Result := Result xor Ord(AValue[I]);
    Result := Result * 16777619;
  end;
end;

function TFrmVisualFileManager.ThumbnailFileName(const AFile: TFileEntry): string;
var
  CacheVersion: string;
begin
  CacheVersion := 'image-cache-v1';
  if IsVideoFile(AFile) then
    CacheVersion := 'video-frame-v1';
  Result := TPath.Combine(FThumbnailFolder, IntToHex(HashText(AFile.FullName +
    '|' + IntToStr(AFile.Size) + '|' + IntToStr(Trunc(AFile.ModifiedAt * 86400000)) +
    '|' + CacheVersion), 8) + '.jpg');
end;

procedure TFrmVisualFileManager.CreateGenericThumbnail(const AFile: TFileEntry;
  const AOutput: string);
var
  Bitmap: TBitmap;
  Jpeg: TJPEGImage;
  Text: string;
begin
  Bitmap := TBitmap.Create;
  Jpeg := TJPEGImage.Create;
  try
    Bitmap.SetSize(160, 120);
    Bitmap.Canvas.Brush.Color := $00E8EEF5;
    Bitmap.Canvas.FillRect(Rect(0, 0, Bitmap.Width, Bitmap.Height));
    Bitmap.Canvas.Brush.Color := $006B7280;
    Bitmap.Canvas.FillRect(Rect(0, 0, Bitmap.Width, 10));
    Text := UpperCase(Copy(AFile.Extension, 2, 8));
    if Text = '' then
      Text := 'DOSYA';
    Bitmap.Canvas.Font.Color := $00405060;
    Bitmap.Canvas.Font.Size := 18;
    Bitmap.Canvas.Font.Style := [fsBold];
    Bitmap.Canvas.TextOut(14, 42, Text);
    Bitmap.Canvas.Font.Color := $006B7280;
    Bitmap.Canvas.Font.Size := 8;
    Bitmap.Canvas.Font.Style := [];
    Bitmap.Canvas.TextOut(14, 78, Copy(AFile.DisplayName, 1, 24));
    Jpeg.Assign(Bitmap);
    Jpeg.CompressionQuality := 78;
    Jpeg.Compress;
    Jpeg.SaveToFile(AOutput);
  finally
    Jpeg.Free;
    Bitmap.Free;
  end;
end;

procedure TFrmVisualFileManager.CreateThumbnail(const AFile: TFileEntry;
  const AOutput: string);
var
  Picture: TPicture;
  Bitmap: TBitmap;
  Jpeg: TJPEGImage;
  Scale: Double;
  Width, Height, LeftPos, TopPos: Integer;
begin
  if MatchText(AFile.Extension, ['.jpg', '.jpeg', '.png', '.bmp', '.gif']) then
  begin
    Picture := TPicture.Create;
    Bitmap := TBitmap.Create;
    Jpeg := TJPEGImage.Create;
    try
      try
        Picture.LoadFromFile(AFile.FullName);
        if (Picture.Graphic.Width <= 0) or (Picture.Graphic.Height <= 0) then
        begin
          CreateGenericThumbnail(AFile, AOutput);
          Exit;
        end;
        Bitmap.SetSize(160, 120);
        Bitmap.Canvas.Brush.Color := clWhite;
        Bitmap.Canvas.FillRect(Rect(0, 0, Bitmap.Width, Bitmap.Height));
        Scale := Min(Bitmap.Width / Picture.Graphic.Width,
          Bitmap.Height / Picture.Graphic.Height);
        Width := Round(Picture.Graphic.Width * Scale);
        Height := Round(Picture.Graphic.Height * Scale);
        LeftPos := (Bitmap.Width - Width) div 2;
        TopPos := (Bitmap.Height - Height) div 2;
        Bitmap.Canvas.StretchDraw(Rect(LeftPos, TopPos, LeftPos + Width,
          TopPos + Height), Picture.Graphic);
        Jpeg.Assign(Bitmap);
        Jpeg.CompressionQuality := 78;
        Jpeg.Compress;
        Jpeg.SaveToFile(AOutput);
      except
        CreateGenericThumbnail(AFile, AOutput);
      end;
    finally
      Jpeg.Free;
      Bitmap.Free;
      Picture.Free;
    end;
  end
  else
    CreateGenericThumbnail(AFile, AOutput);
end;

procedure TFrmVisualFileManager.LoadOrCreateThumbnail(const AIndex: Integer);
var
  CacheFile: string;
  Picture: TPicture;
  Bitmap: TBitmap;
  ImageIndex: Integer;
begin
  if (AIndex < 0) or (AIndex >= FFiles.Count) then
    Exit;
  if FThumbnailIndexes.ContainsKey(FFiles[AIndex].FullName) then
    Exit;
  CacheFile := ThumbnailFileName(FFiles[AIndex]);
  if not FileExists(CacheFile) then
    CreateThumbnail(FFiles[AIndex], CacheFile);
  if not FileExists(CacheFile) then
    Exit;
  Picture := TPicture.Create;
  Bitmap := TBitmap.Create;
  try
    Picture.LoadFromFile(CacheFile);
    Bitmap.SetSize(160, 120);
    Bitmap.Canvas.Brush.Color := clWhite;
    Bitmap.Canvas.FillRect(Rect(0, 0, Bitmap.Width, Bitmap.Height));
    Bitmap.Canvas.StretchDraw(Rect(0, 0, Bitmap.Width, Bitmap.Height),
      Picture.Graphic);
    ImageIndex := ThumbnailStagingImages.Add(Bitmap, nil);
    FThumbnailIndexes.Add(FFiles[AIndex].FullName, ImageIndex);
    FThumbnailImagesDirty := True;
  except
  end;
  Bitmap.Free;
  Picture.Free;
end;

procedure TFrmVisualFileManager.RedrawThumbnailItem(
  const AFileIndex: Integer);
begin
  { Image is held in the staging list.  The visible image list is replaced
    once after the queue completes, so no per-item redraw is needed. }
end;

procedure TFrmVisualFileManager.ThumbnailTimerTick(Sender: TObject);
const
  CachedItemsPerTick = 4;
var
  FileIndex, LoadedCount: Integer;
  CacheFile: string;
  WasCached: Boolean;
begin
  ThumbnailTimer.Enabled := False;

  if Assigned(FVideoWorker) then
  begin
    if not FVideoWorker.IsFinished then
    begin
      ThumbnailTimer.Enabled := True;
      Exit;
    end;
    CompleteVideoThumbnail;
  end;

  LoadedCount := 0;
  while FThumbnailQueuePosition < FThumbnailQueue.Count do
  begin
    FileIndex := FThumbnailQueue[FThumbnailQueuePosition];
    Inc(FThumbnailQueuePosition);
    CacheFile := ThumbnailFileName(FFiles[FileIndex]);
    WasCached := FileExists(CacheFile);

    if IsVideoFile(FFiles[FileIndex]) and not WasCached then
    begin
      StartVideoThumbnail(FileIndex);
      Break;
    end;

    LoadOrCreateThumbnail(FileIndex);
    RedrawThumbnailItem(FileIndex);
    Inc(LoadedCount);

    { Existing cached thumbnails are cheap to load, so show the initial
      viewport promptly. New image decoding stays one-at-a-time. }
    if not WasCached or (LoadedCount >= CachedItemsPerTick) then
      Break;
  end;

  if Assigned(FVideoWorker) or
    (FThumbnailQueuePosition < FThumbnailQueue.Count) then
    ThumbnailTimer.Enabled := True
  else
    PublishThumbnails;
end;

procedure TFrmVisualFileManager.RemoveDuplicateFiles;
var
  Seen: TDictionary<string, Boolean>;
  I: Integer;
  FileKey: string;
begin
  Seen := TDictionary<string, Boolean>.Create;
  try
    for I := FFiles.Count - 1 downto 0 do
    begin
      FileKey := CanonicalFileName(FFiles[I].FullName);
      if Seen.ContainsKey(FileKey) then
        FFiles.Delete(I)
      else
        Seen.Add(FileKey, True);
    end;
  finally
    Seen.Free;
  end;
end;

procedure TFrmVisualFileManager.MonitorTimerTick(Sender: TObject);
var
  Changes: TList<string>;
  I, OldCount: Integer;
begin
  if not Assigned(FMonitorWorker) then
  begin
    MonitorTimer.Enabled := False;
    Exit;
  end;
  Changes := TList<string>.Create;
  try
    FMonitorWorker.TakeChanges(Changes);
    if Changes.Count = 0 then
      Exit;
    OldCount := FFiles.Count;
    for I := 0 to Changes.Count - 1 do
      AddMonitoredFile(Changes[I]);
    RemoveDuplicateFiles;
    if FFiles.Count > OldCount then
    begin
      Render;
      StatusLabel.Caption := Format('%d yeni dosya algilandi.', [FFiles.Count - OldCount]);
    end;
  finally
    Changes.Free;
  end;
end;

procedure TFrmVisualFileManager.FileListData(Sender: TObject;
  Item: TListItem);
var
  FileIndex, ImageIndex: Integer;
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
  Item.SubItems.Add(FileEntry.FolderName);
  Item.SubItems.Add(FileEntry.FullName);
  if FThumbnailIndexes.TryGetValue(FileEntry.FullName, ImageIndex) and
    (ImageIndex < ThumbnailImages.Count) then
    Item.ImageIndex := ImageIndex
  else
    Item.ImageIndex := PlaceholderImageIndex(FileEntry);
  if ViewBox.ItemIndex = 1 then
    QueueThumbnailPage(Item.Index);
end;

procedure TFrmVisualFileManager.OpenSelectedFile;
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

procedure TFrmVisualFileManager.FileListClick(Sender: TObject);
begin
  if ClickModeBox.ItemIndex = 1 then
    OpenSelectedFile;
end;

procedure TFrmVisualFileManager.FileListMouseEnter(Sender: TObject);
begin
  { Windows routes the wheel to the focused VCL control. }
  if FileList.CanFocus and not FileList.Focused then
    FileList.SetFocus;
end;

procedure TFrmVisualFileManager.FileListDblClick(Sender: TObject);
begin
  if ClickModeBox.ItemIndex = 0 then
    OpenSelectedFile;
end;

end.
