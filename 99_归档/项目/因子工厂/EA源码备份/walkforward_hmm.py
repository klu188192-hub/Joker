"""
Walk-Forward HMM:
1. IS: 2024.07-2025.09 训练 HMM
2. predict 整 22 月 regime (IS in-sample, OOS out-sample)
3. 用 IS 数据决定 skip-states
4. 导出 regime_wf.csv 给 v5 EA
5. 解析 v5 deal CSV 算 IS / OOS PF / MDD
"""
import pandas as pd
import numpy as np
import yfinance as yf
from sklearn.preprocessing import StandardScaler
from hmmlearn.hmm import GaussianHMM
import warnings
warnings.filterwarnings('ignore')

# ============ 1. 数据 ============
print("拉 XAU H1 ...")
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
print(f"  bars: {len(xau)}, {xau.index[0]} → {xau.index[-1]}")

features = ['atr_pct', 'rv', 'ema_dist', 'mom_10', 'range_pct']

# ============ 2. 切 IS / OOS ============
IS_END = pd.Timestamp('2025-09-30', tz='UTC')
OOS_END = pd.Timestamp('2026-05-15', tz='UTC')
is_mask = xau.index <= IS_END
oos_mask = (xau.index > IS_END) & (xau.index <= OOS_END)
print(f"\nIS:  {is_mask.sum()} bars ({xau[is_mask].index[0]} → {xau[is_mask].index[-1]})")
print(f"OOS: {oos_mask.sum()} bars ({xau[oos_mask].index[0]} → {xau[oos_mask].index[-1]})")

# ============ 3. 训练 HMM 仅用 IS ============
X_is = xau[is_mask][features].values
scaler = StandardScaler().fit(X_is)
X_is_s = scaler.transform(X_is)
print(f"\n训练 HMM 4 states on {len(X_is)} IS bars ...")
model = GaussianHMM(n_components=4, covariance_type='diag', n_iter=200, random_state=42)
model.fit(X_is_s)
states_is = model.predict(X_is_s)
print(f"  converged: {model.monitor_.converged}")

# ============ 4. predict OOS ============
X_oos = xau[oos_mask][features].values
X_oos_s = scaler.transform(X_oos)
states_oos = model.predict(X_oos_s)

# ============ 5. 解析 v4.2 deal CSV 按 IS state 决定 skip ============
df = pd.read_csv('/tmp/v42_deals.csv')
df['time'] = pd.to_datetime(df['time_iso'], format='%Y.%m.%d %H:%M:%S')
positions = df.groupby('pos_id').agg(
    open_time=('time', 'min'), close_time=('time', 'max'),
    total_profit=('profit', 'sum'),
).reset_index()
positions['close_utc'] = pd.to_datetime(positions['close_time']).dt.tz_localize('UTC')

# 把 IS state 标到 IS trades
is_xau_idx = xau[is_mask].index
oos_xau_idx = xau[oos_mask].index

def find_state(t, idx, states):
    if t < idx[0] or t > idx[-1]:
        return -1
    pos = idx.searchsorted(t)
    if pos >= len(idx): pos = len(idx) - 1
    return states[pos]

is_trades = positions[positions['close_utc'] <= IS_END].copy()
oos_trades = positions[(positions['close_utc'] > IS_END) & (positions['close_utc'] <= OOS_END)].copy()
is_trades['regime'] = is_trades['close_utc'].apply(lambda t: find_state(t, is_xau_idx, states_is))
oos_trades['regime'] = oos_trades['close_utc'].apply(lambda t: find_state(t, oos_xau_idx, states_oos))

# IS 各 state P&L
print("\n--- IS state P&L (训练用, 决定 skip-states) ---")
is_stats = is_trades[is_trades['regime'] >= 0].groupby('regime').agg(
    n=('pos_id', 'count'), pnl=('total_profit', 'sum'),
    wr=('total_profit', lambda x: (x>0).mean()*100),
)
print(is_stats.to_string())

# Skip states = 亏损 states (IS决定)
skip_states = is_stats[is_stats['pnl'] < 0].index.tolist()
print(f"\n根据 IS, skip states = {skip_states}")

# ============ 6. OOS state P&L (HMM 没见过 OOS 数据) ============
print("\n--- OOS state P&L (真 out-of-sample 验证) ---")
oos_stats = oos_trades[oos_trades['regime'] >= 0].groupby('regime').agg(
    n=('pos_id', 'count'), pnl=('total_profit', 'sum'),
    wr=('total_profit', lambda x: (x>0).mean()*100),
)
print(oos_stats.to_string())

# OOS 应用 IS-决定 skip
oos_kept = oos_trades[~oos_trades['regime'].isin(skip_states) & (oos_trades['regime'] >= 0)]
oos_skipped = oos_trades[oos_trades['regime'].isin(skip_states)]
print(f"\nOOS apply IS-decided skip {skip_states}:")
print(f"  保留 trades: {len(oos_kept)}  PnL=${oos_kept['total_profit'].sum():+.2f}")
print(f"  砍掉 trades: {len(oos_skipped)} PnL=${oos_skipped['total_profit'].sum():+.2f}")

# 算 OOS PF / WR
kept_pnl = oos_kept['total_profit']
gp = kept_pnl[kept_pnl > 0].sum()
gl = -kept_pnl[kept_pnl < 0].sum()
oos_pf = gp/gl if gl > 0 else 999
oos_wr = (kept_pnl > 0).mean() * 100
print(f"\nOOS filtered PF: {oos_pf:.3f}, WR: {oos_wr:.1f}%, n: {len(oos_kept)}")

# OOS no-filter baseline
all_pnl = oos_trades['total_profit']
gp_all = all_pnl[all_pnl > 0].sum()
gl_all = -all_pnl[all_pnl < 0].sum()
oos_pf_baseline = gp_all/gl_all if gl_all > 0 else 999
print(f"OOS baseline (no filter) PF: {oos_pf_baseline:.3f}, n: {len(oos_trades)}")
print(f"OOS filter 改善: PF {oos_pf_baseline:.3f} → {oos_pf:.3f}")

# ============ 7. 导出 walk-forward regime CSV ============
# IS 段 state, OOS 段 state 合并
print("\n--- 导出 regime_wf.csv ---")
wf_records = []
for i, t in enumerate(is_xau_idx):
    s = states_is[i]
    allow = 0 if s in skip_states else 1
    wf_records.append((t, s, allow))
for i, t in enumerate(oos_xau_idx):
    s = states_oos[i]
    allow = 0 if s in skip_states else 1
    wf_records.append((t, s, allow))

wf_df = pd.DataFrame(wf_records, columns=['utc_dt', 'state', 'allow'])
wf_df['broker_epoch'] = ((wf_df['utc_dt'].dt.tz_localize(None) - pd.Timestamp('1970-01-01')).dt.total_seconds().astype('int64') + 10800)
wf_df[['broker_epoch', 'state', 'allow']].to_csv('/tmp/regime_wf.csv', index=False, header=False)
print(f"  rows: {len(wf_df)}, allow: {wf_df['allow'].sum()} ({wf_df['allow'].mean()*100:.1f}%)")
