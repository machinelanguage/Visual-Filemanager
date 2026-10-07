unit OcrSupport;

interface

function TryOcrPdfPages(const AFileName: string; out AText: string): Boolean;

implementation

uses
  Winapi.Windows, System.SysUtils, System.Classes, System.IOUtils;

function QuoteArg(const AValue: string): string;
begin
  Result := '"' + AValue + '"';
end;

function FindInPath(const AFileName: string): string;
var
  Buffer: array[0..MAX_PATH] of Char;
  FilePart: PChar;
begin
  Result := '';
  FilePart := nil;
  if SearchPath(nil, PChar(AFileName), nil, MAX_PATH, PChar(@Buffer[0]),
    FilePart) > 0 then
    Result := Buffer;
end;

function FindTesseract: string;
begin
  Result := FindInPath('tesseract.exe');
  if (Result = '') and FileExists('C:\Program Files\Tesseract-OCR\tesseract.exe') then
    Result := 'C:\Program Files\Tesseract-OCR\tesseract.exe';
end;

function FindPdftoppm: string;
var
  Root: string;
  Files: TArray<string>;
begin
  Result := '';
  Root := TPath.Combine(GetEnvironmentVariable('LOCALAPPDATA'),
    'Microsoft\WinGet\Packages');
  if DirectoryExists(Root) then
  begin
    try
      Files := TDirectory.GetFiles(Root, 'pdftoppm.exe',
        TSearchOption.soAllDirectories);
      if Length(Files) > 0 then
        Result := Files[0];
    except
      Result := '';
    end;
  end;
  if Result = '' then
    Result := FindInPath('pdftoppm.exe');
end;

function RunHidden(const ACommandLine, AWorkFolder: string): Boolean;
var
  StartInfo: TStartupInfo;
  ProcessInfo: TProcessInformation;
  CommandLine: string;
  ExitCode: Cardinal;
begin
  Result := False;
  CommandLine := ACommandLine;
  UniqueString(CommandLine);
  ZeroMemory(@StartInfo, SizeOf(StartInfo));
  ZeroMemory(@ProcessInfo, SizeOf(ProcessInfo));
  StartInfo.cb := SizeOf(StartInfo);
  StartInfo.dwFlags := STARTF_USESHOWWINDOW;
  StartInfo.wShowWindow := SW_HIDE;
  if CreateProcess(nil, PChar(CommandLine), nil, nil, False, CREATE_NO_WINDOW,
    nil, PChar(AWorkFolder), StartInfo, ProcessInfo) then
  try
    WaitForSingleObject(ProcessInfo.hProcess, INFINITE);
    GetExitCodeProcess(ProcessInfo.hProcess, ExitCode);
    Result := ExitCode = 0;
  finally
    CloseHandle(ProcessInfo.hThread);
    CloseHandle(ProcessInfo.hProcess);
  end;
end;

function TryOcrPdfPages(const AFileName: string; out AText: string): Boolean;
var
  Tesseract, Pdftoppm, TempFolder, BaseName, OutputBase, PageText: string;
  RenderCommand, OcrCommand: string;
  ImageFiles, TextFiles: TArray<string>;
  I: Integer;
begin
  Result := False;
  AText := '';
  Tesseract := FindTesseract;
  Pdftoppm := FindPdftoppm;
  if (Tesseract = '') or (Pdftoppm = '') then
    Exit;
  TempFolder := TPath.Combine(TPath.GetTempPath, 'VisualFileManagerOcr');
  ForceDirectories(TempFolder);
  BaseName := TPath.Combine(TempFolder, 'page_' + IntToHex(GetTickCount, 8));
  RenderCommand := QuoteArg(Pdftoppm) + ' -f 1 -l 3 -r 160 -png ' +
    QuoteArg(AFileName) + ' ' + QuoteArg(BaseName);
  try
    if RunHidden(RenderCommand, TempFolder) then
    begin
      ImageFiles := TDirectory.GetFiles(TempFolder,
        ExtractFileName(BaseName) + '-*.png');
      for I := 0 to High(ImageFiles) do
      begin
        OutputBase := ChangeFileExt(ImageFiles[I], '') + '_ocr';
        OcrCommand := QuoteArg(Tesseract) + ' ' + QuoteArg(ImageFiles[I]) + ' ' +
          QuoteArg(OutputBase) + ' -l tur+eng --psm 6';
        if RunHidden(OcrCommand, TempFolder) and FileExists(OutputBase + '.txt') then
        begin
          PageText := TFile.ReadAllText(OutputBase + '.txt', TEncoding.UTF8);
          if Trim(PageText) <> '' then
            AText := AText + PageText + sLineBreak;
        end;
      end;
      Result := Trim(AText) <> '';
    end;
  finally
    ImageFiles := TDirectory.GetFiles(TempFolder,
      ExtractFileName(BaseName) + '-*.png');
    for I := 0 to High(ImageFiles) do
      if FileExists(ImageFiles[I]) then
        TFile.Delete(ImageFiles[I]);
    TextFiles := TDirectory.GetFiles(TempFolder,
      ExtractFileName(BaseName) + '-*_ocr.txt');
    for I := 0 to High(TextFiles) do
      if FileExists(TextFiles[I]) then
        TFile.Delete(TextFiles[I]);
  end;
end;

end.
