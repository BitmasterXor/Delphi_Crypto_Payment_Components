{*******************************************************}
{                                                       }
{       Crypto Payment Components for Delphi            }
{       Shared Types, Records, and Enumerations         }
{                                                       }
{       Copyright (c) 2024-2026                         }
{       No-Middleman Crypto Payment Library             }
{                                                       }
{       Free blockchain API integration only            }
{       No third-party payment processors               }
{                                                       }
{*******************************************************}

unit CPC.Types;

interface

uses
  System.SysUtils;

type
  /// <summary>Payment status lifecycle</summary>
  TCPCPaymentStatus = (
    psNone,        // Not initialized
    psPending,     // Awaiting payment
    psDetected,    // Transaction seen (unconfirmed or partially confirmed)
    psConfirmed,   // Required confirmations reached
    psUnderpaid,   // Received less than expected amount
    psOverpaid,    // Received more than expected amount
    psExpired,     // Payment window closed without full payment
    psCancelled,   // Manually cancelled
    psError        // Error during processing
  );

  /// <summary>A single payment request record</summary>
  TCPCPayment = record
    PaymentID: string;          // Unique GUID-based identifier
    CoinSymbol: string;         // e.g. 'BTC', 'ETH', 'LTC', 'DOGE', 'BCH'
    ReceiveAddress: string;     // Address where payment should be sent
    ExpectedAmount: Double;     // Amount expected (in coin units, e.g. 0.005 BTC)
    DetectedAmount: Double;     // Amount detected so far
    Status: TCPCPaymentStatus;  // Current status
    Confirmations: Integer;     // Number of confirmations observed
    RequiredConfirmations: Integer; // How many confirmations needed
    TxHash: string;             // Transaction hash once detected
    ExternalRef: string;        // User-supplied reference / order ID
    Title: string;              // Display title for the payment
    CreatedAt: TDateTime;       // When payment was created
    ExpiresAt: TDateTime;       // When payment expires
    LastCheckedAt: TDateTime;   // Last time we polled the API
    LastError: string;          // Last error message
    Tag: NativeInt;             // User-defined tag
  end;

  PCPCPayment = ^TCPCPayment;

  TCPCPaymentArray = TArray<TCPCPayment>;

  /// <summary>Result from a single payment check</summary>
  TCPCCheckResult = record
    Success: Boolean;
    PaymentID: string;
    NewStatus: TCPCPaymentStatus;
    DetectedAmount: Double;
    Confirmations: Integer;
    ErrorMessage: string;
  end;

  /// <summary>Event fired when a payment status changes.
  ///  Sender = the component firing the event.
  ///  ACoin = the coin component (cast to TCPCCoinBase from CPC.Coin.Base).
  ///  APayment = the payment record.
  /// </summary>
  TCPCPaymentEvent = procedure(Sender: TObject; const ACoin: TObject;
    const APayment: TCPCPayment) of object;

  /// <summary>Event fired when an error occurs</summary>
  TCPCErrorEvent = procedure(Sender: TObject; const ACoin: TObject;
    const APaymentID, AErrorMessage: string) of object;

  /// <summary>Event for logging/debugging</summary>
  TCPCLogEvent = procedure(Sender: TObject; const AMessage: string) of object;

  /// <summary>Helper for payment status to string conversion</summary>
  TCPCPaymentStatusHelper = record helper for TCPCPaymentStatus
    function ToString: string;
  end;

implementation

{ TCPCPaymentStatusHelper }

function TCPCPaymentStatusHelper.ToString: string;
begin
  case Self of
    psNone:       Result := 'None';
    psPending:    Result := 'Pending';
    psDetected:   Result := 'Detected';
    psConfirmed:  Result := 'Confirmed';
    psUnderpaid:  Result := 'Underpaid';
    psOverpaid:   Result := 'Overpaid';
    psExpired:    Result := 'Expired';
    psCancelled:  Result := 'Cancelled';
    psError:      Result := 'Error';
  else
    Result := 'Unknown';
  end;
end;

end.
