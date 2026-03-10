{*******************************************************}
{                                                       }
{       Crypto Payment Components for Delphi            }
{       TCryptoEngine - Main Engine Component           }
{                                                       }
{       Drop this on your form first, then drop coin    }
{       components and assign their Engine property.    }
{       The engine manages the polling timer and        }
{       coordinates all registered coin components.     }
{                                                       }
{*******************************************************}

unit CPC.Engine;

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  Vcl.ExtCtrls,
  CPC.Types, CPC.Coin.Base;

type
  /// <summary>
  ///  TCryptoEngine is the central coordinator for the Crypto Payment Components.
  ///  It manages a polling timer that periodically checks all registered coin
  ///  components for pending payments. Coin components register themselves
  ///  with the engine when their Engine property is set.
  /// </summary>
  TCryptoEngine = class(TComponent)
  private
    FTimer: TTimer;
    FCoins: TList<TCPCCoinBase>;
    FActive: Boolean;
    FPollingIntervalMs: Integer;
    FOnLog: TCPCLogEvent;
    FOnPaymentCreated: TCPCPaymentEvent;
    FOnPaymentDetected: TCPCPaymentEvent;
    FOnPaymentConfirmed: TCPCPaymentEvent;
    FOnPaymentExpired: TCPCPaymentEvent;
    FOnPaymentUnderpaid: TCPCPaymentEvent;
    FOnError: TCPCErrorEvent;
    procedure SetActive(const Value: Boolean);
    procedure SetPollingIntervalMs(const Value: Integer);
    procedure OnTimerTick(Sender: TObject);
  protected
    procedure Loaded; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    /// <summary>Register a coin component with this engine (called automatically)</summary>
    procedure RegisterCoin(ACoin: TCPCCoinBase);

    /// <summary>Unregister a coin component (called automatically)</summary>
    procedure UnregisterCoin(ACoin: TCPCCoinBase);

    /// <summary>Manually trigger a check of all pending payments across all coins</summary>
    procedure CheckAllPending;

    /// <summary>Get a list of all registered coin components</summary>
    function GetRegisteredCoins: TArray<TCPCCoinBase>;

    /// <summary>Get a list of all coin symbols registered</summary>
    function GetRegisteredCoinSymbols: TArray<string>;

    /// <summary>Find a registered coin by symbol</summary>
    function FindCoin(const ACoinSymbol: string): TCPCCoinBase;

    /// <summary>Total number of active payments across all coins</summary>
    function TotalActivePayments: Integer;

    // Internal notification methods called by coin components
    procedure DoLog(const AMsg: string);
    procedure NotifyPaymentCreated(ACoin: TCPCCoinBase; const APayment: TCPCPayment);
    procedure NotifyPaymentDetected(ACoin: TCPCCoinBase; const APayment: TCPCPayment);
    procedure NotifyPaymentConfirmed(ACoin: TCPCCoinBase; const APayment: TCPCPayment);
    procedure NotifyPaymentExpired(ACoin: TCPCCoinBase; const APayment: TCPCPayment);
    procedure NotifyPaymentUnderpaid(ACoin: TCPCCoinBase; const APayment: TCPCPayment);
    procedure NotifyError(ACoin: TCPCCoinBase; const APaymentID, AMsg: string);
  published
    /// <summary>Enable or disable automatic polling of all coin components</summary>
    property Active: Boolean read FActive write SetActive default False;

    /// <summary>Polling interval in milliseconds (minimum 5000, default 15000)</summary>
    property PollingIntervalMs: Integer read FPollingIntervalMs
      write SetPollingIntervalMs default 15000;

    /// <summary>Fired for log/debug messages</summary>
    property OnLog: TCPCLogEvent read FOnLog write FOnLog;

    /// <summary>Global event: fired when any coin creates a payment</summary>
    property OnPaymentCreated: TCPCPaymentEvent read FOnPaymentCreated
      write FOnPaymentCreated;

    /// <summary>Global event: fired when any coin detects a payment</summary>
    property OnPaymentDetected: TCPCPaymentEvent read FOnPaymentDetected
      write FOnPaymentDetected;

    /// <summary>Global event: fired when any coin confirms a payment</summary>
    property OnPaymentConfirmed: TCPCPaymentEvent read FOnPaymentConfirmed
      write FOnPaymentConfirmed;

    /// <summary>Global event: fired when any coin's payment expires</summary>
    property OnPaymentExpired: TCPCPaymentEvent read FOnPaymentExpired
      write FOnPaymentExpired;

    /// <summary>Global event: fired when any coin's payment is underpaid</summary>
    property OnPaymentUnderpaid: TCPCPaymentEvent read FOnPaymentUnderpaid
      write FOnPaymentUnderpaid;

    /// <summary>Global event: fired when any coin encounters an error</summary>
    property OnError: TCPCErrorEvent read FOnError write FOnError;
  end;

implementation

{ TCryptoEngine }

