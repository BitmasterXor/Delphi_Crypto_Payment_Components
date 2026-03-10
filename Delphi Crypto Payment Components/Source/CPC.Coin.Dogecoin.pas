{*******************************************************}
{                                                       }
{       Crypto Payment Components for Delphi            }
{       TDogecoinCoin - Dogecoin (DOGE) Component       }
{                                                       }
{       Uses FREE BlockCypher API (no key required):    }
{         https://api.blockcypher.com/v1/doge/main/     }
{                                                       }
{       Rate limits (no token):                         }
{         3 requests/second, 100 requests/hour          }
{                                                       }
{*******************************************************}

unit CPC.Coin.Dogecoin;

interface

uses
  System.SysUtils, System.Classes, System.JSON, System.Math,
  CPC.Types, CPC.Coin.Base;

type
  /// <summary>
  ///  Dogecoin (DOGE) payment component.
  ///  Uses BlockCypher's free API. No API key required.
  ///  1 DOGE = 100,000,000 koinu (same structure as satoshi).
  /// </summary>
  TDogecoinCoin = class(TCPCCoinBase)
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
  KOINU_PER_DOGE = 100000000; // 10^8

  // BlockCypher API - free, no key required
  BLOCKCYPHER_DOGE_ADDR_FULL = 'https://api.blockcypher.com/v1/doge/main/addrs/%s';
  BLOCKCYPHER_DOGE_TX        = 'https://api.blockcypher.com/v1/doge/main/txs/%s';

{ TDogecoinCoin }

function TDogecoinCoin.GetCoinSymbol: string;
begin
  Result := 'DOGE';
end;

function TDogecoinCoin.GetCoinName: string;
begin
  Result := 'Dogecoin';
end;

function TDogecoinCoin.GetDecimals: Integer;
begin
  Result := 8;
end;

function TDogecoinCoin.ValidateReceiveAddress(const AAddress: string;
  out AError: string): Boolean;
var
  Addr: string;
begin
  Addr := Trim(AAddress);
  AError := '';
  Result := False;

  if Addr.IsEmpty then
  begin
    AError := 'address is empty';
    Exit;
  end;

  if CharInSet(Addr[1], ['D', 'A', '9']) then
  begin
    Result := (Length(Addr) >= 25) and (Length(Addr) <= 62);
    if not Result then
      AError := 'address length is invalid';
    Exit;
  end;

  AError := 'expected DOGE address prefix D/A/9';
end;

function TDogecoinCoin.CheckForPayment(const AAddress: string;
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
  ExpectedKoinu: Int64;
begin
  Result := False;
  ADetectedAmount := 0;
  AConfirmations := 0;
  ATxHash := '';

  if not HttpGet(Format(BLOCKCYPHER_DOGE_ADDR_FULL, [AAddress]), Response, AError) then
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

    ExpectedKoinu := Round(AExpectedAmount * KOINU_PER_DOGE);
    if ExpectedKoinu <= 0 then
      ExpectedKoinu := 1;

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
          if RefValue = ExpectedKoinu then
          begin
            ATxHash := TxRefItem.GetValue<string>('tx_hash', '');
            AConfirmations := 0;
            ADetectedAmount := RefValue / KOINU_PER_DOGE;
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
          if RefValue = ExpectedKoinu then
          begin
            ATxHash := TxRefItem.GetValue<string>('tx_hash', '');
            AConfirmations := TxRefItem.GetValue<Integer>('confirmations', 0);
            ADetectedAmount := RefValue / KOINU_PER_DOGE;
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

function TDogecoinCoin.CheckTransactionConfirmations(const ATxHash: string;
  out AConfirmations: Integer; out AError: string): Boolean;
var
  Response: string;
  JSON: TJSONValue;
begin
  Result := False;
  AConfirmations := 0;

  if not HttpGet(Format(BLOCKCYPHER_DOGE_TX, [ATxHash]), Response, AError) then
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
