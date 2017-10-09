//+------------------------------------------------------------------+
//|                                              MovingAverageEA.mq4 |
//|                             Copyright 2017, Code-Hamamatsu Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2017, Code-Hamamatsu."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

//--- input parameters

input int      MAPeriod = 200;      //移動平均線の期間
input int      MarginPips = 30;     //上下に取るPips
input int      TP = 10;             //リミット（Pips）
input int      SL = 30;             //ストップ（Pips）
input double   InitialLots = 0.01;  //初期ロット
input int      MagicNumber = 68451; //マジックナンバー

int            g_consecutive_loss;
double         g_OnePipValue;
double         g_StopLossValue,g_TakeProfitValue;

enum StateOfRate{
   InTheBand=0,
   AboveBand=1,
   BelowBand=2,
};

StateOfRate State = InTheBand;

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
   static double balance = AccountBalance();

   if(balance!=AccountBalance())
   {
      if(!HaveOpenPosition())
      {
         if(balance > AccountBalance())
         {
            g_consecutive_loss++;
         }
         else if(balance < AccountBalance())
         {
            g_consecutive_loss = 0;
         }
      }
      balance=AccountBalance();
   }

   CheckRateCondition();

   static StateOfRate PreState = State;

   double LowerBand = NormalizeDouble((iMA(Symbol(),PERIOD_CURRENT,MAPeriod,0,MODE_EMA,PRICE_CLOSE,0) - MarginPips * g_OnePipValue),Digits);
   double UPperBand = NormalizeDouble((iMA(Symbol(),PERIOD_CURRENT,MAPeriod,0,MODE_EMA,PRICE_CLOSE,0) + MarginPips * g_OnePipValue),Digits);

   if(PreState != State)
   {
      if(!HavePosition())
      {
         if(PreState == InTheBand && State == BelowBand)
         {
            double Lots = GetLots(g_consecutive_loss);
            //write long stop order routine
            g_StopLossValue   = NormalizeDouble(LowerBand - SL * g_OnePipValue,Digits);
            g_TakeProfitValue = NormalizeDouble(LowerBand + TP * g_OnePipValue,Digits);
            bool a = OrderSend(Symbol(),OP_BUYSTOP,Lots,LowerBand,3,g_StopLossValue,g_TakeProfitValue,"",MagicNumber);
         }
         else if(PreState == InTheBand && State == AboveBand)
         {
            double Lots = GetLots(g_consecutive_loss);
            //write short stop order routine
            g_StopLossValue   = NormalizeDouble(UPperBand + SL * g_OnePipValue,Digits);
            g_TakeProfitValue = NormalizeDouble(UPperBand - TP * g_OnePipValue,Digits);
            bool a = OrderSend(Symbol(),OP_SELLSTOP,Lots,UPperBand,3,g_StopLossValue,g_TakeProfitValue,"",MagicNumber);
         }
      }
      PreState = State;
   }
}

double GetLots(int loss_count)
{
   double previous_lots = 0.0;
   double lots = InitialLots;

   for(int i=0;i<loss_count;i++)
   {
      lots = previous_lots + lots * (SL/TP);
      previous_lots = lots;
   }
   return(lots);
}

void CheckRateCondition()
{
   double LowerBand = iMA(Symbol(),PERIOD_CURRENT,MAPeriod,0,MODE_EMA,PRICE_CLOSE,0) - MarginPips * g_OnePipValue;
   double UPperBand = iMA(Symbol(),PERIOD_CURRENT,MAPeriod,0,MODE_EMA,PRICE_CLOSE,0) + MarginPips * g_OnePipValue;
   if(Ask <= LowerBand)
   {
      State = BelowBand;
   }
   else if(Bid >= UPperBand)
   {
      State = AboveBand;
   }
   else
   {
      State = InTheBand;
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