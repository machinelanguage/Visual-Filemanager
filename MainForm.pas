unit MainForm;

interface

uses
  Winapi.Windows, Winapi.Messages, Winapi.ShellAPI, Winapi.CommCtrl, System.SysUtils,
  System.Classes,
  System.Generics.Collections, System.Generics.Defaults, System.SyncObjs,
  Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ComCtrls,
  Vcl.Dialogs, Vcl.ImgList, System.IniFiles, System.ImageList, Vcl.Graphics;

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
    FileAreaPanel: TPanel;
    StatusPanel: TPanel;
    PathGroupBevel: TBevel;
    ViewGroupBevel: TBevel;
    ActionGroupBevel: TBevel;
    FolderEdit: TEdit;
    BrowseButton: TButton;
    ScanButton: TButton;
    StopButton: TButton;
    DeleteButton: TButton;
    ClickModeBox: TComboBox;
    FolderGroupBox: TComboBox;
    AnimationBox: TComboBox;
    AnimationDurationBox: TComboBox;
    AnimationDistanceBox: TComboBox;
    BackgroundColorBox: TColorBox;
    FontSizeBox: TComboBox;
    FrameSizeBox: TComboBox;
    SearchEdit: TEdit;
    SortBox: TComboBox;
    ViewBox: TComboBox;
    FilterBox: TComboBox;
    StatusLabel: TLabel;
    FileList: TListView;
    SearchTimer: TTimer;
    ScanTimer: TTimer;
    ThumbnailTimer: TTimer;
    ThumbnailEffectTimer: TTimer;
    MonitorTimer: TTimer;
    ThumbnailImages: TImageList;
    ThumbnailStagingImages: TImageList;
    ThumbnailImagesLarge: TImageList;
    ThumbnailStagingImagesLarge: TImageList;
    ThumbnailImagesXLarge: TImageList;
    ThumbnailStagingImagesXLarge: TImageList;
    SelectionImages: TImageList;
    procedure FormShow(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure BrowseClick(Sender: TObject);
    procedure ScanClick(Sender: TObject);
    procedure StopClick(Sender: TObject);
    procedure DeleteClick(Sender: TObject);
    procedure ClickModeChange(Sender: TObject);
    procedure FolderGroupChange(Sender: TObject);
    procedure ThumbnailAnimationChange(Sender: TObject);
    procedure AnimationDurationChange(Sender: TObject);
    procedure AnimationDistanceChange(Sender: TObject);
    procedure BackgroundColorChange(Sender: TObject);
    procedure FontSizeChange(Sender: TObject);
    procedure FrameSizeChange(Sender: TObject);
    procedure SearchChange(Sender: TObject);
    procedure SearchTimerTick(Sender: TObject);
    procedure SortChange(Sender: TObject);
    procedure ViewChange(Sender: TObject);
    procedure FilterChange(Sender: TObject);
    procedure ScanTimerTick(Sender: TObject);
    procedure ThumbnailTimerTick(Sender: TObject);
    procedure ThumbnailEffectTimerTick(Sender: TObject);
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
    FMarkedFiles: TDictionary<string, Boolean>;
    FRootFolder: string;
    FThumbnailFolder: string;
    FThumbnailRefreshCount: Integer;
    FLastThumbnailRefreshTick: Cardinal;
    FThumbnailImagesDirty: Boolean;
    FPendingScanFolder: string;
    FPendingFileFilter: TFileTypeFilter;
    FStartupScanDone: Boolean;
    FLastScanUiTick: Cardinal;
    FThumbnailEffectMode: Integer;
    FThumbnailSlideOffset: Integer;
    FThumbnailSlideStep: Integer;
    FThumbnailFadeDirection: Integer;
    FThumbnailFadeStep: Integer;
    FThumbnailFadeHoldTicks: Integer;
    FInitialThumbnailPageEnd: Integer;
    FThumbnailPageAnimationPlayed: Boolean;
    procedure LoadSettings;
    procedure SaveSettings;
    function SettingsFileName: string;
    procedure RefreshThumbnails(const AForce: Boolean = False);
    procedure PublishThumbnails;
    procedure StartThumbnailEffect;
    procedure TryStartThumbnailPageAnimation;
    function ThumbnailAnimationDuration: Integer;
    function ThumbnailAnimationDistance: Integer;
    procedure ApplyBackgroundColor(const AColor: TColor);
    procedure ApplyFileCheckboxes;
    procedure PrepareSelectionImages;
    procedure ToggleSelectedFileMark;
    procedure ApplyFileTextSize;
    procedure ApplyThumbnailGridSpacing;
    procedure ReflowThumbnailGrid;
    procedure RefreshThumbnailFrames;
    function ActiveThumbnailImages: TImageList;
    function ActiveThumbnailStagingImages: TImageList;
    function ThumbnailFrameScale: Double;
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
  System.IOUtils, System.StrUtils, System.Math, Vcl.FileCtrl,
  Vcl.Imaging.jpeg, Vcl.Imaging.pngimage, Vcl.Imaging.GIFImg;

const
  APPLICATION_VERSION = '1.2.53';

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
  FMarkedFiles := TDictionary<string, Boolean>.Create;
  LoadSettings;
end;

destructor TFrmVisualFileManager.Destroy;
begin
  SaveSettings;
  ScanTimer.Enabled := False;
  SearchTimer.Enabled := False;
  ThumbnailTimer.Enabled := False;
  ThumbnailEffectTimer.Enabled := False;
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
  FMarkedFiles.Free;
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
  SavedView, SavedClickMode, SavedFilter, SavedGroup, SavedAnimation,
    SavedAnimationDuration, SavedAnimationDistance, SavedFontSize,
      SavedFrameSize: Integer;
  SavedBackgroundColor: TColor;
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
    SavedAnimation := Ini.ReadInteger('General', 'ThumbnailAnimation', 1);
    if (SavedAnimation >= 0) and (SavedAnimation < AnimationBox.Items.Count) then
      AnimationBox.ItemIndex := SavedAnimation
    else
      AnimationBox.ItemIndex := 1;
    SavedAnimationDuration := Ini.ReadInteger('General', 'ThumbnailAnimationDuration', 1);
    if (SavedAnimationDuration >= 0) and
      (SavedAnimationDuration < AnimationDurationBox.Items.Count) then
      AnimationDurationBox.ItemIndex := SavedAnimationDuration
    else
      AnimationDurationBox.ItemIndex := 1;
    SavedAnimationDistance := Ini.ReadInteger('General', 'ThumbnailAnimationDistance', 1);
    if (SavedAnimationDistance >= 0) and
      (SavedAnimationDistance < AnimationDistanceBox.Items.Count) then
      AnimationDistanceBox.ItemIndex := SavedAnimationDistance
    else
      AnimationDistanceBox.ItemIndex := 1;
    SavedBackgroundColor := TColor(Ini.ReadInteger('General', 'BackgroundColor',
      Integer(Color)));
    BackgroundColorBox.Selected := SavedBackgroundColor;
    ApplyBackgroundColor(SavedBackgroundColor);
    SavedFontSize := Ini.ReadInteger('General', 'FileTextSize', 3);
    if (SavedFontSize >= 0) and (SavedFontSize < FontSizeBox.Items.Count) then
      FontSizeBox.ItemIndex := SavedFontSize
    else
      FontSizeBox.ItemIndex := 3;
    ApplyFileTextSize;
    SavedFrameSize := Ini.ReadInteger('General', 'ThumbnailFrameSize', 0);
    if (SavedFrameSize >= 0) and (SavedFrameSize < FrameSizeBox.Items.Count) then
      FrameSizeBox.ItemIndex := SavedFrameSize
    else
      FrameSizeBox.ItemIndex := 0;
    FileList.LargeImages := ActiveThumbnailImages;
  finally
    Ini.Free;
  end;
  CurrentGroupByFolder := FolderGroupBox.ItemIndex = 1;
  if AnimationBox.ItemIndex = 2 then
    ThumbnailTimer.Interval := 90
  else
    ThumbnailTimer.Interval := 30;
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
    Ini.WriteInteger('General', 'ThumbnailAnimation', AnimationBox.ItemIndex);
    Ini.WriteInteger('General', 'ThumbnailAnimationDuration',
      AnimationDurationBox.ItemIndex);
    Ini.WriteInteger('General', 'ThumbnailAnimationDistance',
      AnimationDistanceBox.ItemIndex);
    Ini.WriteInteger('General', 'BackgroundColor', Integer(Color));
    Ini.WriteInteger('General', 'FileTextSize', FontSizeBox.ItemIndex);
    Ini.WriteInteger('General', 'ThumbnailFrameSize', FrameSizeBox.ItemIndex);
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
  { Each image is already inserted into the active list. Do not reset the
    OwnerData item count or invalidate the whole list here: either action
    repaints every card and causes visible thumbnail flicker. }
  FThumbnailImagesDirty := False;
end;

procedure TFrmVisualFileManager.TryStartThumbnailPageAnimation;
begin
  { Do not animate placeholders. The first visible page must be fully staged,
    and the background file scan must have completed first. }
  if FThumbnailPageAnimationPlayed or (FInitialThumbnailPageEnd = 0) or
    (FThumbnailQueuePosition < FInitialThumbnailPageEnd) or
    Assigned(FVideoWorker) or Assigned(FScanWorker) then
    Exit;

  if FThumbnailImagesDirty then
    PublishThumbnails;
  if AnimationBox.ItemIndex >= 3 then
    StartThumbnailEffect;
  FThumbnailPageAnimationPlayed := True;
end;

procedure TFrmVisualFileManager.StartThumbnailEffect;
var
  Travel: Integer;
begin
  ThumbnailEffectTimer.Enabled := False;
  FThumbnailEffectMode := AnimationBox.ItemIndex;

  case FThumbnailEffectMode of
    3, 4:
      begin
        { User-selected offset, capped so part of the page remains visible. }
        Travel := Min(ThumbnailAnimationDistance,
          Max(50, FileAreaPanel.ClientWidth - 40));
        if FThumbnailEffectMode = 3 then
          FThumbnailSlideOffset := -Travel
        else
          FThumbnailSlideOffset := Travel;
        FThumbnailSlideStep := Max(1, (Travel * ThumbnailEffectTimer.Interval +
          ThumbnailAnimationDuration - 1) div ThumbnailAnimationDuration);
        FileList.Align := alNone;
        FileList.SetBounds(3 + FThumbnailSlideOffset, 3,
          Max(1, FileAreaPanel.ClientWidth - 6),
          Max(1, FileAreaPanel.ClientHeight - 6));
        ThumbnailEffectTimer.Enabled := True;
      end;
    5, 6:
      begin
        FThumbnailFadeStep := Max(1, (65 * ThumbnailEffectTimer.Interval) div
          ThumbnailAnimationDuration);
        FThumbnailFadeHoldTicks := 0;
        AlphaBlend := True;
        if FThumbnailEffectMode = 5 then
        begin
          { Fade in: reveal the refreshed thumbnail view. }
          FThumbnailFadeDirection := 1;
          AlphaBlendValue := 190;
        end
        else
        begin
          { Fade out: dim briefly, then restore the normal form opacity. }
          FThumbnailFadeDirection := -1;
          AlphaBlendValue := 255;
        end;
        ThumbnailEffectTimer.Enabled := True;
      end;
  end;
end;

procedure TFrmVisualFileManager.ThumbnailEffectTimerTick(Sender: TObject);
var
  NewAlpha: Integer;
begin
  case FThumbnailEffectMode of
    3, 4:
      begin
        if FThumbnailSlideOffset < 0 then
          Inc(FThumbnailSlideOffset, FThumbnailSlideStep)
        else if FThumbnailSlideOffset > 0 then
          Dec(FThumbnailSlideOffset, FThumbnailSlideStep);

        if Abs(FThumbnailSlideOffset) <= FThumbnailSlideStep then
        begin
          FThumbnailSlideOffset := 0;
          FileList.Align := alClient;
          ThumbnailEffectTimer.Enabled := False;
          Exit;
        end;
        FileList.SetBounds(3 + FThumbnailSlideOffset, 3,
          Max(1, FileAreaPanel.ClientWidth - 6),
          Max(1, FileAreaPanel.ClientHeight - 6));
      end;
    5:
      begin
        NewAlpha := AlphaBlendValue + FThumbnailFadeStep;
        if NewAlpha >= 255 then
        begin
          AlphaBlendValue := 255;
          AlphaBlend := False;
          ThumbnailEffectTimer.Enabled := False;
          Exit;
        end;
        AlphaBlendValue := NewAlpha;
      end;
    6:
      begin
        if FThumbnailFadeHoldTicks > 0 then
        begin
          Dec(FThumbnailFadeHoldTicks);
          if FThumbnailFadeHoldTicks = 0 then
          begin
            AlphaBlendValue := 255;
            AlphaBlend := False;
            ThumbnailEffectTimer.Enabled := False;
          end;
          Exit;
        end;
        NewAlpha := AlphaBlendValue - FThumbnailFadeStep;
        if NewAlpha <= 190 then
        begin
          AlphaBlendValue := 190;
          FThumbnailFadeHoldTicks := 4;
          Exit;
        end;
        AlphaBlendValue := NewAlpha;
      end;
  else
    ThumbnailEffectTimer.Enabled := False;
  end;
end;

procedure TFrmVisualFileManager.FormResize(Sender: TObject);
const
  Margin = 12;
  Gap = 8;
  TouchHeight = 30;
var
  AvailableWidth, X, Y, ItemWidth: Integer;
begin
  AvailableWidth := ClientWidth - (Margin * 2);

  { Wide layout: command bars remain on two compact rows. }
  if ClientWidth >= 1100 then
  begin
    ToolPanel.Height := 104;
    FolderEdit.SetBounds(Margin, 12, ClientWidth - 456, 24);
    X := FolderEdit.Left + FolderEdit.Width + Gap;
    BrowseButton.SetBounds(X, 10, 86, TouchHeight);
    ScanButton.SetBounds(BrowseButton.Left + BrowseButton.Width + Gap, 10, 120,
      TouchHeight);
    StopButton.SetBounds(ScanButton.Left + ScanButton.Width + Gap, 10, 92,
      TouchHeight);
    DeleteButton.SetBounds(StopButton.Left + StopButton.Width + Gap, 10, 100,
      TouchHeight);
    SearchEdit.SetBounds(Margin, 50, 340, 24);
    SortBox.SetBounds(364, 50, 150, 24);
    ViewBox.SetBounds(522, 50, 140, 24);
    FilterBox.SetBounds(670, 50, 150, 24);
    ClickModeBox.SetBounds(828, 50, 140, 24);
    FolderGroupBox.SetBounds(976, 50, ClientWidth - 988, 24);
    PathGroupBevel.SetBounds(6, 5, DeleteButton.Left + DeleteButton.Width,
      40);
    ActionGroupBevel.SetBounds(DeleteButton.Left - 4, 5,
      DeleteButton.Width + 8, 40);
    ViewGroupBevel.SetBounds(6, 44, ClientWidth - 12, 38);
  end
  else if ClientWidth >= 640 then
  begin
    ToolPanel.Height := 184;
    FolderEdit.SetBounds(Margin, 10, AvailableWidth, 24);
    BrowseButton.SetBounds(Margin, 42, 88, TouchHeight);
    ScanButton.SetBounds(BrowseButton.Left + BrowseButton.Width + Gap, 42, 112,
      TouchHeight);
    StopButton.SetBounds(ScanButton.Left + ScanButton.Width + Gap, 42, 112,
      TouchHeight);
    DeleteButton.SetBounds(StopButton.Left + StopButton.Width + Gap, 42, 100,
      TouchHeight);
    SearchEdit.SetBounds(Margin, 78, AvailableWidth, 24);
    ItemWidth := (AvailableWidth - (Gap * 2)) div 3;
    SortBox.SetBounds(Margin, 112, ItemWidth, 24);
    ViewBox.SetBounds(SortBox.Left + ItemWidth + Gap, 112, ItemWidth, 24);
    FilterBox.SetBounds(ViewBox.Left + ItemWidth + Gap, 112, ItemWidth, 24);
    ItemWidth := (AvailableWidth - Gap) div 2;
    ClickModeBox.SetBounds(Margin, 146, ItemWidth, 24);
    FolderGroupBox.SetBounds(ClickModeBox.Left + ItemWidth + Gap, 146,
      ItemWidth, 24);
    PathGroupBevel.SetBounds(6, 5, ClientWidth - 12, 34);
    ActionGroupBevel.SetBounds(6, 37, DeleteButton.Left + DeleteButton.Width + 6,
      40);
    ViewGroupBevel.SetBounds(6, 105, ClientWidth - 12, 72);
  end
  else
  begin
    ToolPanel.Height := 254;
    FolderEdit.SetBounds(Margin, 10, AvailableWidth, 24);
    BrowseButton.SetBounds(Margin, 42, 92, TouchHeight);
    ScanButton.SetBounds(BrowseButton.Left + BrowseButton.Width + Gap, 42, 116,
      TouchHeight);
    StopButton.SetBounds(Margin, 76, 118, TouchHeight);
    DeleteButton.SetBounds(StopButton.Left + StopButton.Width + Gap, 76,
      Max(90, AvailableWidth - StopButton.Width - Gap), TouchHeight);
    SearchEdit.SetBounds(Margin, 112, AvailableWidth, 24);
    ItemWidth := (AvailableWidth - Gap) div 2;
    SortBox.SetBounds(Margin, 146, ItemWidth, 24);
    ViewBox.SetBounds(SortBox.Left + ItemWidth + Gap, 146, ItemWidth, 24);
    FilterBox.SetBounds(Margin, 180, ItemWidth, 24);
    ClickModeBox.SetBounds(FilterBox.Left + ItemWidth + Gap, 180, ItemWidth,
      24);
    FolderGroupBox.SetBounds(Margin, 214, AvailableWidth, 24);
    PathGroupBevel.SetBounds(6, 5, ClientWidth - 12, 34);
    ActionGroupBevel.SetBounds(6, 37, ClientWidth - 12, 74);
    ViewGroupBevel.SetBounds(6, 139, ClientWidth - 12, 106);
  end;

  AnimationBox.SetBounds(Max(314, ClientWidth - 166), 2, 154, 24);
  AnimationDurationBox.SetBounds(Max(218, AnimationBox.Left - 96), 2, 90, 24);
  AnimationDistanceBox.SetBounds(Max(122, AnimationDurationBox.Left - 96), 2,
    90, 24);
  BackgroundColorBox.SetBounds(Max(16, AnimationDistanceBox.Left - 106), 2,
    100, 24);
  FontSizeBox.SetBounds(Max(16, BackgroundColorBox.Left - 106), 2, 100, 24);
  FrameSizeBox.SetBounds(Max(16, FontSizeBox.Left - 106), 2, 100, 24);
  StatusLabel.Width := Max(1, FrameSizeBox.Left - 24);
end;

procedure TFrmVisualFileManager.FormShow(Sender: TObject);
begin
  Caption := 'Dosya Yoneticisi v' + APPLICATION_VERSION;
  PrepareSelectionImages;
  ApplyFileCheckboxes;
  ApplyFileTextSize;
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
    Scale: Double;
  begin
    Bitmap := TBitmap.Create;
    try
      Scale := ThumbnailFrameScale;
      Bitmap.SetSize(ActiveThumbnailImages.Width, ActiveThumbnailImages.Height);
      Bitmap.Canvas.Brush.Color := clWhite;
      Bitmap.Canvas.FillRect(Rect(0, 0, Bitmap.Width, Bitmap.Height));
      Bitmap.Canvas.Brush.Color := AColor;
      Bitmap.Canvas.FillRect(Rect(0, 0, Bitmap.Width, Round(26 * Scale)));
      Bitmap.Canvas.Font.Color := AColor;
      Bitmap.Canvas.Font.Style := [fsBold];
      Bitmap.Canvas.Font.Size := Round(16 * Scale);
      Bitmap.Canvas.TextOut(Round(14 * Scale), Round(46 * Scale), AText);
      Bitmap.Canvas.Font.Style := [];
      Bitmap.Canvas.Font.Size := Round(8 * Scale);
      Bitmap.Canvas.Font.Color := clGray;
      Bitmap.Canvas.TextOut(Round(14 * Scale), Round(82 * Scale),
        'Kucuk resim hazirlaniyor');
      ImageIndex := ActiveThumbnailImages.Add(Bitmap, nil);
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
  ActiveThumbnailImages.Clear;
  ActiveThumbnailStagingImages.Clear;
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

function TFrmVisualFileManager.ThumbnailAnimationDuration: Integer;
begin
  case AnimationDurationBox.ItemIndex of
    0: Result := 120;
    2: Result := 450;
    3: Result := 700;
  else
    Result := 250;
  end;
end;

procedure TFrmVisualFileManager.ApplyBackgroundColor(
  const AColor: TColor);
begin
  Color := AColor;
  ToolPanel.Color := AColor;
  FileAreaPanel.Color := AColor;
  StatusPanel.Color := AColor;
  { The thumbnail ground is owned by the native virtual list, not its
    surrounding panel. Apply the color directly and repaint it immediately. }
  FileList.Color := AColor;
  ToolPanel.Invalidate;
  FileAreaPanel.Invalidate;
  StatusPanel.Invalidate;
  FileList.Invalidate;
end;

procedure TFrmVisualFileManager.PrepareSelectionImages;
var
  Bitmap: TBitmap;
begin
  if SelectionImages.Count > 0 then
    Exit;
  Bitmap := TBitmap.Create;
  try
    Bitmap.SetSize(18, 18);
    Bitmap.Canvas.Brush.Color := clWhite;
    Bitmap.Canvas.FillRect(Rect(0, 0, 18, 18));
    Bitmap.Canvas.Pen.Color := clGray;
    Bitmap.Canvas.Rectangle(2, 2, 15, 15);
    SelectionImages.Add(Bitmap, nil);
    Bitmap.Canvas.Brush.Color := $00DDF5DF;
    Bitmap.Canvas.FillRect(Rect(0, 0, 18, 18));
    Bitmap.Canvas.Pen.Color := $00308030;
    Bitmap.Canvas.Rectangle(2, 2, 15, 15);
    Bitmap.Canvas.Pen.Width := 2;
    Bitmap.Canvas.MoveTo(4, 8);
    Bitmap.Canvas.LineTo(7, 12);
    Bitmap.Canvas.LineTo(13, 5);
    Bitmap.Canvas.Pen.Width := 1;
    SelectionImages.Add(Bitmap, nil);
  finally
    Bitmap.Free;
  end;
end;

procedure TFrmVisualFileManager.ApplyFileCheckboxes;
begin
  { Use a fixed custom state image list: native checkboxes are not rendered
    reliably by the Delphi 10.2 virtual icon list. }
  FileList.Checkboxes := False;
  FileList.StateImages := SelectionImages;
end;

procedure TFrmVisualFileManager.ToggleSelectedFileMark;
var
  Position, FileIndex, VisibleIndex: Integer;
  FileName: string;
begin
  if not Assigned(FileList.Selected) then
    Exit;
  Position := FileList.Selected.Index;
  if (Position < 0) or (Position >= FVisibleItems.Count) then
    Exit;
  FileIndex := FVisibleItems[Position];
  FileName := FFiles[FileIndex].FullName;
  if FMarkedFiles.ContainsKey(FileName) then
    FMarkedFiles.Remove(FileName)
  else
    FMarkedFiles.Add(FileName, True);
  VisibleIndex := Position;
  if FileList.HandleAllocated then
    SendMessage(FileList.Handle, LVM_REDRAWITEMS, VisibleIndex, VisibleIndex);
end;

procedure TFrmVisualFileManager.BackgroundColorChange(Sender: TObject);
begin
  ApplyBackgroundColor(BackgroundColorBox.Selected);
  SaveSettings;
end;

function TFrmVisualFileManager.ThumbnailAnimationDistance: Integer;
begin
  case AnimationDistanceBox.ItemIndex of
    0: Result := 80;
    2: Result := 200;
    3: Result := 260;
  else
    Result := 140;
  end;
end;

procedure TFrmVisualFileManager.AnimationDistanceChange(Sender: TObject);
begin
  SaveSettings;
  if ThumbnailEffectTimer.Enabled and (FThumbnailEffectMode in [3, 4]) then
    StartThumbnailEffect;
end;

procedure TFrmVisualFileManager.AnimationDurationChange(Sender: TObject);
begin
  SaveSettings;
  if ThumbnailEffectTimer.Enabled and (FThumbnailEffectMode >= 3) then
    StartThumbnailEffect;
end;

procedure TFrmVisualFileManager.ThumbnailAnimationChange(Sender: TObject);
begin
  ThumbnailEffectTimer.Enabled := False;
  FileList.Align := alClient;
  AlphaBlend := False;
  { VCL list views do not have GPU alpha transitions. These modes control
    safe staged publishing of the virtual image list instead. }
  case AnimationBox.ItemIndex of
    2: ThumbnailTimer.Interval := 90;  { one card at a time }
  else
    ThumbnailTimer.Interval := 30;      { compact or grouped reveal }
  end;
  SaveSettings;

  { Apply slide/fade choices immediately when a thumbnail page is already
    visible. Loading effects for the other modes apply to the next queue. }
  if (AnimationBox.ItemIndex >= 3) and (ViewBox.ItemIndex = 1) and
    (FThumbnailIndexes.Count > 0) then
    StartThumbnailEffect;
end;

function TFrmVisualFileManager.ActiveThumbnailImages: TImageList;
begin
  case FrameSizeBox.ItemIndex of
    1: Result := ThumbnailImagesLarge;
    2: Result := ThumbnailImagesXLarge;
  else
    Result := ThumbnailImages;
  end;
end;

function TFrmVisualFileManager.ActiveThumbnailStagingImages: TImageList;
begin
  case FrameSizeBox.ItemIndex of
    1: Result := ThumbnailStagingImagesLarge;
    2: Result := ThumbnailStagingImagesXLarge;
  else
    Result := ThumbnailStagingImages;
  end;
end;

function TFrmVisualFileManager.ThumbnailFrameScale: Double;
begin
  Result := ActiveThumbnailImages.Width / 160.0;
end;

procedure TFrmVisualFileManager.ApplyThumbnailGridSpacing;
var
  SpacingX, SpacingY: Integer;
begin
  { A larger label needs a larger icon cell.  This keeps virtual-list
    thumbnail captions from touching the next row or column. }
  SpacingX := Max(ActiveThumbnailImages.Width + 30,
    ActiveThumbnailImages.Width + (FileList.Font.Size * 3));
  SpacingY := Max(ActiveThumbnailImages.Height + 35,
    ActiveThumbnailImages.Height + (FileList.Font.Size * 4));
  if FileList.HandleAllocated then
  begin
    SendMessage(FileList.Handle, LVM_SETICONSPACING, 0,
      NativeInt((SpacingX and $FFFF) or ((SpacingY and $FFFF) shl 16)));
    if FileList.ViewStyle = vsIcon then
      FileList.Arrange(arDefault);
  end;
end;

procedure TFrmVisualFileManager.ReflowThumbnailGrid;
var
  ListStyle: Longint;
begin
  if (ViewBox.ItemIndex <> 1) or not FileList.HandleAllocated then
    Exit;
  { TListView in Delphi 10.2 does not publish AutoArrange/Alignment. Set the
    native style at runtime without serializing unsupported DFM properties. }
  ListStyle := GetWindowLong(FileList.Handle, GWL_STYLE);
  ListStyle := ListStyle or LVS_AUTOARRANGE;
  SetWindowLong(FileList.Handle, GWL_STYLE, ListStyle);
  SendMessage(FileList.Handle, LVM_ARRANGE, LVA_DEFAULT, 0);
  if FVisibleItems.Count > 0 then
    SendMessage(FileList.Handle, LVM_ENSUREVISIBLE, 0, 0);
  FileList.Invalidate;
end;

procedure TFrmVisualFileManager.RefreshThumbnailFrames;
var
  VisibleIndex: Integer;
begin
  if (ViewBox.ItemIndex <> 1) or (FVisibleItems.Count = 0) then
    Exit;
  FThumbnailIndexes.Clear;
  FQueuedThumbnailFiles.Clear;
  FThumbnailQueue.Clear;
  FThumbnailQueuePosition := 0;
  ActiveThumbnailImages.Clear;
  ActiveThumbnailStagingImages.Clear;
  FPlaceholderIndexes.Clear;
  PreparePlaceholderImages;
  VisibleIndex := 0;
  if Assigned(FileList.TopItem) then
    VisibleIndex := FileList.TopItem.Index;
  QueueThumbnailPage(VisibleIndex);
  FileList.Invalidate;
end;

procedure TFrmVisualFileManager.ApplyFileTextSize;
begin
  FileList.ParentFont := False;
  FileList.Font.Name := 'Tahoma';
  FileList.Font.Size := 10 + (FontSizeBox.ItemIndex * 2);
  ApplyThumbnailGridSpacing;
  RefreshThumbnailFrames;
  FileList.Invalidate;
end;

procedure TFrmVisualFileManager.FrameSizeChange(Sender: TObject);
begin
  ThumbnailTimer.Enabled := False;
  FThumbnailIndexes.Clear;
  FQueuedThumbnailFiles.Clear;
  FThumbnailQueue.Clear;
  FThumbnailQueuePosition := 0;
  FPlaceholderIndexes.Clear;
  ActiveThumbnailImages.Clear;
  ActiveThumbnailStagingImages.Clear;
  PreparePlaceholderImages;
  FileList.LargeImages := ActiveThumbnailImages;
  ApplyThumbnailGridSpacing;
  ReflowThumbnailGrid;
  RefreshThumbnailFrames;
  SaveSettings;
end;

procedure TFrmVisualFileManager.FontSizeChange(Sender: TObject);
begin
  ApplyFileTextSize;
  SaveSettings;
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
  ApplyFileCheckboxes;
  SaveSettings;
  if ViewBox.ItemIndex = 1 then
  begin
    FileList.ViewStyle := vsIcon;
    ApplyThumbnailGridSpacing;
    ReflowThumbnailGrid;
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
  if (FirstIndex = 0) and not FThumbnailPageAnimationPlayed then
    FInitialThumbnailPageEnd := FThumbnailQueue.Count;
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
  FInitialThumbnailPageEnd := 0;
  FThumbnailPageAnimationPlayed := False;
  Query := Trim(SearchEdit.Text);
  for I := 0 to FFiles.Count - 1 do
  begin
    if (Query = '') or ContainsText(FFiles[I].DisplayName, Query) then
      AddVisibleFile(I);
  end;
  QueueThumbnailPage(0);
  FileList.Items.Count := FVisibleItems.Count;
  if ViewBox.ItemIndex = 1 then
    ReflowThumbnailGrid;
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
  { The cached source image remains JPEG; the filename drawn on its frame is
    always rebuilt from the original file record at the selected text size. }
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
  ImageIndex, CaptionTop, ImageBottom: Integer;
  CaptionText: string;
  CaptionArea: TRect;
  FrameScale: Double;
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
    try
      Picture.LoadFromFile(CacheFile);
    except
      { A stopped video/image extraction can leave an empty JPEG in the
        cache. Recreate only that cache item instead of silently hiding it. }
      DeleteFile(CacheFile);
      CreateGenericThumbnail(FFiles[AIndex], CacheFile);
      Picture.LoadFromFile(CacheFile);
    end;

    { Every active list has a fixed designer-owned size. The card and source
      image use the same scale, without resizing any image list at runtime. }
    FrameScale := ThumbnailFrameScale;
    Bitmap.SetSize(ActiveThumbnailImages.Width, ActiveThumbnailImages.Height);
    Bitmap.Canvas.Brush.Style := bsSolid;
    Bitmap.Canvas.Brush.Color := $00E7EDF2;
    Bitmap.Canvas.FillRect(Rect(0, 0, Bitmap.Width, Bitmap.Height));

    { Offset shadow and the thick white Polaroid border. }
    Bitmap.Canvas.Brush.Color := $0089959F;
    Bitmap.Canvas.FillRect(Rect(Round(8 * FrameScale), Round(8 * FrameScale),
      Bitmap.Width - Round(2 * FrameScale), Bitmap.Height - Round(FrameScale)));
    Bitmap.Canvas.Brush.Color := clWhite;
    Bitmap.Canvas.FillRect(Rect(Round(2 * FrameScale), Round(2 * FrameScale),
      Bitmap.Width - Round(8 * FrameScale), Bitmap.Height - Round(4 * FrameScale)));
    Bitmap.Canvas.Pen.Color := $00CCD2D6;
    Bitmap.Canvas.Brush.Style := bsClear;
    Bitmap.Canvas.Rectangle(Round(2 * FrameScale), Round(2 * FrameScale),
      Bitmap.Width - Round(8 * FrameScale), Bitmap.Height - Round(4 * FrameScale));

    { The only visible filename is inside the Polaroid frame.  More selected
      text size reserves more room here and shrinks the image area slightly. }
    CaptionTop := Round((96 - (FontSizeBox.ItemIndex * 4)) * FrameScale);
    ImageBottom := CaptionTop - Round(4 * FrameScale);
    Bitmap.Canvas.StretchDraw(Rect(Round(8 * FrameScale), Round(8 * FrameScale),
      Bitmap.Width - Round(14 * FrameScale), ImageBottom), Picture.Graphic);
    Bitmap.Canvas.Pen.Color := $00939AA0;
    Bitmap.Canvas.Rectangle(Round(7 * FrameScale), Round(7 * FrameScale),
      Bitmap.Width - Round(13 * FrameScale), ImageBottom + Round(FrameScale));
    CaptionText := ChangeFileExt(FFiles[AIndex].DisplayName, '');
    Bitmap.Canvas.Font.Name := 'Tahoma';
    Bitmap.Canvas.Font.Size := Round((6 + FontSizeBox.ItemIndex) * FrameScale);
    Bitmap.Canvas.Font.Color := $004A535A;
    Bitmap.Canvas.Brush.Style := bsClear;
    CaptionArea := Rect(Round(8 * FrameScale), CaptionTop,
      Bitmap.Width - Round(14 * FrameScale), Bitmap.Height - Round(6 * FrameScale));
    DrawText(Bitmap.Canvas.Handle, PChar(CaptionText), Length(CaptionText),
      CaptionArea, DT_CENTER or DT_WORDBREAK or DT_END_ELLIPSIS);
    Bitmap.Canvas.Pen.Color := clWhite;
    Bitmap.Canvas.MoveTo(Round(3 * FrameScale), Round(3 * FrameScale));
    Bitmap.Canvas.LineTo(Bitmap.Width - Round(10 * FrameScale), Round(3 * FrameScale));
    Bitmap.Canvas.LineTo(Bitmap.Width - Round(10 * FrameScale),
      Bitmap.Height - Round(6 * FrameScale));

    ImageIndex := ActiveThumbnailImages.Add(Bitmap, nil);
    FThumbnailIndexes.Add(FFiles[AIndex].FullName, ImageIndex);
    FThumbnailImagesDirty := True;
  except
    { Keep the list responsive; the generic placeholder remains available. }
  end;
  Bitmap.Free;
  Picture.Free;
end;

procedure TFrmVisualFileManager.RedrawThumbnailItem(
  const AFileIndex: Integer);
var
  VisibleIndex: Integer;
begin
  { Repaint only the cell whose active image was just added. }
  VisibleIndex := FVisibleItems.IndexOf(AFileIndex);
  if (VisibleIndex >= 0) and FileList.HandleAllocated then
    SendMessage(FileList.Handle, LVM_REDRAWITEMS, VisibleIndex, VisibleIndex);
end;

procedure TFrmVisualFileManager.ThumbnailTimerTick(Sender: TObject);
var
  FileIndex, LoadedCount, ItemsPerTick: Integer;
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
  if AnimationBox.ItemIndex = 2 then
    ItemsPerTick := 1
  else
    ItemsPerTick := 4;
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

    { Existing cached thumbnails are cheap to load. The selected mode
      determines whether the staged image list is published as a group or
      one card at a time. }
    if (AnimationBox.ItemIndex = 2) and FThumbnailImagesDirty then
    begin
      PublishThumbnails;
      Break;
    end;
    if not WasCached or (LoadedCount >= ItemsPerTick) then
      Break;
  end;

  if (AnimationBox.ItemIndex = 1) and FThumbnailImagesDirty then
    PublishThumbnails;

  TryStartThumbnailPageAnimation;

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
  I, J, OldCount: Integer;
  Query: string;
  AlreadyVisible: Boolean;
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

    if FFiles.Count = OldCount then
      Exit;

    { Do not rebuild the OwnerData list here. Only append the genuinely new
      records, which keeps the existing icon layout and virtual cache intact. }
    Query := Trim(SearchEdit.Text);
    for I := OldCount to FFiles.Count - 1 do
    begin
      if (Query = '') or ContainsText(FFiles[I].DisplayName, Query) then
      begin
        { The directory notification may be repeated by Windows. Keep the
          virtual list unique even if a duplicate record reaches this point. }
        AlreadyVisible := False;
        for J := 0 to FVisibleItems.Count - 1 do
          if SameText(FFiles[FVisibleItems[J]].FullName, FFiles[I].FullName) then
          begin
            AlreadyVisible := True;
            Break;
          end;
        if not AlreadyVisible then begin
          AddVisibleFile(I);
          beep;
        end;

      end;
      QueueThumbnail(I);
    end;
    SortVisibleByNewest;

    { Sorting moves the old virtual indices. Explicitly invalidate those
      OwnerData rows; changing only Items.Count leaves stale cached captions
      and images on some VCL/Windows combinations. }
    FileList.Items.Count := FVisibleItems.Count;
    if FileList.HandleAllocated and (FVisibleItems.Count > 0) then
    begin
      SendMessage(FileList.Handle, LVM_REDRAWITEMS, 0,
        FVisibleItems.Count - 1);
      FileList.Invalidate;
    end;
    if FThumbnailQueuePosition < FThumbnailQueue.Count then
      ThumbnailTimer.Enabled := True;
    StatusLabel.Caption := Format('%d yeni dosya algilandi.',
      [FFiles.Count - OldCount]);
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
  if ViewBox.ItemIndex = 1 then
    Item.Caption := ''
  else
    Item.Caption := FileEntry.DisplayName;
  if FMarkedFiles.ContainsKey(FileEntry.FullName) then
    Item.StateIndex := 2
  else
    Item.StateIndex := 1;
  Item.SubItems.Clear;
  Item.SubItems.Add(FileEntry.Extension);
  Item.SubItems.Add(FileSizeText(FileEntry.Size));
  Item.SubItems.Add(DateTimeToStr(FileEntry.ModifiedAt));
  Item.SubItems.Add(FileEntry.FolderName);
  Item.SubItems.Add(FileEntry.FullName);
  if FThumbnailIndexes.TryGetValue(FileEntry.FullName, ImageIndex) and
    (ImageIndex < ActiveThumbnailImages.Count) then
    Item.ImageIndex := ImageIndex
  else
    Item.ImageIndex := PlaceholderImageIndex(FileEntry);
  if ViewBox.ItemIndex = 1 then
    QueueThumbnailPage(Item.Index);
end;

procedure TFrmVisualFileManager.DeleteClick(Sender: TObject);
var
  I, Position, Index, SelectedCount: Integer;
  DeleteSource, FirstFileName, DeleteNames: string;
  Operation: TSHFileOpStruct;
  SelectedFiles: TDictionary<string, Boolean>;
begin
  if Assigned(FScanWorker) or Assigned(FVideoWorker) then
  begin
    MessageDlg('Tarama veya kucuk resim islemi tamamlanana kadar silme yapilamaz.',
      mtInformation, [mbOK], 0);
    Exit;
  end;

  SelectedFiles := TDictionary<string, Boolean>.Create;
  try
    DeleteSource := '';
    DeleteNames := '';
    FirstFileName := '';
    for I := 0 to FileList.Items.Count - 1 do
      if (I < FVisibleItems.Count) and
        FMarkedFiles.ContainsKey(FFiles[FVisibleItems[I]].FullName) then
      begin
        Position := I;
        Index := FVisibleItems[Position];
        if (Index >= 0) and (Index < FFiles.Count) and
          not SelectedFiles.ContainsKey(FFiles[Index].FullName) then
        begin
          SelectedFiles.Add(FFiles[Index].FullName, True);
          DeleteSource := DeleteSource + FFiles[Index].FullName + #0;
          DeleteNames := DeleteNames + ExtractFileName(FFiles[Index].FullName) +
            sLineBreak;
          if FirstFileName = '' then
            FirstFileName := FFiles[Index].FullName;
        end;
      end;

    SelectedCount := SelectedFiles.Count;
    if SelectedCount = 0 then
    begin
      MessageDlg('Silmek icin dosyalarin yanindaki kutulari isaretleyin.',
        mtInformation, [mbOK], 0);
      Exit;
    end;

    if MessageDlg(Format('%d isaretli dosya Geri Donusum Kutusu''na tasinacak. Devam edilsin mi?',
      [SelectedCount]), mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
      Exit;

    if MessageDlg(Format('Son onay: %d isaretli dosya silinecek:' +
      sLineBreak + sLineBreak + '%s' + sLineBreak +
      'Onayliyor musunuz?', [SelectedCount, DeleteNames]), mtWarning,
      [mbYes, mbNo], 0) <> mrYes then
      Exit;

    DeleteSource := DeleteSource + #0;
    ZeroMemory(@Operation, SizeOf(Operation));
    Operation.Wnd := Handle;
    Operation.wFunc := FO_DELETE;
    Operation.pFrom := PChar(DeleteSource);
    Operation.fFlags := FOF_ALLOWUNDO or FOF_NOCONFIRMATION or FOF_SILENT;

    if (SHFileOperation(Operation) <> 0) or Operation.fAnyOperationsAborted then
    begin
      MessageDlg('Dosyalardan biri silinemedi.', mtError, [mbOK], 0);
      Exit;
    end;

    for I := FFiles.Count - 1 downto 0 do
      if SelectedFiles.ContainsKey(FFiles[I].FullName) then
      begin
        FKnownFiles.Remove(CanonicalFileName(FFiles[I].FullName));
        FMarkedFiles.Remove(FFiles[I].FullName);
        FFiles.Delete(I);
      end;
    Render;
    StatusLabel.Caption := Format('%d dosya Geri Donusum Kutusu''na tasindi.',
      [SelectedCount]);
  finally
    SelectedFiles.Free;
  end;
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
    OpenSelectedFile
  else
    ToggleSelectedFileMark;
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