constructor TCryptoEngine.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FCoins := TList<TCPCCoinBase>.Create;
  FPollingIntervalMs := 15000;
  FActive := False;

  FTimer := TTimer.Create(Self);
  FTimer.Enabled := False;
  FTimer.Interval := FPollingIntervalMs;
  FTimer.OnTimer := OnTimerTick;
end;

destructor TCryptoEngine.Destroy;
var
  I: Integer;
begin
  FTimer.Enabled := False;
  // Unlink all coins (iterate backwards since UnregisterCoin modifies the list)
  for I := FCoins.Count - 1 downto 0 do
    FCoins[I].Engine := nil;
  FCoins.Free;
  inherited;
end;

procedure TCryptoEngine.Loaded;
begin
  inherited;
  if FActive and not (csDesigning in ComponentState) then
    FTimer.Enabled := True;
end;

procedure TCryptoEngine.SetActive(const Value: Boolean);
begin
  FActive := Value;
  if not (csLoading in ComponentState) and not (csDesigning in ComponentState) then
    FTimer.Enabled := Value;
end;

procedure TCryptoEngine.SetPollingIntervalMs(const Value: Integer);
begin
  if Value < 5000 then
    FPollingIntervalMs := 5000
  else
    FPollingIntervalMs := Value;
  FTimer.Interval := FPollingIntervalMs;
end;

procedure TCryptoEngine.OnTimerTick(Sender: TObject);
begin
  CheckAllPending;
end;

procedure TCryptoEngine.RegisterCoin(ACoin: TCPCCoinBase);
begin
  if not FCoins.Contains(ACoin) then
  begin
    FCoins.Add(ACoin);
    DoLog('Registered coin: ' + ACoin.CoinSymbol);
  end;
end;

procedure TCryptoEngine.UnregisterCoin(ACoin: TCPCCoinBase);
begin
  FCoins.Remove(ACoin);
end;

procedure TCryptoEngine.CheckAllPending;
var
  Coin: TCPCCoinBase;
begin
  for Coin in FCoins do
  begin
    try
      Coin.CheckAllPending;
    except
      on E: Exception do
        DoLog('Error checking ' + Coin.CoinSymbol + ': ' + E.Message);
    end;
  end;
end;

function TCryptoEngine.GetRegisteredCoins: TArray<TCPCCoinBase>;
begin
  Result := FCoins.ToArray;
end;

function TCryptoEngine.GetRegisteredCoinSymbols: TArray<string>;
var
  I: Integer;
begin
  SetLength(Result, FCoins.Count);
  for I := 0 to FCoins.Count - 1 do
    Result[I] := FCoins[I].CoinSymbol;
end;

function TCryptoEngine.FindCoin(const ACoinSymbol: string): TCPCCoinBase;
var
  Coin: TCPCCoinBase;
begin
  Result := nil;
  for Coin in FCoins do
    if SameText(Coin.CoinSymbol, ACoinSymbol) then
      Exit(Coin);
end;

function TCryptoEngine.TotalActivePayments: Integer;
var
  Coin: TCPCCoinBase;
begin
  Result := 0;
  for Coin in FCoins do
    Inc(Result, Coin.ActivePaymentCount);
end;

procedure TCryptoEngine.DoLog(const AMsg: string);
begin
  if Assigned(FOnLog) then
    FOnLog(Self, AMsg);
end;

procedure TCryptoEngine.NotifyPaymentCreated(ACoin: TCPCCoinBase;
  const APayment: TCPCPayment);
begin
  if Assigned(FOnPaymentCreated) then
    FOnPaymentCreated(Self, ACoin, APayment);
end;

procedure TCryptoEngine.NotifyPaymentDetected(ACoin: TCPCCoinBase;
  const APayment: TCPCPayment);
begin
  if Assigned(FOnPaymentDetected) then
    FOnPaymentDetected(Self, ACoin, APayment);
end;

procedure TCryptoEngine.NotifyPaymentConfirmed(ACoin: TCPCCoinBase;
  const APayment: TCPCPayment);
begin
  if Assigned(FOnPaymentConfirmed) then
    FOnPaymentConfirmed(Self, ACoin, APayment);
end;

procedure TCryptoEngine.NotifyPaymentExpired(ACoin: TCPCCoinBase;
  const APayment: TCPCPayment);
begin
  if Assigned(FOnPaymentExpired) then
    FOnPaymentExpired(Self, ACoin, APayment);
end;

procedure TCryptoEngine.NotifyPaymentUnderpaid(ACoin: TCPCCoinBase;
  const APayment: TCPCPayment);
begin
  if Assigned(FOnPaymentUnderpaid) then
    FOnPaymentUnderpaid(Self, ACoin, APayment);
end;

procedure TCryptoEngine.NotifyError(ACoin: TCPCCoinBase;
  const APaymentID, AMsg: string);
begin
  if Assigned(FOnError) then
    FOnError(Self, ACoin, APaymentID, AMsg);
end;

end.
