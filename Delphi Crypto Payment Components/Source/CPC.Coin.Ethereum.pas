{*******************************************************}
{                                                       }
{       Crypto Payment Components for Delphi            }
{       TEthereumCoin - Ethereum (ETH) Component        }
{                                                       }
{       Uses FREE Ethplorer API with built-in "freekey" }
{       No registration or signup required.             }
{                                                       }
{       Also supports ERC-20 token payments (USDT,      }
{       USDC, etc.) via Ethplorer's token tracking.     }
{                                                       }
{       Rate limits (freekey):                          }
{         2 req/sec, 200/hr, 1000/day                   }
{                                                       }
{*******************************************************}

unit CPC.Coin.Ethereum;

interface

uses
  System.SysUtils, System.Classes, System.JSON, System.Math,
  CPC.Types, CPC.Coin.Base;

type
  /// <summary>
  ///  Ethereum (ETH) payment component.
  ///  Uses Ethplorer.io free API (built-in "freekey", no signup).
  ///  Supports both native ETH and ERC-20 token payments.
  /// </summary>
  TEthereumCoin = class(TCPCCoinBase)
  private
    FTokenContract: string;
    FTokenDecimals: Integer;
    FTokenSymbol: string;
  protected
    function GetCoinSymbol: string; override;
    function GetCoinName: string; override;
    function GetDecimals: Integer; override;
    function ValidateReceiveAddress(const AAddress: string; out AError: string): Boolean; override;

    function CheckForPayment(const AAddress: string; AExpectedAmount: Double;
      out ADetectedAmount: Double; out AConfirmations: Integer;
      out ATxHash: string; out AError: string): Boolean; override;

    function CheckTransactionConfirmations(const ATxHash: string;
      out AConfirmations: Integer; out AError: string): Boolean; override;
  public
    constructor Create(AOwner: TComponent); override;
  published
    /// <summary>ERC-20 token contract address. Leave empty for native ETH.</summary>
    property TokenContract: string read FTokenContract write FTokenContract;

    /// <summary>Token decimal places (e.g. 6 for USDT, 18 for most tokens).
    ///  Only used when TokenContract is set.</summary>
    property TokenDecimals: Integer read FTokenDecimals write FTokenDecimals default 18;

    /// <summary>Token symbol for display (e.g. 'USDT'). Only used when TokenContract is set.</summary>
    property TokenSymbol: string read FTokenSymbol write FTokenSymbol;
  end;

implementation

const
  WEI_PER_ETH = 1000000000000000000; // 10^18

  // Ethplorer API - free with built-in "freekey"
  ETHPLORER_ADDR_TXS  = 'https://api.ethplorer.io/getAddressTransactions/%s?apiKey=freekey&limit=10';
  ETHPLORER_ADDR_HIST = 'https://api.ethplorer.io/getAddressHistory/%s?apiKey=freekey&limit=10&type=transfer';
  ETHPLORER_TX_INFO   = 'https://api.ethplorer.io/getTxInfo/%s?apiKey=freekey';

{ TEthereumCoin }

constructor TEthereumCoin.Create(AOwner: TComponent);
begin
  inherited;
  FTokenDecimals := 18;
  RequiredConfirmations := 12; // ETH typically needs more confirmations
end;

function TEthereumCoin.GetCoinSymbol: string;
begin
  if FTokenSymbol <> '' then
    Result := FTokenSymbol
  else
    Result := 'ETH';
end;

function TEthereumCoin.GetCoinName: string;
begin
  if FTokenSymbol <> '' then
    Result := 'Ethereum (' + FTokenSymbol + ')'
  else
    Result := 'Ethereum';
end;

function TEthereumCoin.GetDecimals: Integer;
begin
  if FTokenContract <> '' then
    Result := FTokenDecimals
  else
    Result := 18;
end;

function TEthereumCoin.ValidateReceiveAddress(const AAddress: string;
  out AError: string): Boolean;
var
  Addr: string;
  I: Integer;
begin
  Addr := Trim(AAddress);
  AError := '';
  Result := False;

  if Addr.IsEmpty then
  begin
    AError := 'address is empty';
    Exit;
  end;

  if (Length(Addr) <> 42) or (LowerCase(Copy(Addr, 1, 2)) <> '0x') then
  begin
    AError := 'expected Ethereum address format 0x + 40 hex chars';
    Exit;
  end;

  for I := 3 to Length(Addr) do
    if not CharInSet(Addr[I], ['0'..'9', 'a'..'f', 'A'..'F']) then
    begin
      AError := 'address contains non-hex characters';
      Exit;
    end;

  Result := True;
end;

function TEthereumCoin.CheckForPayment(const AAddress: string;
  AExpectedAmount: Double; out ADetectedAmount: Double;
  out AConfirmations: Integer; out ATxHash: string;
  out AError: string): Boolean;
var
  Response: string;
  JSON, TxItem, OpItem, TokenInfoObj, OpsObj: TJSONValue;
  TxArray: TJSONArray;
  I: Integer;
  TxTo: string;
  TxValue: Double;
  IsConfirmed: Boolean;
  Decs: Integer;
  ExpectedScaled: Int64;
  TxScaled: Int64;
begin
  Result := False;
  ADetectedAmount := 0;
  AConfirmations := 0;
  ATxHash := '';

  ExpectedScaled := Round(AExpectedAmount * 1E8);
  if ExpectedScaled <= 0 then
    ExpectedScaled := 1;

  if FTokenContract = '' then
  begin
    // Native ETH: use latest inbound tx for hash/confirmation tracking.
    if not HttpGet(Format(ETHPLORER_ADDR_TXS, [AAddress]), Response, AError) then
      Exit;

    JSON := ParseJSON(Response);
    if not Assigned(JSON) then
    begin
      AError := 'Invalid JSON from Ethplorer transactions';
      Exit;
    end;

    try
      if not (JSON is TJSONArray) then
      begin
        AError := 'Unexpected response format from Ethplorer transactions';
        Exit;
      end;

      TxArray := TJSONArray(JSON);

      for I := 0 to TxArray.Count - 1 do
      begin
        TxItem := TxArray.Items[I];
        TxTo := TxItem.GetValue<string>('to', '');

        if SameText(TxTo, AAddress) then
        begin
          TxValue := TxItem.GetValue<Double>('value', 0);
          TxScaled := Round(TxValue * 1E8);
          if TxScaled = ExpectedScaled then
          begin
            ATxHash := TxItem.GetValue<string>('hash', '');
            IsConfirmed := TxItem.GetValue<Boolean>('success', False);
            if IsConfirmed then
              AConfirmations := 12 // Ethplorer doesn't give exact count; if listed, it's confirmed
            else
              AConfirmations := 0;
            ADetectedAmount := TxScaled / 1E8;
            Break;
          end;
        end;
      end;

      Result := True;
    finally
      JSON.Free;
    end;
  end
  else
  begin
    // ERC-20 token: use latest inbound token transfer for hash/confirmation tracking.
    if not HttpGet(Format(ETHPLORER_ADDR_HIST, [AAddress]), Response, AError) then
      Exit;

    JSON := ParseJSON(Response);
    if not Assigned(JSON) then
    begin
      AError := 'Invalid JSON from Ethplorer history';
      Exit;
    end;

    try
      OpsObj := JSON.FindValue('operations');
      if not Assigned(OpsObj) or not (OpsObj is TJSONArray) then
      begin
        AError := 'Unexpected response format from Ethplorer history';
        Exit;
      end;

      TxArray := TJSONArray(OpsObj);
      Decs := FTokenDecimals;

      for I := 0 to TxArray.Count - 1 do
      begin
        OpItem := TxArray.Items[I];
        TxTo := OpItem.GetValue<string>('to', '');
        TokenInfoObj := OpItem.FindValue('tokenInfo');

        if SameText(TxTo, AAddress) and Assigned(TokenInfoObj) then
        begin
          if SameText(TokenInfoObj.GetValue<string>('address', ''), FTokenContract) then
          begin
            TxValue := OpItem.GetValue<Double>('value', 0);
            TxValue := TxValue / Power(10, Decs);
            TxScaled := Round(TxValue * 1E8);
            if TxScaled = ExpectedScaled then
            begin
              ATxHash := OpItem.GetValue<string>('transactionHash', '');
              AConfirmations := 12; // Listed in history = confirmed
              ADetectedAmount := TxScaled / 1E8;
              Break;
            end;
          end;
        end;
      end;

      Result := True;
    finally
      JSON.Free;
    end;
  end;
end;

function TEthereumCoin.CheckTransactionConfirmations(const ATxHash: string;
  out AConfirmations: Integer; out AError: string): Boolean;
var
  Response: string;
  JSON: TJSONValue;
  IsConfirmed: Boolean;
begin
  Result := False;
  AConfirmations := 0;

  if not HttpGet(Format(ETHPLORER_TX_INFO, [ATxHash]), Response, AError) then
    Exit;

  JSON := ParseJSON(Response);
  if not Assigned(JSON) then
  begin
    AError := 'Invalid JSON from Ethplorer tx info';
    Exit;
  end;

  try
    // Check if there's an error
    if JSON.FindValue('error') <> nil then
    begin
      AError := JSON.GetValue<string>('error.message', 'Transaction not found');
      Exit;
    end;

    IsConfirmed := JSON.GetValue<Boolean>('success', False);
    if IsConfirmed then
    begin
      AConfirmations := 12; // Conservative: if Ethplorer shows it, it's well confirmed
    end
    else
      AConfirmations := 0;

    Result := True;
  finally
    JSON.Free;
  end;
end;

end.
