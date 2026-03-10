{*******************************************************}
{                                                       }
{       Crypto Payment Components for Delphi            }
{       TLitecoinCoin - Litecoin (LTC) Component        }
{                                                       }
{       Uses FREE BlockCypher API (no key required):    }
{         https://api.blockcypher.com/v1/ltc/main/      }
{                                                       }
{       Rate limits (no token):                         }
{         3 requests/second, 100 requests/hour          }
{                                                       }
{*******************************************************}

unit CPC.Coin.Litecoin;

interface

uses
  System.SysUtils, System.Classes, System.JSON, System.Math,
  CPC.Types, CPC.Coin.Base;

type
  /// <summary>
  ///  Litecoin (LTC) payment component.
  ///  Uses BlockCypher's free API to check address balances,
  ///  detect incoming transactions, and track confirmations.
  ///  No API key required.
  /// </summary>
  TLitecoinCoin = class(TCPCCoinBase)
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
  end;

implementation

const
  LITOSHI_PER_LTC = 100000000; // 10^8, same as Bitcoin

  // BlockCypher API - free, no key required
  BLOCKCYPHER_LTC_ADDR_FULL = 'https://api.blockcypher.com/v1/ltc/main/addrs/%s';
  BLOCKCYPHER_LTC_TX        = 'https://api.blockcypher.com/v1/ltc/main/txs/%s';

{ TLitecoinCoin }

function TLitecoinCoin.GetCoinSymbol: string;
begin
  Result := 'LTC';
end;

function TLitecoinCoin.GetCoinName: string;
begin
  Result := 'Litecoin';
end;

function TLitecoinCoin.GetDecimals: Integer;
begin
  Result := 8;
end;

function TLitecoinCoin.ValidateReceiveAddress(const AAddress: string;
  out AError: string): Boolean;
var
  Addr, Prefix: string;
begin
  Addr := Trim(AAddress);
  AError := '';
  Result := False;

  if Addr.IsEmpty then
  begin
    AError := 'address is empty';
    Exit;
  end;

  Prefix := LowerCase(Addr);
  if (Pos('ltc1', Prefix) = 1) then
  begin
    Result := (Length(Addr) >= 14) and (Length(Addr) <= 90);
    if not Result then
      AError := 'bech32 address length is invalid';
    Exit;
  end;

  if CharInSet(Addr[1], ['L', 'M', '3']) then
  begin
    Result := (Length(Addr) >= 26) and (Length(Addr) <= 62);
    if not Result then
      AError := 'base58 address length is invalid';
    Exit;
  end;

  AError := 'expected LTC address prefix ltc1/L/M/3';
end;

function TLitecoinCoin.CheckForPayment(const AAddress: string;
  AExpectedAmount: Double; out ADetectedAmount: Double;
  out AConfirmations: Integer; out ATxHash: string;
  out AError: string): Boolean;
var
  Response: string;
  JSON, TxRefItem: TJSONValue;
  TxRefs, UnconfRefs: TJSONArray;
  I: Integer;
  InputN: Integer;
  RefValue: Int64;
  ExpectedLitoshis: Int64;
begin
  Result := False;
  ADetectedAmount := 0;
  AConfirmations := 0;
  ATxHash := '';

  // Get address with txrefs
  if not HttpGet(Format(BLOCKCYPHER_LTC_ADDR_FULL, [AAddress]), Response, AError) then
    Exit;

  JSON := ParseJSON(Response);
  if not Assigned(JSON) then
  begin
    AError := 'Invalid JSON from BlockCypher';
    Exit;
  end;

  try
    if JSON.FindValue('error') <> nil then
    begin
      AError := JSON.GetValue<string>('error', 'Unknown error');
      Exit;
    end;

    ExpectedLitoshis := Round(AExpectedAmount * LITOSHI_PER_LTC);
    if ExpectedLitoshis <= 0 then
      ExpectedLitoshis := 1;

    // Prefer latest unconfirmed incoming tx for hash/confirmation tracking.
    UnconfRefs := JSON.FindValue('unconfirmed_txrefs') as TJSONArray;
    if Assigned(UnconfRefs) then
    begin
      for I := 0 to UnconfRefs.Count - 1 do
      begin
        TxRefItem := UnconfRefs.Items[I];
        InputN := TxRefItem.GetValue<Integer>('tx_input_n', 0);
        if InputN = -1 then
        begin
          RefValue := TxRefItem.GetValue<Int64>('value', 0);
          if RefValue = ExpectedLitoshis then
          begin
            ATxHash := TxRefItem.GetValue<string>('tx_hash', '');
            AConfirmations := 0;
            ADetectedAmount := RefValue / LITOSHI_PER_LTC;
            Break;
          end;
        end;
      end;
    end;

    // Fallback: latest confirmed incoming tx.
    TxRefs := JSON.FindValue('txrefs') as TJSONArray;
    if Assigned(TxRefs) and ATxHash.IsEmpty then
    begin
      for I := 0 to TxRefs.Count - 1 do
      begin
        TxRefItem := TxRefs.Items[I];
        InputN := TxRefItem.GetValue<Integer>('tx_input_n', 0);
        if InputN = -1 then
        begin
          RefValue := TxRefItem.GetValue<Int64>('value', 0);
          if RefValue = ExpectedLitoshis then
          begin
            ATxHash := TxRefItem.GetValue<string>('tx_hash', '');
            AConfirmations := TxRefItem.GetValue<Integer>('confirmations', 0);
            ADetectedAmount := RefValue / LITOSHI_PER_LTC;
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

function TLitecoinCoin.CheckTransactionConfirmations(const ATxHash: string;
  out AConfirmations: Integer; out AError: string): Boolean;
var
  Response: string;
  JSON: TJSONValue;
begin
  Result := False;
  AConfirmations := 0;

  if not HttpGet(Format(BLOCKCYPHER_LTC_TX, [ATxHash]), Response, AError) then
    Exit;

  JSON := ParseJSON(Response);
  if not Assigned(JSON) then
  begin
    AError := 'Invalid JSON from BlockCypher tx';
    Exit;
  end;

  try
    if JSON.FindValue('error') <> nil then
    begin
      AError := JSON.GetValue<string>('error', 'Unknown error');
      Exit;
    end;

    AConfirmations := JSON.GetValue<Integer>('confirmations', 0);
    Result := True;
  finally
    JSON.Free;
  end;
end;

end.
