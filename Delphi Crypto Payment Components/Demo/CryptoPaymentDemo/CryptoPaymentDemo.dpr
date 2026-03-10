program CryptoPaymentDemo;

uses
  Vcl.Forms,
  MainForm in 'MainForm.pas' {frmMain},
  CPC.Types in '..\..\Source\CPC.Types.pas',
  CPC.Coin.Base in '..\..\Source\CPC.Coin.Base.pas',
  CPC.Engine in '..\..\Source\CPC.Engine.pas',
  CPC.Coin.Bitcoin in '..\..\Source\CPC.Coin.Bitcoin.pas',
  CPC.Coin.Ethereum in '..\..\Source\CPC.Coin.Ethereum.pas',
  CPC.Coin.Litecoin in '..\..\Source\CPC.Coin.Litecoin.pas',
  CPC.Coin.Dogecoin in '..\..\Source\CPC.Coin.Dogecoin.pas',
  CPC.Coin.BitcoinCash in '..\..\Source\CPC.Coin.BitcoinCash.pas',
  Vcl.Themes,
  Vcl.Styles;

{$R *.res}

begin
  ReportMemoryLeaksOnShutdown := True;
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  TStyleManager.TrySetStyle('Carbon');
  Application.Title := 'Crypto Payment Demo';
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.
