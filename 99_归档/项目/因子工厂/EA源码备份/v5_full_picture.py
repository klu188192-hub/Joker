"""v5 WF 完整画像: filter v4.2 trade 计算 IS/OOS 全期 PF/MDD/monthly/DD 段"""
import pandas as pd
import numpy as np
import yfinance as yf
from sklearn.preprocessing import StandardScaler
from hmmlearn.hmm import GaussianHMM
import warnings
warnings.filterwarnings('ignore')

# === HMM Walk-Forward setup (跟 walkforward_hmm.py 相同) ===
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
oos_mask = xau.index > IS_END
X_is = xau[is_mask][features].values
X_oos = xau[oos_mask][features].values
scaler = StandardScaler().fit(X_is)
model = GaussianHMM(n_components=4, covariance_type='diag', n_iter=200, random_state=42)
model.fit(scaler.transform(X_is))
states_is = model.predict(scaler.transform(X_is))
states_oos = model.predict(scaler.transform(X_oos))

# === Trades ===
df = pd.read_csv('/tmp/v42_deals.csv')
df['time'] = pd.to_datetime(df['time_iso'], format='%Y.%m.%d %H:%M:%S')
positions = df.groupby('pos_id').agg(
    open_time=('time', 'min'), close_time=('time', 'max'),
    total_profit=('profit', 'sum'),
    comment_main=('comment', lambda x: x.iloc[0]),
).reset_index()
positions['close_utc'] = pd.to_datetime(positions['close_time']).dt.tz_localize('UTC')
positions['open_utc'] = pd.to_datetime(positions['open_time']).dt.tz_localize('UTC')

def find_state(t, idx, states):
    if t < idx[0] or t > idx[-1]: return -1
    pos = idx.searchsorted(t)
    if pos >= len(idx): pos = len(idx) - 1
    return states[pos]

# regime decided by entry time (跟 EA NewBar 等价)
is_xau_idx = xau[is_mask].index
oos_xau_idx = xau[oos_mask].index

def assign_state(row):
    t = row['open_utc']
    if t <= IS_END:
        return find_state(t, is_xau_idx, states_is)
    else:
        return find_state(t, oos_xau_idx, states_oos)

positions['entry_state'] = positions.apply(assign_state, axis=1)
positions = positions.sort_values('open_utc').reset_index(drop=True)

# === IS decides skip ===
is_pos = positions[positions['open_utc'] <= IS_END]
is_state_pnl = is_pos.groupby('entry_state')['total_profit'].sum()
skip = is_state_pnl[is_state_pnl < 0].index.tolist()
print(f"IS state P&L:\n{is_state_pnl}\nSkip states: {skip}")

# === Apply filter to ALL 22 months ===
positions['kept'] = (~positions['entry_state'].isin(skip)) & (positions['entry_state'] >= 0)
kept = positions[positions['kept']].copy()
skipped = positions[~positions['kept']]
print(f"\n=== Filter applied (full 22 months) ===")
print(f"Total positions: {len(positions)}")
print(f"Kept: {len(kept)} ({len(kept)/len(positions)*100:.1f}%)")
print(f"Skipped: {len(skipped)} ({len(skipped)/len(positions)*100:.1f}%)")
print(f"Kept PnL: ${kept['total_profit'].sum():+.2f}")
print(f"Skipped PnL: ${skipped['total_profit'].sum():+.2f}")

def pf_calc(pnl):
    gp = pnl[pnl > 0].sum(); gl = -pnl[pnl < 0].sum()
    return gp/gl if gl > 0 else 999

# === DD analysis on kept (cumulative equity over time) ===
kept_sorted = kept.sort_values('close_utc').reset_index(drop=True)
initial = 10000
eq = initial + kept_sorted['total_profit'].cumsum()
peak = eq.cummax()
dd_abs = peak - eq
dd_pct = dd_abs / peak * 100
max_dd = dd_pct.max()
print(f"\n=== Equity & DD (kept trades cumulative) ===")
print(f"Final equity: ${eq.iloc[-1]:.2f} (+{(eq.iloc[-1]-initial)/initial*100:.1f}%)")
print(f"Max DD%: {max_dd:.2f}%")

# Top DD segments
kept_sorted['equity'] = eq.values
kept_sorted['peak'] = peak.values
kept_sorted['dd_pct'] = dd_pct.values
kept_sorted['in_dd'] = kept_sorted['equity'] < kept_sorted['peak']
kept_sorted['dd_grp'] = (kept_sorted['in_dd'] != kept_sorted['in_dd'].shift()).cumsum()
dd_segs = kept_sorted[kept_sorted['in_dd']].groupby('dd_grp').agg(
    start=('close_utc', 'min'), end=('close_utc', 'max'),
    max_dd=('dd_pct', 'max'),
).reset_index(drop=True)
dd_segs['days'] = (dd_segs['end'] - dd_segs['start']).dt.days
print("\nTop 3 DD segments:")
for _, r in dd_segs.nlargest(3, 'max_dd').iterrows():
    print(f"  {r['start'].date()} → {r['end'].date()}  {int(r['days']):3d}d  -{r['max_dd']:5.2f}%")

# === IS/OOS split ===
is_kept = kept[kept['open_utc'] <= IS_END]
oos_kept = kept[kept['open_utc'] > IS_END]
print(f"\n=== IS vs OOS split (WF — HMM only trained on IS) ===")
print(f"IS  : n={len(is_kept):3d}  PF={pf_calc(is_kept['total_profit']):.3f}  WR={(is_kept['total_profit']>0).mean()*100:.1f}%  Net=${is_kept['total_profit'].sum():+.2f}")
print(f"OOS : n={len(oos_kept):3d}  PF={pf_calc(oos_kept['total_profit']):.3f}  WR={(oos_kept['total_profit']>0).mean()*100:.1f}%  Net=${oos_kept['total_profit'].sum():+.2f}")

# === Monthly ===
print(f"\n=== Monthly P&L (kept) ===")
kept_sorted['month'] = kept_sorted['close_utc'].dt.to_period('M')
monthly = kept_sorted.groupby('month').agg(
    n=('pos_id', 'count'), pnl=('total_profit', 'sum'),
).reset_index()
losing = 0
for _, r in monthly.iterrows():
    flag = '  ' if r['pnl'] >= 0 else ' *'
    if r['pnl'] < 0: losing += 1
    print(f"{flag}{r['month']}  n={int(r['n']):3d}  pnl=${r['pnl']:+8.2f}")
print(f"\nLosing months: {losing}/{len(monthly)} ({losing/len(monthly)*100:.0f}%)")

# === Pyramid attribution ===
print(f"\n=== Pyramid attribution (kept) ===")
main_kept = kept[~kept['comment_main'].str.contains('Pyr', na=False)]
pyr_kept = kept[kept['comment_main'].str.contains('Pyr', na=False)]
print(f"Main : n={len(main_kept):3d}  PnL=${main_kept['total_profit'].sum():+.2f}  WR={(main_kept['total_profit']>0).mean()*100:.1f}%")
print(f"Pyr  : n={len(pyr_kept):3d}  PnL=${pyr_kept['total_profit'].sum():+.2f}  WR={(pyr_kept['total_profit']>0).mean()*100:.1f}%")
