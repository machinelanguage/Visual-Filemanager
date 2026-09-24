program VisualFileManager;

uses
  Vcl.Forms,
  MainForm in 'MainForm.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  CreateVisualFileManager;
  Application.Run;
end.
