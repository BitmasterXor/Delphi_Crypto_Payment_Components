{*******************************************************}
{                                                       }
{       Crypto Payment Components for Delphi            }
{       TBitcoinCashCoin - Bitcoin Cash (BCH) Component }
{                                                       }
{       Uses FREE Blockchair API (no key required):     }
{         https://api.blockchair.com/bitcoin-cash/      }
{                                                       }
{       Rate limits (no key):                           }
{         30 requests/minute, 1440 requests/day         }
{                                                       }
{*******************************************************}

unit CPC.Coin.BitcoinCash;

interface

uses
  System.SysUtils, System.Classes, System.JSON, System.Math,
  CPC.Types, CPC.Coin.Base;

type
  TBitcoinCashCoin = class(TCPCCoinBase)
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
  SATOSHI_PER_BCH = 100000000;

  BLOCKCHAIR_BCH_ADDR = 'https://api.blockchair.com/bitcoin-cash/dashboards/address/%s';
  BLOCKCHAIR_BCH_TX   = 'https://api.blockchair.com/bitcoin-cash/dashboards/transaction/%s';

{ TBitcoinCashCoin }

function TBitcoinCashCoin.GetCoinSymbol: string;
begin
  Result := 'BCH';
end;

function TBitcoinCashCoin.GetCoinName: string;
begin
  Result := 'Bitcoin Cash';
end;

function TBitcoinCashCoin.GetDecimals: Integer;
begin
  Result := 8;
end;

function TBitcoinCashCoin.ValidateReceiveAddress(const AAddress: string;
  out AError: string): Boolean;
var
  Addr, Prefix: string;
  SepPos: Integer;
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
  if Pos('bitcoincash:', Prefix) = 1 then
  begin
    SepPos := Pos(':', Addr);
    if SepPos > 0 then
      Addr := Copy(Addr, SepPos + 1, MaxInt);
    Prefix := LowerCase(Addr);
  end;

  if (Length(Addr) >= 42) and (Length(Addr) <= 62) and
     (not Prefix.IsEmpty) and CharInSet(Prefix[1], ['q', 'p']) then
  begin
    Result := True;
    Exit;
  end;

  if CharInSet(Addr[1], ['1', '3']) then
  begin
    Result := (Length(Addr) >= 26) and (Length(Addr) <= 62);
    if not Result then
      AError := 'legacy address length is invalid';
    Exit;
  end;

  AError := 'expected BCH cashaddr (q/p...) or legacy 1/3 format';
end;

function TBitcoinCashCoin.CheckForPayment(const AAddress: string;
  AExpectedAmount: Double; out ADetectedAmount: Double;
  out AConfirmations: Integer; out ATxHash: string;
  out AError: string): Boolean;
var
  Response, TxResp, TxErr: string;
  JSON, DataObj, AddrData, AddrInfo, TxItem: TJSONValue;
  TxJSON, TxDataObj, TxData, TxOutput, TxInfo: TJSONValue;
  TxArray: TJSONArray;
  ExpectedSatoshis: Int64;
  TxValueToAddress: Int64;
  TxHash: string;
  TxBlockId, TxLatestBlock: Integer;
  TxIdx, OutIdx, TxScanCount: Integer;
begin
  Result := False;
  ADetectedAmount := 0;
  AConfirmations := 0;
  ATxHash := '';

  if not HttpGet(Format(BLOCKCHAIR_BCH_ADDR, [AAddress]) + '?transaction_details=true',
    Response, AError) then
    Exit;

  JSON := ParseJSON(Response);
  if not Assigned(JSON) then
  begin
    AError := 'Invalid JSON from Blockchair';
    Exit;
  end;

  try
    DataObj := JSON.FindValue('data');
    if not Assigned(DataObj) or not (DataObj is TJSONObject) then
    begin
      AError := 'No data in response';
      Exit;
    end;

    AddrData := nil;
    if TJSONObject(DataObj).Count > 0 then
      AddrData := TJSONObject(DataObj).Pairs[0].JsonValue;

    if not Assigned(AddrData) then
    begin
      Result := True;
      Exit;
    end;

    AddrInfo := AddrData.FindValue('address');
    if not Assigned(AddrInfo) then
    begin
      Result := True;
      Exit;
    end;

    ExpectedSatoshis := Round(AExpectedAmount * SATOSHI_PER_BCH);
    if ExpectedSatoshis <= 0 then
      ExpectedSatoshis := 1;

    TxArray := AddrData.FindValue('transactions') as TJSONArray;
    if Assigned(TxArray) and (TxArray.Count > 0) then
    begin
      TxScanCount := Min(TxArray.Count, 12);
      for TxIdx := 0 to TxScanCount - 1 do
      begin
        TxItem := TxArray.Items[TxIdx];
        if TxItem is TJSONString then
          TxHash := TxItem.Value
        else
          TxHash := TxItem.GetValue<string>('hash', '');

        if TxHash.IsEmpty then
          Continue;

        if not HttpGet(Format(BLOCKCHAIR_BCH_TX, [TxHash]), TxResp, TxErr) then
          Continue;

        TxJSON := ParseJSON(TxResp);
        if not Assigned(TxJSON) then
          Continue;
        try
          TxDataObj := TxJSON.FindValue('data');
          if not Assigned(TxDataObj) or not (TxDataObj is TJSONObject) then
            Continue;

          TxData := nil;
          if TJSONObject(TxDataObj).Count > 0 then
            TxData := TJSONObject(TxDataObj).Pairs[0].JsonValue;
          if not Assigned(TxData) then
            Continue;

          TxValueToAddress := 0;
          if Assigned(TxData.FindValue('outputs')) and
             (TxData.FindValue('outputs') is TJSONArray) then
          begin
            for OutIdx := 0 to TJSONArray(TxData.FindValue('outputs')).Count - 1 do
            begin
              TxOutput := TJSONArray(TxData.FindValue('outputs')).Items[OutIdx];
              if SameText(TxOutput.GetValue<string>('recipient', ''), AAddress) then
                Inc(TxValueToAddress, TxOutput.GetValue<Int64>('value', 0));
            end;
          end;

          if TxValueToAddress = ExpectedSatoshis then
          begin
            ATxHash := TxHash;
            ADetectedAmount := TxValueToAddress / SATOSHI_PER_BCH;

            TxInfo := TxData.FindValue('transaction');
            if Assigned(TxInfo) then
            begin
              TxBlockId := TxInfo.GetValue<Integer>('block_id', -1);
              if TxBlockId <= 0 then
                AConfirmations := 0
              else
              begin
                TxLatestBlock := TxJSON.GetValue<Integer>('context.state', 0);
                if TxLatestBlock > 0 then
                  AConfirmations := TxLatestBlock - TxBlockId + 1
                else
                  AConfirmations := 1;
              end;
            end
            else
              AConfirmations := 0;

            Break;
          end;
        finally
          TxJSON.Free;
        end;
      end;
    end;

    Result := True;
  finally
    JSON.Free;
  end;
end;

function TBitcoinCashCoin.CheckTransactionConfirmations(const ATxHash: string;
  out AConfirmations: Integer; out AError: string): Boolean;
var
  Response: string;
  JSON, DataObj, TxData, TxInfo: TJSONValue;
  BlockId: Integer;
  LatestBlock: Integer;
begin
  Result := False;
  AConfirmations := 0;

  if not HttpGet(Format(BLOCKCHAIR_BCH_TX, [ATxHash]), Response, AError) then
    Exit;

  JSON := ParseJSON(Response);
  if not Assigned(JSON) then
  begin
    AError := 'Invalid JSON from Blockchair tx';
    Exit;
  end;

  try
    DataObj := JSON.FindValue('data');
    if not Assigned(DataObj) or not (DataObj is TJSONObject) then
    begin
      AError := 'No data in transaction response';
      Exit;
    end;

    TxData := nil;
    if TJSONObject(DataObj).Count > 0 then
      TxData := TJSONObject(DataObj).Pairs[0].JsonValue;

    if not Assigned(TxData) then
    begin
      AError := 'Transaction not found';
      Exit;
    end;

    TxInfo := TxData.FindValue('transaction');
    if not Assigned(TxInfo) then
    begin
      AError := 'Transaction info not found';
      Exit;
    end;

    BlockId := TxInfo.GetValue<Integer>('block_id', -1);

    if BlockId <= 0 then
    begin
      AConfirmations := 0;
      Result := True;
      Exit;
    end;

    LatestBlock := JSON.GetValue<Integer>('context.state', 0);
    if LatestBlock > 0 then
      AConfirmations := LatestBlock - BlockId + 1
    else
      AConfirmations := 1;

    Result := True;
  finally
    JSON.Free;
  end;
end;

end.
