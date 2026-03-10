unit MainForm;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants,
  System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,
  Vcl.StdCtrls, Vcl.ComCtrls, Vcl.ExtCtrls,
  CPC.Types, CPC.Coin.Base, CPC.Engine,
  CPC.Coin.Bitcoin, CPC.Coin.Ethereum, CPC.Coin.Litecoin,
  CPC.Coin.Dogecoin, CPC.Coin.BitcoinCash;

type
  TfrmMain = class(TForm)
    { -- VCL Controls (placed via DFM) -- }
    PageControl1: TPageControl;
    tsSetup: TTabSheet;
    tsPayments: TTabSheet;
    tsLog: TTabSheet;
    gbEngine: TGroupBox;
    lblPolling: TLabel;
    edtPollingInterval: TEdit;
    chkActive: TCheckBox;
    gbCoins: TGroupBox;
    lblBTCAddr: TLabel;
    edtBTCAddress: TEdit;
    lblETHAddr: TLabel;
    edtETHAddress: TEdit;
    lblLTCAddr: TLabel;
    edtLTCAddress: TEdit;
    lblDOGEAddr: TLabel;
    edtDOGEAddress: TEdit;
    lblBCHAddr: TLabel;
    edtBCHAddress: TEdit;
    btnApplySettings: TButton;
    gbCreatePayment: TGroupBox;
    lblCoin: TLabel;
    cbCoinSelect: TComboBox;
    lblAmount: TLabel;
    edtAmount: TEdit;
    lblRef: TLabel;
    edtExternalRef: TEdit;
    btnCreatePayment: TButton;
    lvPayments: TListView;
    btnCheckAll: TButton;
    btnRefreshList: TButton;
    memoLog: TMemo;
    btnClearLog: TButton;
    StatusBar1: TStatusBar;
    { -- Crypto Payment Components (placed via DFM, drag-drop) -- }
    CryptoEngine1: TCryptoEngine;
    BitcoinCoin1: TBitcoinCoin;
    EthereumCoin1: TEthereumCoin;
    LitecoinCoin1: TLitecoinCoin;
    DogecoinCoin1: TDogecoinCoin;
    BitcoinCashCoin1: TBitcoinCashCoin;
    { -- Event Handlers -- }
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure btnApplySettingsClick(Sender: TObject);
    procedure btnCreatePaymentClick(Sender: TObject);
    procedure btnCheckAllClick(Sender: TObject);
    procedure btnRefreshListClick(Sender: TObject);
    procedure btnClearLogClick(Sender: TObject);
    procedure chkActiveClick(Sender: TObject);
    procedure CryptoEngine1Log(Sender: TObject; const AMessage: string);
    procedure CryptoEngine1PaymentCreated(Sender: TObject; const ACoin: TObject;
      const APayment: TCPCPayment);
    procedure CryptoEngine1PaymentDetected(Sender: TObject; const ACoin: TObject;
      const APayment: TCPCPayment);
    procedure CryptoEngine1PaymentConfirmed(Sender: TObject; const ACoin: TObject;
      const APayment: TCPCPayment);
    procedure CryptoEngine1PaymentExpired(Sender: TObject; const ACoin: TObject;
      const APayment: TCPCPayment);
    procedure CryptoEngine1Error(Sender: TObject; const ACoin: TObject;
      const APaymentID, AErrorMessage: string);
  private
    procedure RefreshPaymentList;
    procedure Log(const AMsg: string);
    function GetSelectedCoin: TCPCCoinBase;
  end;

var
  frmMain: TfrmMain;

implementation

{$R *.dfm}

procedure TfrmMain.FormCreate(Sender: TObject);
begin
  cbCoinSelect.Items.Clear;
  cbCoinSelect.Items.Add('BTC - Bitcoin');
  cbCoinSelect.Items.Add('ETH - Ethereum');
  cbCoinSelect.Items.Add('LTC - Litecoin');
  cbCoinSelect.Items.Add('DOGE - Dogecoin');
  cbCoinSelect.Items.Add('BCH - Bitcoin Cash');
  cbCoinSelect.ItemIndex := 0;

  Log('Crypto Payment Demo started.');
  Log('1. Enter your receive addresses in the Setup tab.');
  Log('2. Click "Apply Settings" to configure the coins.');
  Log('3. Check "Engine Active" to start auto-polling.');
  Log('4. Go to Payments tab to create payment requests.');
end;

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
  CryptoEngine1.Active := False;
end;

procedure TfrmMain.btnApplySettingsClick(Sender: TObject);
begin
  BitcoinCoin1.ReceiveAddress := Trim(edtBTCAddress.Text);
  EthereumCoin1.ReceiveAddress := Trim(edtETHAddress.Text);
  LitecoinCoin1.ReceiveAddress := Trim(edtLTCAddress.Text);
  DogecoinCoin1.ReceiveAddress := Trim(edtDOGEAddress.Text);
  BitcoinCashCoin1.ReceiveAddress := Trim(edtBCHAddress.Text);

  CryptoEngine1.PollingIntervalMs := StrToIntDef(edtPollingInterval.Text, 15000);

  Log('Settings applied.');
  StatusBar1.SimpleText := 'Settings applied. Registered coins: ' +
    string.Join(', ', CryptoEngine1.GetRegisteredCoinSymbols);
end;

procedure TfrmMain.chkActiveClick(Sender: TObject);
begin
  CryptoEngine1.Active := chkActive.Checked;
  if CryptoEngine1.Active then
    Log('Engine activated - polling every ' +
      IntToStr(CryptoEngine1.PollingIntervalMs) + 'ms')
  else
    Log('Engine deactivated');
end;

