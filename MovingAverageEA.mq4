//+------------------------------------------------------------------+
//|                                              MovingAverageEA.mq4 |
//|                             Copyright 2017, Code-Hamamatsu Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2017, Code-Hamamatsu."
#property link      "https://www.mql5.com"
#property version   "1.50"
#property strict

//--- input parameters

input int      MAPeriod                = 200;      //�ړ����ϐ��̊���
input int      MarginPips              = 30;       //�㉺�Ɏ��Pips
input double   TP                      = 10;       //���~�b�g�iPips�j
input double   SL                      = 30;       //�X�g�b�v�iPips�j
input double   InitialLots             = 0.01;     //�������b�g
input int      MagicNumber             = 68451;    //�}�W�b�N�i���o�[
input int      Consecutive_Loss_Limit  = 3;        //�A��������
input double   Spread                  = 5;        //����X�v���b�h

input bool     DebugMode = false;

int            g_consecutive_loss;
double         g_OnePipValue;
double         g_StopLossValue,g_TakeProfitValue;
bool           g_allow_trade = true;

//structure witch representing rate state
enum StateOfRate{
   OverTheMA=0,
   UnderTheMA=1,
   AboveBand=2,
   BelowBand=3,
};

//variable whitch representing the current rate state
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
      Comment("�X�v���b�h�I�[�o�[");
      //Print("�X�v���b�h���K���̕����L�����ߔ������܂���");
      return;
   }
   else
   {
      Comment("");
   }

   //�����̎c�����ω��������ǂ����`�F�b�N����i�|�W�V���������ς��ꂽ���Ƃ����o����j
   CheckChangeInAccountBalance();

   //���݂̃��[�g�̏�Ԃ��`�F�b�N���āAState�ϐ��ɃZ�b�g����
   CheckRateCondition();

   if(DebugMode) Comment(TimeToString(TimeCurrent(),TIME_DATE|TIME_MINUTES) + " \n" + "Consecutive loss=",g_consecutive_loss," allow trade=",g_allow_trade," State=",EnumToString(State));

   //�|�W�V�����̔��������𖞂����Ă��邩�A��肵�Ă��Ȃ�Stop�|�W�V���������݂����܂ܐV�������[�\�N���ɐ؂�ւ�����ꍇ�ɁA��������B
   CheckIfOrderSendConditionFilled();

}

void CheckChangeInAccountBalance()
{
   static double balance = AccountBalance();

   if(balance != AccountBalance())
   {
      if(!HaveOpenPosition())
      {
         if(balance > AccountBalance())
         {
            g_consecutive_loss++;
            g_allow_trade = false;
         }
         else if(balance < AccountBalance())
         {
            g_consecutive_loss = 0;
         }
      }
      balance = AccountBalance();
   }
   return;
}


void CheckIfOrderSendConditionFilled()
{
   static StateOfRate PreState = State;
   static datetime OpenTime = Time[0];

   if(PreState != State)
   {
      if(!HavePosition() && g_allow_trade)
      {
         if(PreState != BelowBand && State == BelowBand)
         {
            SendBuyStopOrder();
         }
         else if(PreState != AboveBand && State == AboveBand)
         {
            SendSellStopOrder();
         }
      }
      //�A���Ŏw�肵���񐔕����g���[�h�������A�g���[�h���֎~���ꂽ��Ԃ�
      if(!g_allow_trade)
      {
         //���[�g�̏�Ԃ��A�u�ړ����ς̏�v�܂��́A�u�ړ����ρ{��Pips����v�̏�Ԃ���u�ړ����ς�艺�v�ɕω������ꍇ�A��U�֎~���Ă����g���[�h���ēx������
         if((PreState == OverTheMA || PreState == AboveBand) && State == UnderTheMA)
         {
            g_allow_trade = true;
         }
         //���[�g�̏�Ԃ��A�u�ړ����ς̉��v�܂��́A�u�ړ����ρ|��Pips��艺�v�̏�Ԃ���u�ړ����ς���v�ɕω����Ă����ꍇ�A��U�֎~���Ă����g���[�h���ēx������
         else if((PreState == UnderTheMA || PreState == BelowBand) && State == OverTheMA)
         {
            g_allow_trade = true;
         }
         PreState = State;
      }
   }
   if(OpenTime != Time[0])
   {
      if(HaveBuyStopPosition())
      {
         DeleteBuyStopPosition();
         SendBuyStopOrder();
      }
      else if(HaveSellStopPosition())
      {
         DeleteSellStopPosition();
         SendSellStopOrder();
      }
      OpenTime = Time[0];
   }
}

