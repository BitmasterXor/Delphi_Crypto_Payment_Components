{*******************************************************}
{                                                       }
{       Crypto Payment Components for Delphi            }
{       Base Coin Component (Abstract)                  }
{                                                       }
{       All coin components inherit from this class.    }
{       Each coin implements its own free API logic.    }
{                                                       }
{*******************************************************}

unit CPC.Coin.Base;

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  System.JSON, System.Net.HttpClient, System.Net.URLClient,
  System.DateUtils,
  CPC.Types;

type
  /// <summary>
  ///  Abstract base class for all cryptocurrency coin components.
  ///  Each specific coin (BTC, ETH, LTC, etc.) inherits from this class
  ///  and implements the abstract methods for its own free blockchain API.
  /// </summary>
  TCPCCoinBase = class(TComponent)
  private
    FEngine: TComponent; // TCryptoEngine (stored as TComponent to avoid circular ref)
    FReceiveAddress: string;
    FRequiredConfirmations: Integer;
    FExpirationMinutes: Integer;
    FPayments: TDictionary<string, TCPCPayment>;
    FOnPaymentCreated: TCPCPaymentEvent;
    FOnPaymentDetected: TCPCPaymentEvent;
    FOnPaymentConfirmed: TCPCPaymentEvent;
    FOnPaymentExpired: TCPCPaymentEvent;
    FOnPaymentUnderpaid: TCPCPaymentEvent;
    FOnError: TCPCErrorEvent;
    procedure SetEngine(const Value: TComponent);
    function IsTxHashAssignedToAnotherPayment(const APaymentID, ATxHash: string): Boolean;
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;

    /// <summary>Returns the coin symbol, e.g. 'BTC', 'ETH'</summary>
    function GetCoinSymbol: string; virtual; abstract;

    /// <summary>Returns a human-friendly coin name, e.g. 'Bitcoin'</summary>
    function GetCoinName: string; virtual; abstract;

    /// <summary>Returns the number of decimal places for this coin (e.g. 8 for BTC)</summary>
    function GetDecimals: Integer; virtual; abstract;

    /// <summary>Validate a receive address before allowing payment creation.</summary>
    function ValidateReceiveAddress(const AAddress: string; out AError: string): Boolean; virtual;

    /// <summary>
    ///  Checks for incoming transactions to the given address.
    ///  Should populate ADetectedAmount (in coin units), AConfirmations, ATxHash.
    /// </summary>
    function CheckForPayment(const AAddress: string; AExpectedAmount: Double;
      out ADetectedAmount: Double; out AConfirmations: Integer;
      out ATxHash: string; out AError: string): Boolean; virtual; abstract;

    /// <summary>
    ///  If a TxHash is known, check its confirmation count directly.
    /// </summary>
    function CheckTransactionConfirmations(const ATxHash: string;
      out AConfirmations: Integer; out AError: string): Boolean; virtual; abstract;

    /// <summary>Perform an HTTP GET and return the response body as string</summary>
    function HttpGet(const AURL: string; out AResponse: string;
      out AError: string): Boolean;

    /// <summary>Parse a JSON string, caller must free the result</summary>
    function ParseJSON(const AData: string): TJSONValue;

    /// <summary>Fire payment status change events</summary>
    procedure DoPaymentCreated(const APayment: TCPCPayment);
    procedure DoPaymentDetected(const APayment: TCPCPayment);
    procedure DoPaymentConfirmed(const APayment: TCPCPayment);
    procedure DoPaymentExpired(const APayment: TCPCPayment);
    procedure DoPaymentUnderpaid(const APayment: TCPCPayment);
    procedure DoError(const APaymentID, AMsg: string);

    procedure DoLog(const AMsg: string);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    /// <summary>Create a new payment request for this coin</summary>
    function CreatePayment(AAmount: Double; const AExternalRef: string = '';
      const ATitle: string = ''): string;

    /// <summary>Manually set a tx hash for a payment</summary>
    procedure SetPaymentTxHash(const APaymentID, ATxHash: string);

    /// <summary>Cancel a payment</summary>
    procedure CancelPayment(const APaymentID: string);

    /// <summary>Delete a payment from memory</summary>
    procedure DeletePayment(const APaymentID: string);

    /// <summary>Check a single payment's status via the blockchain API</summary>
    function CheckPayment(const APaymentID: string): TCPCCheckResult;

    /// <summary>Check all pending payments</summary>
    procedure CheckAllPending;

    /// <summary>Retrieve a payment record by ID</summary>
    function GetPayment(const APaymentID: string; out APayment: TCPCPayment): Boolean;

    /// <summary>List all payments for this coin</summary>
    function ListPayments: TCPCPaymentArray;

    /// <summary>Number of active (pending/detected) payments</summary>
    function ActivePaymentCount: Integer;

    /// <summary>Coin symbol (e.g. 'BTC')</summary>
    property CoinSymbol: string read GetCoinSymbol;

    /// <summary>Coin name (e.g. 'Bitcoin')</summary>
    property CoinName: string read GetCoinName;

    /// <summary>Decimal places for this coin</summary>
    property Decimals: Integer read GetDecimals;
  published
    /// <summary>The CryptoEngine this coin is linked to</summary>
    property Engine: TComponent read FEngine write SetEngine;

    /// <summary>The wallet address to receive payments</summary>
    property ReceiveAddress: string read FReceiveAddress write FReceiveAddress;

    /// <summary>Number of confirmations required before marking as confirmed</summary>
    property RequiredConfirmations: Integer read FRequiredConfirmations
      write FRequiredConfirmations default 3;

    /// <summary>Minutes before a payment expires (0 = never expires)</summary>
    property ExpirationMinutes: Integer read FExpirationMinutes
      write FExpirationMinutes default 60;

    /// <summary>Fired when a new payment is created</summary>
    property OnPaymentCreated: TCPCPaymentEvent read FOnPaymentCreated
      write FOnPaymentCreated;

    /// <summary>Fired when a transaction is detected for a payment</summary>
    property OnPaymentDetected: TCPCPaymentEvent read FOnPaymentDetected
      write FOnPaymentDetected;

    /// <summary>Fired when a payment reaches required confirmations</summary>
    property OnPaymentConfirmed: TCPCPaymentEvent read FOnPaymentConfirmed
      write FOnPaymentConfirmed;

    /// <summary>Fired when a payment expires</summary>
    property OnPaymentExpired: TCPCPaymentEvent read FOnPaymentExpired
      write FOnPaymentExpired;

    /// <summary>Fired when a payment is underpaid</summary>
    property OnPaymentUnderpaid: TCPCPaymentEvent read FOnPaymentUnderpaid
      write FOnPaymentUnderpaid;

    /// <summary>Fired when an error occurs</summary>
    property OnError: TCPCErrorEvent read FOnError write FOnError;
  end;