procedure TfrmMain.btnCreatePaymentClick(Sender: TObject);
var
  Coin: TCPCCoinBase;
  Amount: Double;
  PaymentID: string;
begin
  Coin := GetSelectedCoin;
  if Coin = nil then
  begin
    ShowMessage('Please select a coin.');
    Exit;
  end;

  if Trim(Coin.ReceiveAddress) = '' then
  begin
    ShowMessage('Please set a receive address for ' + Coin.CoinSymbol +
      ' in the Setup tab first.');
    Exit;
  end;

  Amount := StrToFloatDef(edtAmount.Text, 0);
  if Amount <= 0 then
  begin
    ShowMessage('Please enter a valid amount.');
    Exit;
  end;

  try
    PaymentID := Coin.CreatePayment(Amount, Trim(edtExternalRef.Text));
    Log(Format('Created %s payment: %s for %.8f', [Coin.CoinSymbol, PaymentID, Amount]));
    RefreshPaymentList;
    PageControl1.ActivePage := tsPayments;
  except
    on E: Exception do
      ShowMessage('Error creating payment: ' + E.Message);
  end;
end;

procedure TfrmMain.btnCheckAllClick(Sender: TObject);
begin
  Log('Manually checking all pending payments...');
  CryptoEngine1.CheckAllPending;
  RefreshPaymentList;
end;

procedure TfrmMain.btnRefreshListClick(Sender: TObject);
begin
  RefreshPaymentList;
end;

procedure TfrmMain.btnClearLogClick(Sender: TObject);
begin
  memoLog.Clear;
end;

function TfrmMain.GetSelectedCoin: TCPCCoinBase;
begin
  case cbCoinSelect.ItemIndex of
    0: Result := BitcoinCoin1;
    1: Result := EthereumCoin1;
    2: Result := LitecoinCoin1;
    3: Result := DogecoinCoin1;
    4: Result := BitcoinCashCoin1;
  else
    Result := nil;
  end;
end;

procedure TfrmMain.RefreshPaymentList;
var
  Coins: TArray<TCPCCoinBase>;
  Coin: TCPCCoinBase;
  Payments: TCPCPaymentArray;
  P: TCPCPayment;
  Item: TListItem;
begin
  lvPayments.Items.BeginUpdate;
  try
    lvPayments.Items.Clear;
    Coins := CryptoEngine1.GetRegisteredCoins;

    for Coin in Coins do
    begin
      Payments := Coin.ListPayments;
      for P in Payments do
      begin
        Item := lvPayments.Items.Add;
        Item.Caption := P.CoinSymbol;
        Item.SubItems.Add(Copy(P.PaymentID, 1, 12) + '...');
        Item.SubItems.Add(P.ReceiveAddress);
        Item.SubItems.Add(FormatFloat('0.########', P.ExpectedAmount));
        Item.SubItems.Add(FormatFloat('0.########', P.DetectedAmount));
        Item.SubItems.Add(P.Status.ToString);
        Item.SubItems.Add(Format('%d/%d', [P.Confirmations, P.RequiredConfirmations]));
        if P.TxHash <> '' then
          Item.SubItems.Add(Copy(P.TxHash, 1, 16) + '...')
        else
          Item.SubItems.Add('');
        Item.SubItems.Add(P.ExternalRef);
      end;
    end;

    StatusBar1.SimpleText := Format('Total payments: %d | Active: %d',
      [lvPayments.Items.Count, CryptoEngine1.TotalActivePayments]);
  finally
    lvPayments.Items.EndUpdate;
  end;
end;

procedure TfrmMain.Log(const AMsg: string);
begin
  memoLog.Lines.Add(FormatDateTime('hh:nn:ss', Now) + ' | ' + AMsg);
end;

{ Engine Events - wired via DFM Object Inspector }

procedure TfrmMain.CryptoEngine1Log(Sender: TObject; const AMessage: string);
begin
  Log(AMessage);
end;

procedure TfrmMain.CryptoEngine1PaymentCreated(Sender: TObject;
  const ACoin: TObject; const APayment: TCPCPayment);
begin
  Log(Format('[CREATED] %s payment %s for %.8f',
    [APayment.CoinSymbol, APayment.PaymentID, APayment.ExpectedAmount]));
  RefreshPaymentList;
end;

procedure TfrmMain.CryptoEngine1PaymentDetected(Sender: TObject;
  const ACoin: TObject; const APayment: TCPCPayment);
begin
  Log(Format('[DETECTED] %s payment %s - amount: %.8f, confirmations: %d',
    [APayment.CoinSymbol, APayment.PaymentID, APayment.DetectedAmount,
     APayment.Confirmations]));
  RefreshPaymentList;
end;

procedure TfrmMain.CryptoEngine1PaymentConfirmed(Sender: TObject;
  const ACoin: TObject; const APayment: TCPCPayment);
begin
  Log(Format('[CONFIRMED] %s payment %s - FULLY CONFIRMED with %d confirmations!',
    [APayment.CoinSymbol, APayment.PaymentID, APayment.Confirmations]));
  RefreshPaymentList;
end;

procedure TfrmMain.CryptoEngine1PaymentExpired(Sender: TObject;
  const ACoin: TObject; const APayment: TCPCPayment);
begin
  Log(Format('[EXPIRED] %s payment %s',
    [APayment.CoinSymbol, APayment.PaymentID]));
  RefreshPaymentList;
end;

procedure TfrmMain.CryptoEngine1Error(Sender: TObject;
  const ACoin: TObject; const APaymentID, AErrorMessage: string);
begin
  Log(Format('[ERROR] Payment %s: %s', [APaymentID, AErrorMessage]));
end;

end.
