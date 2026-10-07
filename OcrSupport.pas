unit OcrSupport;

interface

function TryOcrPdfFirstPage(const AFileName: string; out AText: string): Boolean;

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
begin
  Result := '';
  if SearchPath(nil, PChar(AFileName), nil, MAX_PATH, Buffer, nil) > 0 then
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
  Result := FindInPath('pdftoppm.exe');
  if Result <> '' then
    Exit;
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

function TryOcrPdfFirstPage(const AFileName: string; out AText: string): Boolean;
var
  Tesseract, Pdftoppm, TempFolder, BaseName, ImageName, OutputBase: string;
  RenderCommand, OcrCommand: string;
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
  ImageName := BaseName + '.png';
  OutputBase := BaseName + '_ocr';
  RenderCommand := QuoteArg(Pdftoppm) + ' -f 1 -l 1 -r 160 -singlefile -png ' +
    QuoteArg(AFileName) + ' ' + QuoteArg(BaseName);
  OcrCommand := QuoteArg(Tesseract) + ' ' + QuoteArg(ImageName) + ' ' +
    QuoteArg(OutputBase) + ' -l tur+eng --psm 6';
  try
    if RunHidden(RenderCommand, TempFolder) and FileExists(ImageName) and
      RunHidden(OcrCommand, TempFolder) and FileExists(OutputBase + '.txt') then
    begin
      AText := TFile.ReadAllText(OutputBase + '.txt', TEncoding.UTF8);
      Result := Trim(AText) <> '';
    end;
  finally
    if FileExists(ImageName) then
      TFile.Delete(ImageName);
    if FileExists(OutputBase + '.txt') then
      TFile.Delete(OutputBase + '.txt');
  end;
end;

end.
