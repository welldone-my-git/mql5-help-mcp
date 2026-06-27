import MetaTrader5 as mt5

class CAccountInfo:
    def __init__(self, mt5_instance: mt5=mt5):
        
        """CAccountInfo class provides easy access to the currently opened trade account properties in MetaTrader5.
        
            read more: https://www.mql5.com/en/docs/standardlibrary/tradeclasses/caccountinfo
        """
        
        self._account_info = mt5_instance.account_info()
        self.mt5_instance = mt5_instance
        
        if self._account_info is None:
            raise RuntimeError("Failed to retrieve account info: ", mt5_instance.last_error())

    # --- Integer properties
    
    def login(self): 
        return self._account_info.login
    
    def trade_mode(self): 
        return self._account_info.trade_mode
    
    def trade_mode_description(self):
        
        mode_map = {
            self.mt5_instance.ACCOUNT_TRADE_MODE_DEMO: "Demo",
            self.mt5_instance.ACCOUNT_TRADE_MODE_CONTEST: "Contest",
            self.mt5_instance.ACCOUNT_TRADE_MODE_REAL: "Real"
        }
        return mode_map.get(self._account_info.trade_mode, "Unknown")

    def leverage(self): 
        return self._account_info.leverage
    
    def stopout_mode(self): 
        return self._account_info.margin_so_mode
    
    def stopout_mode_description(self):
        
        mode_map = {
            self.mt5_instance.ACCOUNT_STOPOUT_MODE_PERCENT: "Percent",
            self.mt5_instance.ACCOUNT_STOPOUT_MODE_MONEY: "Money"
        }
        
        return mode_map.get(self._account_info.margin_so_mode, "Unknown")

    def margin_mode(self): 
        return self._account_info.margin_mode
    
    def margin_mode_description(self):
        
        mode_map = {
            self.mt5_instance.ACCOUNT_MARGIN_MODE_RETAIL_NETTING: "Retail Netting",
            self.mt5_instance.ACCOUNT_MARGIN_MODE_EXCHANGE: "Exchange",
            self.mt5_instance.ACCOUNT_MARGIN_MODE_RETAIL_HEDGING: "Retail Hedging"
        }
        
        return mode_map.get(self._account_info.margin_mode, "Unknown")

    def trade_allowed(self): 
        return self._account_info.trade_allowed
    
    def trade_expert(self): 
        return self._account_info.trade_expert
    
    def limit_orders(self):
        return self._account_info.limit_orders

    # --- Double properties
    def balance(self):
        return self._account_info.balance
    
    def credit(self):
        
        return self._account_info.credit
    
    def profit(self): 
        return self._account_info.profit
    
    def equity(self): 
        return self._account_info.equity
    
    def margin(self):
        return self._account_info.margin
    
    def free_margin(self): 
        return self._account_info.margin_free
    
    def margin_level(self):
        return self._account_info.margin_level
    
    def margin_call(self):
        return self._account_info.margin_so_call
    
    def margin_stopout(self):
        return self._account_info.margin_so_so

    # --- String properties
    
    def name(self):
        return self._account_info.name
    
    def server(self):
        return self._account_info.server
    
    def currency(self):
        return self._account_info.currency
    
    def company(self):
        return self._account_info.company

    # --- Checks (simulate via order_check or manual math)
    
    def margin_check(self, symbol, order_type, volume, price):
        
        result = self.mt5_instance.order_check({
            "action": self.mt5_instance.TRADE_ACTION_DEAL,
            "symbol": symbol,
            "volume": volume,
            "type": order_type,
            "price": price
        })
        
        return result.margin_required if result is not None else None

    def order_profit_check(self, symbol, order_type, volume, price_open, price_close):
        
        point = self.mt5_instance.symbol_info(symbol).point
        contract_size = self.mt5_instance.symbol_info(symbol).trade_contract_size
        if order_type == self.mt5_instance.ORDER_TYPE_BUY:
            profit = (price_close - price_open) / point * point * volume * contract_size
        else:
            profit = (price_open - price_close) / point * point * volume * contract_size
        return profit

    def free_margin_check(self, symbol, order_type, volume, price):
        
        required_margin = self.margin_check(symbol, order_type, volume, price)
        if required_margin is None:
            return None
        return self.free_margin() - required_margin

    def max_lot_check(self, symbol, order_type, price, percent=100):
        
        # Let's Simulate max lot check based on available margin and required margin per unit
        
        required_margin = self.margin_check(symbol, order_type, 1.0, price)
        if required_margin is None or required_margin == 0:
            return None
        margin_available = self.free_margin() * (percent / 100)
        return margin_available / required_margin

        