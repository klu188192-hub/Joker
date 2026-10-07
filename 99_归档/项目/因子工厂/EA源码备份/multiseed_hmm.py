"""多 seed HMM 稳定性验证: 5 个不同 random seed 训练, 看 skip-state 选择是否稳定"""
import pandas as pd
import numpy as np
import yfinance as yf
from sklearn.preprocessing import StandardScaler
from hmmlearn.hmm import GaussianHMM
import warnings
warnings.filterwarnings('ignore')

xau = yf.download('GC=F', start='2024-06-01', end='2026-05-15', interval='1h', auto_adjust=True, progress=False)
if isinstance(xau.columns, pd.MultiIndex):
    xau.columns = xau.columns.get_level_values(0)
xau['logret'] = np.log(xau['Close']/xau['Close'].shift(1))
xau['atr'] = (xau['High'] - xau['Low']).rolling(14).mean()
xau['atr_pct'] = xau['atr'] / xau['Close']
xau['rv'] = xau['logret'].rolling(24).std() * np.sqrt(24)
xau['ema50'] = xau['Close'].ewm(span=50).mean()
xau['ema_dist'] = (xau['Close'] - xau['ema50']) / xau['ema50']
xau['mom_10'] = xau['Close'].pct_change(10)
xau['range_pct'] = (xau['High'] - xau['Low']) / xau['Close']
xau = xau.dropna()
features = ['atr_pct', 'rv', 'ema_dist', 'mom_10', 'range_pct']

IS_END = pd.Timestamp('2025-09-30', tz='UTC')
is_mask = xau.index <= IS_END
oos_mask = (xau.index > IS_END)
X_is = xau[is_mask][features].values
X_oos = xau[oos_mask][features].values
scaler = StandardScaler().fit(X_is)
X_is_s = scaler.transform(X_is)
X_oos_s = scaler.transform(X_oos)

df = pd.read_csv('/tmp/v42_deals.csv')
df['time'] = pd.to_datetime(df['time_iso'], format='%Y.%m.%d %H:%M:%S')
positions = df.groupby('pos_id').agg(
    open_time=('time', 'min'), close_time=('time', 'max'),
    total_profit=('profit', 'sum'),
).reset_index()
positions['close_utc'] = pd.to_datetime(positions['close_time']).dt.tz_localize('UTC')
is_trades = positions[positions['close_utc'] <= IS_END].copy()
oos_trades = positions[positions['close_utc'] > IS_END].copy()

is_xau_idx = xau[is_mask].index
oos_xau_idx = xau[oos_mask].index

def find_state(t, idx, states):
    if t < idx[0] or t > idx[-1]: return -1
    pos = idx.searchsorted(t)
    if pos >= len(idx): pos = len(idx) - 1
    return states[pos]

print(f"{'seed':>5} | IS skip states | IS PF kept | OOS PF kept | OOS PF baseline | OOS Δ")
results = []
for seed in [42, 1, 2, 7, 13]:
    model = GaussianHMM(n_components=4, covariance_type='diag', n_iter=200, random_state=seed)
    model.fit(X_is_s)
    states_is = model.predict(X_is_s)
    states_oos = model.predict(X_oos_s)

    is_trades['regime'] = is_trades['close_utc'].apply(lambda t: find_state(t, is_xau_idx, states_is))
    oos_trades['regime'] = oos_trades['close_utc'].apply(lambda t: find_state(t, oos_xau_idx, states_oos))

    is_stats = is_trades[is_trades['regime'] >= 0].groupby('regime')['total_profit'].sum()
    skip = is_stats[is_stats < 0].index.tolist()

    def pf_calc(pnl):
        gp = pnl[pnl > 0].sum()
        gl = -pnl[pnl < 0].sum()
        return gp/gl if gl > 0 else 999

    is_kept = is_trades[(~is_trades['regime'].isin(skip)) & (is_trades['regime'] >= 0)]
    oos_kept = oos_trades[(~oos_trades['regime'].isin(skip)) & (oos_trades['regime'] >= 0)]
    is_pf = pf_calc(is_kept['total_profit'])
    oos_pf = pf_calc(oos_kept['total_profit'])
    oos_base_pf = pf_calc(oos_trades['total_profit'])
    delta = oos_pf - oos_base_pf
    print(f"{seed:>5} | {str(skip):14s} | {is_pf:9.3f} | {oos_pf:11.3f} | {oos_base_pf:15.3f} | {delta:+.3f}")
    results.append({'seed': seed, 'skip': skip, 'is_pf': is_pf, 'oos_pf': oos_pf, 'oos_base': oos_base_pf, 'delta': delta})

import statistics
print(f"\n=== Stability ===")
oos_pfs = [r['oos_pf'] for r in results]
print(f"OOS PF median: {statistics.median(oos_pfs):.3f}, min: {min(oos_pfs):.3f}, max: {max(oos_pfs):.3f}")
deltas = [r['delta'] for r in results]
print(f"OOS Δ vs baseline median: {statistics.median(deltas):+.3f}, min: {min(deltas):+.3f}, max: {max(deltas):+.3f}")
positives = sum(1 for d in deltas if d > 0)
print(f"seeds with positive Δ: {positives}/{len(results)}")
