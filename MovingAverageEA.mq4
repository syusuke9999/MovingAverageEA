//+------------------------------------------------------------------+
//|                                              MovingAverageEA.mq4 |
//|                             Copyright 2017, Code-Hamamatsu Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2017, Code-Hamamatsu."
#property link      "https://www.mql5.com"
#property version   "1.30"
#property strict

//--- input parameters

input int      MAPeriod                = 200;      //移動平均線の期間
input int      MarginPips              = 30;       //上下に取るPips
input double   TP                      = 10;       //リミット（Pips）
input double   SL                      = 30;       //ストップ（Pips）
input double   InitialLots             = 0.01;     //初期ロット
input int      MagicNumber             = 68451;    //マジックナンバー
input int      Consecutive_Loss_Limit  = 3;        //連続負け回数
input double   Spread                  = 5;        //上限スプレッド

input bool     DebugMode=true;

int            g_consecutive_loss;
double         g_OnePipValue;
double         g_StopLossValue,g_TakeProfitValue;

enum StateOfRate{
   OverTheMA=0,
   UnderTheMA=1,
   AboveBand=2,
   BelowBand=3,
};

StateOfRate State;

int DigitOfLots = (int)(-1 * MathLog10(MarketInfo(Symbol(),MODE_MINLOT)));

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   double point = MarketInfo(Symbol(),MODE_POINT);
   if(Digits==3 || Digits==5)g_OnePipValue=point*10;
   else g_OnePipValue=point;

   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---

  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   if((Ask-Bid) > Spread * g_OnePipValue)
   {
      Comment("スプレッドオーバー");
      //Print("スプレッドが規程の幅より広いため発注しません");
      return;
   }
   else
   {
      Comment("");
   }
   static double balance = AccountBalance();
   static bool   allow_trade = true;

   if(balance!=AccountBalance())
   {
      if(!HaveOpenPosition())
      {
         if(balance > AccountBalance())
         {
            g_consecutive_loss++;
            allow_trade = false;
         }
         else if(balance < AccountBalance())
         {
            g_consecutive_loss = 0;
         }
      }
      balance=AccountBalance();
   }

   CheckRateCondition();
   if(DebugMode) Comment(TimeToString(TimeCurrent(),TIME_DATE|TIME_MINUTES) + " \n" + "Consecutive loss=",g_consecutive_loss," allow trade=",allow_trade," State=",EnumToString(State));
   static StateOfRate PreState = State;

   double LowerBand = NormalizeDouble((iMA(Symbol(),PERIOD_CURRENT,MAPeriod,0,MODE_EMA,PRICE_CLOSE,0) - MarginPips * g_OnePipValue),Digits);
   double UPperBand = NormalizeDouble((iMA(Symbol(),PERIOD_CURRENT,MAPeriod,0,MODE_EMA,PRICE_CLOSE,0) + MarginPips * g_OnePipValue),Digits);

   if(PreState != State)
   {
      if(!HavePosition() && allow_trade)
      {
         if((PreState == OverTheMA || PreState == UnderTheMA) && State == BelowBand)
         {
            double Lots = GetLots(g_consecutive_loss);
            //write long stop order routine
            g_StopLossValue   = NormalizeDouble(LowerBand - SL * g_OnePipValue,Digits);
            g_TakeProfitValue = NormalizeDouble(LowerBand + TP * g_OnePipValue,Digits);
            bool a = OrderSend(Symbol(),OP_BUYSTOP,Lots,LowerBand,3,g_StopLossValue,g_TakeProfitValue,"",MagicNumber);
         }
         else if((PreState == OverTheMA || PreState == UnderTheMA) && State == AboveBand)
         {
            double Lots = GetLots(g_consecutive_loss);
            //write short stop order routine
            g_StopLossValue   = NormalizeDouble(UPperBand + SL * g_OnePipValue,Digits);
            g_TakeProfitValue = NormalizeDouble(UPperBand - TP * g_OnePipValue,Digits);
            bool a = OrderSend(Symbol(),OP_SELLSTOP,Lots,UPperBand,3,g_StopLossValue,g_TakeProfitValue,"",MagicNumber);
         }
      }
      if((PreState == OverTheMA || PreState == AboveBand) && State == UnderTheMA)
      {
         allow_trade = true;
      }
      else if((PreState == UnderTheMA || PreState == BelowBand) && State == OverTheMA)
      {
         allow_trade = true;
      }
      PreState = State;
   }
}

double GetLots(int loss_count)
{
   double previous_lots = 0.0;
   double lots = InitialLots;
   if(Consecutive_Loss_Limit < loss_count)
   {
      lots = InitialLots;
      return(lots);
   }
   else
   {
      for(int i=0;i<loss_count;i++)
      {
         lots = previous_lots + lots * (SL/TP);
         previous_lots = lots;
      }
      lots = NormalizeDouble(lots,DigitOfLots);
      return(lots);
   }
}

void CheckRateCondition()
{
   double LowerBand = iMA(Symbol(),PERIOD_CURRENT,MAPeriod,0,MODE_EMA,PRICE_CLOSE,0) - MarginPips * g_OnePipValue;
   double CenterMA  = iMA(Symbol(),PERIOD_CURRENT,MAPeriod,0,MODE_EMA,PRICE_CLOSE,0);
   double UPperBand = iMA(Symbol(),PERIOD_CURRENT,MAPeriod,0,MODE_EMA,PRICE_CLOSE,0) + MarginPips * g_OnePipValue;
   if(Ask <= LowerBand)
   {
      State = BelowBand;
   }
   else if(Bid >= UPperBand)
   {
      State = AboveBand;
   }
   else if(Bid < CenterMA && Bid > LowerBand)
   {
      State = UnderTheMA;
   }
   else if(Bid >= CenterMA && Bid < UPperBand)
   {
      State = OverTheMA;
   }
}

bool HavePosition()
{
   for(int i=0; i<OrdersTotal(); i++)
   {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES) == false) return(false);
      if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber)
      {
         return(true);
      }
   }
   return(false);
}

bool HaveOpenPosition()
{
   for(int i=0; i<OrdersTotal(); i++)
   {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES) == false) return(false);
      if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber)
      {
         if(OrderType() == OP_BUY || OrderType() == OP_SELL)
         {
            return(true);
         }
      }
   }
   return(false);
}