implementation

uses
  CPC.Engine;

{ TCPCCoinBase }

constructor TCPCCoinBase.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FPayments := TDictionary<string, TCPCPayment>.Create;
  FRequiredConfirmations := 3;
  FExpirationMinutes := 60;
end;

destructor TCPCCoinBase.Destroy;
begin
  if Assigned(FEngine) and (FEngine is TCryptoEngine) then
    TCryptoEngine(FEngine).UnregisterCoin(Self);
  FPayments.Free;
  inherited;
end;

procedure TCPCCoinBase.SetEngine(const Value: TComponent);
begin
  if FEngine <> Value then
  begin
    // Validate that Value is a TCryptoEngine or nil
    if Assigned(Value) and not (Value is TCryptoEngine) then
      raise Exception.Create('Engine must be a TCryptoEngine component');

    if Assigned(FEngine) and (FEngine is TCryptoEngine) then
    begin
      TCryptoEngine(FEngine).UnregisterCoin(Self);
      FEngine.RemoveFreeNotification(Self);
    end;
    FEngine := Value;
    if Assigned(FEngine) then
    begin
      TCryptoEngine(FEngine).RegisterCoin(Self);
      FEngine.FreeNotification(Self);
    end;
  end;
end;

function TCPCCoinBase.IsTxHashAssignedToAnotherPayment(const APaymentID,
  ATxHash: string): Boolean;
var
  Pair: TPair<string, TCPCPayment>;
