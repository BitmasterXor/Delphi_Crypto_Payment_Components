object frmMain: TfrmMain
  Left = 0
  Top = 0
  Caption = 'Crypto Payment Components - Demo'
  ClientHeight = 580
  ClientWidth = 850
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  TextHeight = 15
  object PageControl1: TPageControl
    Left = 0
    Top = 0
    Width = 850
    Height = 558
    ActivePage = tsSetup
    Align = alClient
    TabOrder = 0
    object tsSetup: TTabSheet
      Caption = 'Setup'
      object gbEngine: TGroupBox
        Left = 16
        Top = 16
        Width = 800
        Height = 73
        Caption = ' Engine Settings '
        TabOrder = 0
        object lblPolling: TLabel
          Left = 16
          Top = 30
          Width = 109
          Height = 15
          Caption = 'Polling Interval (ms):'
        end
        object edtPollingInterval: TEdit
          Left = 150
          Top = 27
          Width = 80
          Height = 23
          TabOrder = 0
          Text = '15000'
        end
        object chkActive: TCheckBox
          Left = 260
          Top = 29
          Width = 140
          Height = 17
          Caption = 'Engine Active'
          TabOrder = 1
          OnClick = chkActiveClick
        end
      end
      object gbCoins: TGroupBox
        Left = 16
        Top = 100
        Width = 800
        Height = 310
        Caption = ' Coin Receive Addresses '
        TabOrder = 1
        object lblBTCAddr: TLabel
          Left = 16
          Top = 30
          Width = 71
          Height = 15
          Caption = 'BTC (Bitcoin):'
        end
        object lblETHAddr: TLabel
          Left = 16
          Top = 70
          Width = 87
          Height = 15
          Caption = 'ETH (Ethereum):'
        end
        object lblLTCAddr: TLabel
          Left = 16
          Top = 110
          Width = 75
          Height = 15
          Caption = 'LTC (Litecoin):'
        end
        object lblDOGEAddr: TLabel
          Left = 16
          Top = 150
          Width = 96
          Height = 15
          Caption = 'DOGE (Dogecoin):'
        end
        object lblBCHAddr: TLabel
          Left = 16
          Top = 190
          Width = 104
          Height = 15
          Caption = 'BCH (Bitcoin Cash):'
        end
        object edtBTCAddress: TEdit
          Left = 130
          Top = 27
          Width = 650
          Height = 23
          TabOrder = 0
        end
        object edtETHAddress: TEdit
          Left = 130
          Top = 67
          Width = 650
          Height = 23
          TabOrder = 1
        end
        object edtLTCAddress: TEdit
          Left = 130
          Top = 107
          Width = 650
          Height = 23
          TabOrder = 2
        end
        object edtDOGEAddress: TEdit
          Left = 130
          Top = 147
          Width = 650
          Height = 23
          TabOrder = 3
        end
        object edtBCHAddress: TEdit
          Left = 130
          Top = 187
          Width = 650
          Height = 23
          TabOrder = 4
        end
      end
      object btnApplySettings: TButton
        Left = 16
        Top = 425
        Width = 150
        Height = 30
        Caption = 'Apply Settings'
        TabOrder = 2
        OnClick = btnApplySettingsClick
      end
    end
    object tsPayments: TTabSheet
      Caption = 'Payments'
      ImageIndex = 1
      object gbCreatePayment: TGroupBox
        Left = 16
        Top = 12
        Width = 800
        Height = 73
        Caption = ' Create Payment '
        TabOrder = 0
        object lblCoin: TLabel
          Left = 16
          Top = 30
          Width = 28
          Height = 15
          Caption = 'Coin:'
        end
        object lblAmount: TLabel
          Left = 225
          Top = 30
          Width = 47
          Height = 15
          Caption = 'Amount:'
        end
        object lblRef: TLabel
          Left = 420
          Top = 30
          Width = 20
          Height = 15
          Caption = 'Ref:'
        end
        object cbCoinSelect: TComboBox
          Left = 55
          Top = 27
          Width = 150
          Height = 23
          Style = csDropDownList
          TabOrder = 0
        end
        object edtAmount: TEdit
          Left = 280
          Top = 27
          Width = 120
          Height = 23
          TabOrder = 1
          Text = '0.001'
        end
        object edtExternalRef: TEdit
          Left = 452
          Top = 27
          Width = 150
          Height = 23
          TabOrder = 2
          Text = 'ORDER-001'
        end
        object btnCreatePayment: TButton
          Left = 620
          Top = 25
          Width = 160
          Height = 28
          Caption = 'Create Payment'
          TabOrder = 3
          OnClick = btnCreatePaymentClick
        end
      end
      object lvPayments: TListView
        Left = 16
        Top = 96
        Width = 800
        Height = 380
        Columns = <
          item
            Caption = 'Coin'
          end
          item
            Caption = 'Payment ID'
            Width = 120
          end
          item
            Caption = 'Address'
            Width = 200
          end
          item
            Caption = 'Expected'
            Width = 100
          end
          item
            Caption = 'Detected'
            Width = 100
          end
          item
            Caption = 'Status'
            Width = 80
          end
          item
            Caption = 'Confirmations'
            Width = 90
          end
          item
            Caption = 'TxHash'
            Width = 200
          end
          item
            Caption = 'Ref'
            Width = 100
          end>
        ReadOnly = True
        RowSelect = True
        TabOrder = 1
        ViewStyle = vsReport
      end
      object btnCheckAll: TButton
        Left = 16
        Top = 490
        Width = 130
        Height = 28
        Caption = 'Check All Pending'
        TabOrder = 2
        OnClick = btnCheckAllClick
      end
      object btnRefreshList: TButton
        Left = 160
        Top = 490
        Width = 100
        Height = 28
        Caption = 'Refresh List'
        TabOrder = 3
        OnClick = btnRefreshListClick
      end
    end
    object tsLog: TTabSheet
      Caption = 'Event Log'
      ImageIndex = 2
      object memoLog: TMemo
        Left = 16
        Top = 12
        Width = 800
        Height = 480
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -11
        Font.Name = 'Consolas'
        Font.Style = []
        ParentFont = False
        ReadOnly = True
        ScrollBars = ssVertical
        TabOrder = 0
      end
      object btnClearLog: TButton
        Left = 16
        Top = 498
        Width = 100
        Height = 25
        Caption = 'Clear Log'
        TabOrder = 1
        OnClick = btnClearLogClick
      end
    end
  end
  object StatusBar1: TStatusBar
    Left = 0
    Top = 558
    Width = 850
    Height = 22
    Panels = <>
    SimplePanel = True
    SimpleText = 'Ready'
  end
  object CryptoEngine1: TCryptoEngine
    OnLog = CryptoEngine1Log
    OnPaymentCreated = CryptoEngine1PaymentCreated
    OnPaymentDetected = CryptoEngine1PaymentDetected
    OnPaymentConfirmed = CryptoEngine1PaymentConfirmed
    OnPaymentExpired = CryptoEngine1PaymentExpired
    OnError = CryptoEngine1Error
    Left = 240
    Top = 464
  end
  object BitcoinCoin1: TBitcoinCoin
    Engine = CryptoEngine1
    Left = 336
    Top = 520
  end
  object EthereumCoin1: TEthereumCoin
    Engine = CryptoEngine1
    RequiredConfirmations = 12
    Left = 336
    Top = 464
  end
  object LitecoinCoin1: TLitecoinCoin
    Engine = CryptoEngine1
    RequiredConfirmations = 6
    Left = 240
    Top = 520
  end
  object DogecoinCoin1: TDogecoinCoin
    Engine = CryptoEngine1
    RequiredConfirmations = 6
    Left = 432
    Top = 464
  end
  object BitcoinCashCoin1: TBitcoinCashCoin
    Engine = CryptoEngine1
    RequiredConfirmations = 6
    Left = 432
    Top = 520
  end
end