bool SendBuyStopOrder()
{
   double Lots       = GetLots(g_consecutive_loss);
   double LowerBand  = NormalizeDouble((iMA(Symbol(),PERIOD_CURRENT,MAPeriod,0,MODE_EMA,PRICE_CLOSE,0) - MarginPips * g_OnePipValue),Digits);
   g_StopLossValue   = NormalizeDouble(LowerBand - SL * g_OnePipValue,Digits);
   g_TakeProfitValue = NormalizeDouble(LowerBand + TP * g_OnePipValue,Digits);
   bool a = OrderSend(Symbol(),OP_BUYSTOP,Lots,LowerBand,3,g_StopLossValue,g_TakeProfitValue,"",MagicNumber,0,clrNONE);
   return(a);
}

bool SendSellStopOrder()
{
   double Lots       = GetLots(g_consecutive_loss);
   double UPperBand  = NormalizeDouble((iMA(Symbol(),PERIOD_CURRENT,MAPeriod,0,MODE_EMA,PRICE_CLOSE,0) + MarginPips * g_OnePipValue),Digits);
   g_StopLossValue   = NormalizeDouble(UPperBand + SL * g_OnePipValue,Digits);
   g_TakeProfitValue = NormalizeDouble(UPperBand - TP * g_OnePipValue,Digits);
   bool a = OrderSend(Symbol(),OP_SELLSTOP,Lots,UPperBand,3,g_StopLossValue,g_TakeProfitValue,"",MagicNumber,0,clrNONE);
   return(a);
}

void CheckRateCondition()
{
   double LowerBand  = iMA(Symbol(),PERIOD_CURRENT,MAPeriod,0,MODE_EMA,PRICE_CLOSE,0) - MarginPips * g_OnePipValue;
   double CenterMA   = iMA(Symbol(),PERIOD_CURRENT,MAPeriod,0,MODE_EMA,PRICE_CLOSE,0);
   double UPperBand  = iMA(Symbol(),PERIOD_CURRENT,MAPeriod,0,MODE_EMA,PRICE_CLOSE,0) + MarginPips * g_OnePipValue;
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

double GetLots(int loss_count)
{
   double previous_lots = 0.0;
   double lots          = InitialLots;
   if(Consecutive_Loss_Limit < loss_count)
   {
      lots = InitialLots;
      return(lots);
   }
   else
   {
      for(int i=0;i<loss_count;i++)
      {
         lots = previous_lots + lots * (SL / TP);
         previous_lots = lots;
      }
      lots = NormalizeDouble(lots,DigitOfLots);
      return(lots);
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

bool HaveBuyStopPosition()
{
   for(int i=0; i<OrdersTotal(); i++)
   {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES) == false) return(false);
      if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber)
      {
         if(OrderType() == OP_BUYSTOP)
         {
            return(true);
         }
      }
   }
   return(false);
}

bool HaveSellStopPosition()
{
   for(int i=0; i<OrdersTotal(); i++)
   {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES) == false) return(false);
      if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber)
      {
         if(OrderType() == OP_SELLSTOP)
         {
            return(true);
         }
      }
   }
   return(false);
}

bool DeleteBuyStopPosition()
{
   for(int i=0; i<OrdersTotal(); i++)
   {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES) == false) return(false);
      if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber)
      {
         if(OrderType() == OP_BUYSTOP)
         {
            bool a = OrderDelete(OrderTicket(),clrNONE);
         }
      }
   }
   return(false);
}

bool DeleteSellStopPosition()
{
   for(int i=0; i<OrdersTotal(); i++)
   {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES) == false) return(false);
      if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber)
      {
         if(OrderType() == OP_SELLSTOP)
         {
            bool a = OrderDelete(OrderTicket(),clrNONE);
         }
      }
   }
   return(false);
}