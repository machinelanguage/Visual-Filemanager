unit ThumbnailSupport;

interface

uses
  System.SysUtils;

function ThumbnailCacheFileName(const AFolder, AFileName: string;
  const ASize: Int64; const AModifiedAt: TDateTime): string;
function CreateThumbnailFile(const AFileName, ATopic, AOutputFile: string): Boolean;

implementation

uses
  System.Classes, System.IOUtils, System.StrUtils, System.Math, System.Types,
  Vcl.Graphics,
  Vcl.Imaging.jpeg, Vcl.Imaging.pngimage, Vcl.Imaging.GIFImg, OcrSupport;

function HashText(const S: string): Cardinal;
var I: Integer;
begin
  Result := 2166136261;
  for I := 1 to Length(S) do begin Result := Result xor Ord(S[I]); Result := Result * 16777619; end;
end;

function ThumbnailCacheFileName(const AFolder, AFileName: string;
  const ASize: Int64; const AModifiedAt: TDateTime): string;
begin
  Result := TPath.Combine(AFolder, IntToHex(HashText(AFileName + '|' +
    IntToStr(ASize) + '|' + IntToStr(Trunc(AModifiedAt * 86400000))), 8) + '.bmp');
end;

procedure SaveGenericThumbnail(const AFileName, ATopic, AOutputFile: string);
var B: TBitmap; Ext: string;
begin
  B := TBitmap.Create;
  try
    B.SetSize(220, 140); B.Canvas.Brush.Color := $00E8EEF5;
    B.Canvas.FillRect(Rect(0, 0, B.Width, B.Height));
    B.Canvas.Brush.Color := $0090A4B8; B.Canvas.FillRect(Rect(0, 0, B.Width, 8));
    Ext := UpperCase(Copy(ExtractFileExt(AFileName), 2, 9)); if Ext = '' then Ext := 'DOSYA';
    B.Canvas.Font.Color := clWhite; B.Canvas.Font.Size := 20; B.Canvas.Font.Style := [fsBold];
    B.Canvas.TextOut(16, 38, Ext); B.Canvas.Font.Color := $00405060; B.Canvas.Font.Size := 10;
    B.Canvas.Font.Style := []; B.Canvas.TextOut(16, 82, Copy(ATopic, 1, 26));
    ForceDirectories(ExtractFilePath(AOutputFile)); B.SaveToFile(AOutputFile);
  finally B.Free; end;
end;

procedure SaveGraphicThumbnail(const ASourceFile, AOutputFile: string);
var P: TPicture; B: TBitmap; Scale: Double; W, H, L, T: Integer;
begin
  P := TPicture.Create; B := TBitmap.Create;
  try
    P.LoadFromFile(ASourceFile); B.SetSize(220, 140); B.Canvas.Brush.Color := clWhite;
    B.Canvas.FillRect(Rect(0, 0, B.Width, B.Height));
    Scale := Min(B.Width / P.Graphic.Width, B.Height / P.Graphic.Height);
    W := Round(P.Graphic.Width * Scale); H := Round(P.Graphic.Height * Scale);
    L := (B.Width - W) div 2; T := (B.Height - H) div 2;
    B.Canvas.StretchDraw(Rect(L, T, L + W, T + H), P.Graphic);
    ForceDirectories(ExtractFilePath(AOutputFile)); B.SaveToFile(AOutputFile);
  finally B.Free; P.Free; end;
end;

function CreateThumbnailFile(const AFileName, ATopic, AOutputFile: string): Boolean;
var Ext, TempPng: string;
begin
  Result := False; if FileExists(AOutputFile) then Exit(True);
  Ext := LowerCase(ExtractFileExt(AFileName));
  try
    if MatchText(Ext, ['.bmp', '.jpg', '.jpeg', '.png', '.gif']) then
      SaveGraphicThumbnail(AFileName, AOutputFile)
    else if Ext = '.pdf' then begin
      TempPng := ChangeFileExt(AOutputFile, '.png');
      try
        if not RenderPdfThumbnail(AFileName, TempPng) then Exit;
        SaveGraphicThumbnail(TempPng, AOutputFile);
      finally if FileExists(TempPng) then TFile.Delete(TempPng); end;
    end else SaveGenericThumbnail(AFileName, ATopic, AOutputFile);
    Result := FileExists(AOutputFile);
  except Result := False; end;
end;

end.
