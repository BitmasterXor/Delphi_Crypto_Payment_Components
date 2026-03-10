{*******************************************************}
{                                                       }
{       Crypto Payment Components for Delphi            }
{       TBitcoinCoin - Bitcoin (BTC) Component          }
{                                                       }
{       Uses FREE APIs (no API key required):           }
{         - Blockchain.com API (primary)                }
{         - Mempool.space API (fallback/tx confirm)     }
{                                                       }
{       Rate limits:                                    }
{         Blockchain.com: 1 request per 10 seconds      }
{         Mempool.space: reasonable use                  }
{                                                       }
{*******************************************************}

unit CPC.Coin.Bitcoin;

interface

uses
  System.SysUtils, System.Classes, System.JSON, System.Math,
  CPC.Types, CPC.Coin.Base;

type
  TBitcoinCoin = class(TCPCCoinBase)
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
  SATOSHI_PER_BTC = 100000000;

  MEMPOOL_TX_STATUS_URL      = 'https://mempool.space/api/tx/%s/status';
  MEMPOOL_ADDR_TXS_URL       = 'https://mempool.space/api/address/%s/txs';
  MEMPOOL_BLOCKS_TIP_URL     = 'https://mempool.space/api/blocks/tip/height';

{ TBitcoinCoin }

function TBitcoinCoin.GetCoinSymbol: string;
begin
  Result := 'BTC';
end;

function TBitcoinCoin.GetCoinName: string;
begin
  Result := 'Bitcoin';
end;

function TBitcoinCoin.GetDecimals: Integer;
begin
  Result := 8;
end;

function TBitcoinCoin.ValidateReceiveAddress(const AAddress: string;
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
  if (Pos('bc1', Prefix) = 1) or (Pos('tb1', Prefix) = 1) then
  begin
    Result := (Length(Addr) >= 14) and (Length(Addr) <= 90);
    if not Result then
      AError := 'bech32 address length is invalid';
    Exit;
  end;

  if CharInSet(Addr[1], ['1', '3', 'm', 'n', '2']) then
  begin
    Result := (Length(Addr) >= 26) and (Length(Addr) <= 62);
    if not Result then
      AError := 'base58 address length is invalid';
    Exit;
  end;

  AError := 'expected BTC address prefix bc1/tb1/1/3/m/n/2';
end;

function TBitcoinCoin.CheckForPayment(const AAddress: string;
  AExpectedAmount: Double; out ADetectedAmount: Double;
  out AConfirmations: Integer; out ATxHash: string;
  out AError: string): Boolean;
var
  Response, TipResp, TipErr: string;
  JSON, TxItem, VoutItem, StatusObj: TJSONValue;
  TxArray, VoutArray: TJSONArray;
  I, J: Integer;
  TxAddr: string;
  TxValue: Int64;
  TxBlockHeight, TipHeight: Integer;
  ExpectedSatoshis: Int64;
  BestConfs: Integer;
  BestTxHash: string;
  FoundIncoming: Boolean;
begin
  Result := False;
  ADetectedAmount := 0;
  AConfirmations := 0;
  ATxHash := '';

  ExpectedSatoshis := Round(AExpectedAmount * SATOSHI_PER_BTC);
  if ExpectedSatoshis <= 0 then
    ExpectedSatoshis := 1;

  // If tx lookup fails, keep payment pending and retry on next poll.
  if not HttpGet(Format(MEMPOOL_ADDR_TXS_URL, [AAddress]), Response, AError) then
    Exit;

  JSON := ParseJSON(Response);
  if not Assigned(JSON) then
  begin
    AError := 'Invalid JSON response from mempool.space';
    Exit;
  end;

  try
    if not (JSON is TJSONArray) then
    begin
      AError := 'Unexpected response format from mempool.space';
      Exit;
    end;

    TxArray := TJSONArray(JSON);
    BestConfs := 0;
    BestTxHash := '';
    FoundIncoming := False;

    // Get current block height for confirmation calculation
    TipHeight := 0;
    if HttpGet(MEMPOOL_BLOCKS_TIP_URL, TipResp, TipErr) then
      TipHeight := StrToIntDef(Trim(TipResp), 0);

    for I := 0 to TxArray.Count - 1 do
    begin
      TxItem := TxArray.Items[I];

      VoutArray := TxItem.FindValue('vout') as TJSONArray;
      if not Assigned(VoutArray) then
        Continue;

      for J := 0 to VoutArray.Count - 1 do
      begin
        VoutItem := VoutArray.Items[J];
        TxAddr := VoutItem.GetValue<string>('scriptpubkey_address', '');

        if SameText(TxAddr, AAddress) then
        begin
          TxValue := VoutItem.GetValue<Int64>('value', 0);
          if TxValue = ExpectedSatoshis then
          begin
            BestTxHash := TxItem.GetValue<string>('txid', '');

            StatusObj := TxItem.FindValue('status');
            if Assigned(StatusObj) then
            begin
              if StatusObj.GetValue<Boolean>('confirmed', False) then
              begin
                TxBlockHeight := StatusObj.GetValue<Integer>('block_height', 0);
                if (TipHeight > 0) and (TxBlockHeight > 0) then
                  BestConfs := TipHeight - TxBlockHeight + 1
                else
                  BestConfs := 1;
              end
              else
                BestConfs := 0;
            end;

            ADetectedAmount := TxValue / SATOSHI_PER_BTC;
            FoundIncoming := True;
            Break;
          end;
        end;
      end;

      if FoundIncoming then
        Break;
    end;

    if FoundIncoming then
    begin
      AConfirmations := BestConfs;
      ATxHash := BestTxHash;
    end;

    Result := True;
  finally
    JSON.Free;
  end;
end;

function TBitcoinCoin.CheckTransactionConfirmations(const ATxHash: string;
  out AConfirmations: Integer; out AError: string): Boolean;
var
  Response, TipResp, TipErr: string;
  JSON: TJSONValue;
  BlockHeight, TipHeight: Integer;
begin
  Result := False;
  AConfirmations := 0;

  if not HttpGet(Format(MEMPOOL_TX_STATUS_URL, [ATxHash]), Response, AError) then
    Exit;

  JSON := ParseJSON(Response);
  if not Assigned(JSON) then
  begin
    AError := 'Invalid JSON from mempool.space tx status';
    Exit;
  end;

  try
    if not JSON.GetValue<Boolean>('confirmed', False) then
    begin
      AConfirmations := 0;
      Result := True;
      Exit;
    end;

    BlockHeight := JSON.GetValue<Integer>('block_height', 0);

    if HttpGet(MEMPOOL_BLOCKS_TIP_URL, TipResp, TipErr) then
    begin
      TipHeight := StrToIntDef(Trim(TipResp), 0);
      if (TipHeight > 0) and (BlockHeight > 0) then
        AConfirmations := TipHeight - BlockHeight + 1
      else
        AConfirmations := 1;
    end
    else
      AConfirmations := 1;

    Result := True;
  finally
    JSON.Free;
  end;
end;

end.
