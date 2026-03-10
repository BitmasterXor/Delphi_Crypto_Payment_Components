{*******************************************************}
{                                                       }
{       Crypto Payment Components for Delphi            }
{       Design-Time Component Registration              }
{                                                       }
{       Registers all components to the                 }
{       "Crypto Payments" palette page in the IDE.      }
{                                                       }
{*******************************************************}

unit CPC.Register;

interface

procedure Register;

implementation

{$R *.dcr}

uses
  System.Classes,
  CPC.Engine,
  CPC.Coin.Bitcoin,
  CPC.Coin.Ethereum,
  CPC.Coin.Litecoin,
  CPC.Coin.Dogecoin,
  CPC.Coin.BitcoinCash;

procedure Register;
begin
  RegisterComponents('Crypto Payments', [
    TCryptoEngine,
    TBitcoinCoin,
    TEthereumCoin,
    TLitecoinCoin,
    TDogecoinCoin,
    TBitcoinCashCoin
  ]);
end;

end.