begin
  Result := False;
  if ATxHash.Trim.IsEmpty then
    Exit;

  for Pair in FPayments do
  begin
    if not SameText(Pair.Key, APaymentID) and
       not Pair.Value.TxHash.Trim.IsEmpty and
       SameText(Pair.Value.TxHash, ATxHash) then
      Exit(True);
  end;
end;

procedure TCPCCoinBase.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited;
  if (Operation = opRemove) and (AComponent = FEngine) then
    FEngine := nil;
end;

function TCPCCoinBase.HttpGet(const AURL: string; out AResponse: string;
  out AError: string): Boolean;
var
  Http: THTTPClient;
  Resp: IHTTPResponse;
begin
  Result := False;
  AResponse := '';
  AError := '';
  Http := THTTPClient.Create;
  try
    Http.ConnectionTimeout := 10000;
    Http.ResponseTimeout := 15000;
    Http.UserAgent := 'CryptoPaymentComponent/1.0';
    try
      Resp := Http.Get(AURL);
      AResponse := Resp.ContentAsString;
      if Resp.StatusCode = 200 then
        Result := True
      else
        AError := Format('HTTP %d: %s', [Resp.StatusCode, Resp.StatusText]);
    except
      on E: Exception do
        AError := E.Message;
    end;
  finally
    Http.Free;
  end;
end;

function TCPCCoinBase.ParseJSON(const AData: string): TJSONValue;
begin
  Result := TJSONObject.ParseJSONValue(AData);
end;

function TCPCCoinBase.ValidateReceiveAddress(const AAddress: string;
  out AError: string): Boolean;
begin
  Result := True;
  AError := '';
end;

function TCPCCoinBase.CreatePayment(AAmount: Double; const AExternalRef: string;
  const ATitle: string): string;
var
  Payment: TCPCPayment;
  ErrMsg: string;
begin
  if FReceiveAddress.Trim.IsEmpty then
    raise Exception.CreateFmt('%s: ReceiveAddress is not set', [CoinSymbol]);

  if AAmount <= 0 then
    raise Exception.Create('Payment amount must be greater than zero');

  if not ValidateReceiveAddress(FReceiveAddress, ErrMsg) then
    raise Exception.CreateFmt('%s: invalid ReceiveAddress (%s)',
      [CoinSymbol, ErrMsg]);

  Payment := Default(TCPCPayment);
  Payment.PaymentID := TGUID.NewGuid.ToString.Replace('{', '').Replace('}', '');
  Payment.CoinSymbol := CoinSymbol;
  Payment.ReceiveAddress := FReceiveAddress;
  Payment.ExpectedAmount := AAmount;
  Payment.DetectedAmount := 0;
  Payment.Status := psPending;
  Payment.Confirmations := 0;
  Payment.RequiredConfirmations := FRequiredConfirmations;
  Payment.TxHash := '';
  Payment.ExternalRef := AExternalRef;
  Payment.Title := ATitle;
  Payment.CreatedAt := Now;
  if FExpirationMinutes > 0 then
    Payment.ExpiresAt := IncMinute(Now, FExpirationMinutes)
  else
    Payment.ExpiresAt := 0;
  Payment.LastCheckedAt := 0;
  Payment.LastError := '';
  Payment.Tag := 0;

  FPayments.Add(Payment.PaymentID, Payment);
  Result := Payment.PaymentID;

  DoPaymentCreated(Payment);
  DoLog(Format('Payment created: %s for %.8f %s to %s',
    [Payment.PaymentID, AAmount, CoinSymbol, FReceiveAddress]));
end;

procedure TCPCCoinBase.SetPaymentTxHash(const APaymentID, ATxHash: string);
var
  Payment: TCPCPayment;
begin
  if FPayments.TryGetValue(APaymentID, Payment) then
  begin
    Payment.TxHash := ATxHash;
    FPayments[APaymentID] := Payment;
  end;
end;

procedure TCPCCoinBase.CancelPayment(const APaymentID: string);
var
  Payment: TCPCPayment;
begin
  if FPayments.TryGetValue(APaymentID, Payment) then
  begin
    if Payment.Status in [psPending, psDetected] then
    begin
      Payment.Status := psCancelled;
      FPayments[APaymentID] := Payment;
    end;
  end;
end;

procedure TCPCCoinBase.DeletePayment(const APaymentID: string);
begin
  FPayments.Remove(APaymentID);
end;

function TCPCCoinBase.CheckPayment(const APaymentID: string): TCPCCheckResult;
var
  Payment: TCPCPayment;
  DetAmt: Double;
  Confs: Integer;
  TxH, ErrMsg: string;
  OldStatus: TCPCPaymentStatus;
begin
  Result := Default(TCPCCheckResult);
  Result.PaymentID := APaymentID;

  if not FPayments.TryGetValue(APaymentID, Payment) then
  begin
    Result.ErrorMessage := 'Payment not found';
    Exit;
  end;

  // Skip non-active payments
  if not (Payment.Status in [psPending, psDetected]) then
  begin
    Result.Success := True;
    Result.NewStatus := Payment.Status;
    Result.DetectedAmount := Payment.DetectedAmount;
    Result.Confirmations := Payment.Confirmations;
    Exit;
  end;

  // Check expiration
  if (Payment.ExpiresAt > 0) and (Now > Payment.ExpiresAt) and
     (Payment.Status = psPending) then
  begin
    Payment.Status := psExpired;
    FPayments[APaymentID] := Payment;
    Result.Success := True;
    Result.NewStatus := psExpired;
    DoPaymentExpired(Payment);
    Exit;
  end;

  OldStatus := Payment.Status;
  Payment.LastCheckedAt := Now;

  // If we already have a tx hash, check confirmations directly
  if not Payment.TxHash.IsEmpty then
  begin
    if CheckTransactionConfirmations(Payment.TxHash, Confs, ErrMsg) then
    begin
      Payment.Confirmations := Confs;
      if Confs >= Payment.RequiredConfirmations then
      begin
        Payment.Status := psConfirmed;
        FPayments[APaymentID] := Payment;
        Result.Success := True;
        Result.NewStatus := psConfirmed;
        Result.Confirmations := Confs;
        Result.DetectedAmount := Payment.DetectedAmount;
        if OldStatus <> psConfirmed then
          DoPaymentConfirmed(Payment);
        Exit;
      end
      else
      begin
        if Payment.Status = psPending then
          Payment.Status := psDetected;
        FPayments[APaymentID] := Payment;
        Result.Success := True;
        Result.NewStatus := Payment.Status;
        Result.Confirmations := Confs;
        Result.DetectedAmount := Payment.DetectedAmount;
        if (OldStatus = psPending) and (Payment.Status = psDetected) then
          DoPaymentDetected(Payment);
        Exit;
      end;
    end
    else
    begin
      Payment.LastError := ErrMsg;
      FPayments[APaymentID] := Payment;
      Result.ErrorMessage := ErrMsg;
      DoError(APaymentID, ErrMsg);
      Exit;
    end;
  end;

  // No tx hash yet - check for incoming payment via address scanning
  if CheckForPayment(Payment.ReceiveAddress, Payment.ExpectedAmount,
       DetAmt, Confs, TxH, ErrMsg) then
  begin
    Result.Success := True;

    if DetAmt > 0 then
    begin
      if IsTxHashAssignedToAnotherPayment(APaymentID, TxH) then
      begin
        Result.NewStatus := Payment.Status;
        Result.DetectedAmount := Payment.DetectedAmount;
        Result.Confirmations := Payment.Confirmations;
        FPayments[APaymentID] := Payment;
        Exit;
      end;

      Payment.DetectedAmount := DetAmt;
      Payment.Confirmations := Confs;
      if not TxH.IsEmpty then
        Payment.TxHash := TxH;

      if Confs >= Payment.RequiredConfirmations then
      begin
        Payment.Status := psConfirmed;
        FPayments[APaymentID] := Payment;
        Result.NewStatus := psConfirmed;
        Result.DetectedAmount := DetAmt;
        Result.Confirmations := Confs;
        if OldStatus <> psConfirmed then
          DoPaymentConfirmed(Payment);
        Exit;
      end
      else
      begin
        Payment.Status := psDetected;
        FPayments[APaymentID] := Payment;
        Result.NewStatus := psDetected;
        Result.DetectedAmount := DetAmt;
        Result.Confirmations := Confs;
        if OldStatus = psPending then
          DoPaymentDetected(Payment);
        Exit;
      end;
    end
    else
    begin
      Result.NewStatus := Payment.Status;
      FPayments[APaymentID] := Payment;
    end;
  end
  else
  begin
    Payment.LastError := ErrMsg;
    FPayments[APaymentID] := Payment;
    Result.ErrorMessage := ErrMsg;
    DoError(APaymentID, ErrMsg);
  end;
end;

procedure TCPCCoinBase.CheckAllPending;
var
  Pair: TPair<string, TCPCPayment>;
  IDs: TArray<string>;
  ID: string;
begin
  IDs := [];
  for Pair in FPayments do
    if Pair.Value.Status in [psPending, psDetected] then
      IDs := IDs + [Pair.Key];

  for ID in IDs do
    CheckPayment(ID);
end;

function TCPCCoinBase.GetPayment(const APaymentID: string;
  out APayment: TCPCPayment): Boolean;
begin
  Result := FPayments.TryGetValue(APaymentID, APayment);
end;

function TCPCCoinBase.ListPayments: TCPCPaymentArray;
var
  Pair: TPair<string, TCPCPayment>;
  I: Integer;
begin
  SetLength(Result, FPayments.Count);
  I := 0;
  for Pair in FPayments do
  begin
    Result[I] := Pair.Value;
    Inc(I);
  end;
end;

function TCPCCoinBase.ActivePaymentCount: Integer;
var
  Pair: TPair<string, TCPCPayment>;
begin
  Result := 0;
  for Pair in FPayments do
    if Pair.Value.Status in [psPending, psDetected] then
      Inc(Result);
end;

procedure TCPCCoinBase.DoPaymentCreated(const APayment: TCPCPayment);
begin
  if Assigned(FOnPaymentCreated) then
    FOnPaymentCreated(Self, Self, APayment);
  if Assigned(FEngine) and (FEngine is TCryptoEngine) then
    TCryptoEngine(FEngine).NotifyPaymentCreated(Self, APayment);
end;

procedure TCPCCoinBase.DoPaymentDetected(const APayment: TCPCPayment);
begin
  if Assigned(FOnPaymentDetected) then
    FOnPaymentDetected(Self, Self, APayment);
  if Assigned(FEngine) and (FEngine is TCryptoEngine) then
    TCryptoEngine(FEngine).NotifyPaymentDetected(Self, APayment);
end;

procedure TCPCCoinBase.DoPaymentConfirmed(const APayment: TCPCPayment);
begin
  if Assigned(FOnPaymentConfirmed) then
    FOnPaymentConfirmed(Self, Self, APayment);
  if Assigned(FEngine) and (FEngine is TCryptoEngine) then
    TCryptoEngine(FEngine).NotifyPaymentConfirmed(Self, APayment);
end;

procedure TCPCCoinBase.DoPaymentExpired(const APayment: TCPCPayment);
begin
  if Assigned(FOnPaymentExpired) then
    FOnPaymentExpired(Self, Self, APayment);
  if Assigned(FEngine) and (FEngine is TCryptoEngine) then
    TCryptoEngine(FEngine).NotifyPaymentExpired(Self, APayment);
end;

procedure TCPCCoinBase.DoPaymentUnderpaid(const APayment: TCPCPayment);
begin
  if Assigned(FOnPaymentUnderpaid) then
    FOnPaymentUnderpaid(Self, Self, APayment);
  if Assigned(FEngine) and (FEngine is TCryptoEngine) then
    TCryptoEngine(FEngine).NotifyPaymentUnderpaid(Self, APayment);
end;

procedure TCPCCoinBase.DoError(const APaymentID, AMsg: string);
begin
  if Assigned(FOnError) then
    FOnError(Self, Self, APaymentID, AMsg);
  if Assigned(FEngine) and (FEngine is TCryptoEngine) then
    TCryptoEngine(FEngine).NotifyError(Self, APaymentID, AMsg);
end;

procedure TCPCCoinBase.DoLog(const AMsg: string);
begin
  if Assigned(FEngine) and (FEngine is TCryptoEngine) then
    TCryptoEngine(FEngine).DoLog(CoinSymbol + ': ' + AMsg);
end;

end.
