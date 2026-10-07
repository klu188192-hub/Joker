"""Turtle 5y HMM regime: 训练 HMM filter chop / trend, 输出 regime CSV 给 Turtle EA"""
import pandas as pd
import numpy as np
import yfinance as yf
from sklearn.preprocessing import StandardScaler
from hmmlearn.hmm import GaussianHMM
import warnings
warnings.filterwarnings('ignore')

# 尝试拉 5 年 1h, fallback 到 D1
print("拉 GC=F 5y 1h ...")
try:
    xau_h1 = yf.download('GC=F', start='2020-12-01', end='2026-05-15', interval='1h', auto_adjust=True, progress=False)
    if isinstance(xau_h1.columns, pd.MultiIndex):
        xau_h1.columns = xau_h1.columns.get_level_values(0)
    print(f"  H1 bars: {len(xau_h1)}, {xau_h1.index[0]} → {xau_h1.index[-1]}")
except Exception as e:
    xau_h1 = pd.DataFrame()
    print(f"  H1 失败: {e}")

# 拉 D1 (一定能拿到 5y+)
print("拉 GC=F 5y 1d ...")
xau_d1 = yf.download('GC=F', start='2020-12-01', end='2026-05-15', interval='1d', auto_adjust=True, progress=False)
if isinstance(xau_d1.columns, pd.MultiIndex):
    xau_d1.columns = xau_d1.columns.get_level_values(0)
print(f"  D1 bars: {len(xau_d1)}, {xau_d1.index[0]} → {xau_d1.index[-1]}")

# 用 D1 训 HMM, broadcast 到 H1
xau = xau_d1
xau['logret'] = np.log(xau['Close']/xau['Close'].shift(1))
xau['atr'] = (xau['High'] - xau['Low']).rolling(14).mean()
xau['atr_pct'] = xau['atr'] / xau['Close']
xau['rv'] = xau['logret'].rolling(21).std() * np.sqrt(21)
xau['ema50'] = xau['Close'].ewm(span=50).mean()
xau['ema_dist'] = (xau['Close'] - xau['ema50']) / xau['ema50']
xau['mom_10'] = xau['Close'].pct_change(10)
xau['range_pct'] = (xau['High'] - xau['Low']) / xau['Close']
xau = xau.dropna()
features = ['atr_pct', 'rv', 'ema_dist', 'mom_10', 'range_pct']
print(f"\nHMM 训练数据: {len(xau)} D1 bars from {xau.index[0]} to {xau.index[-1]}")

X = xau[features].values
scaler = StandardScaler().fit(X)
X_s = scaler.transform(X)
model = GaussianHMM(n_components=4, covariance_type='diag', n_iter=200, random_state=42)
model.fit(X_s)
states = model.predict(X_s)
xau['state'] = states

# 每个 state 的特征
print(f"\n--- State Characteristics (D1) ---")
for s in range(4):
    mask = states == s
    n = mask.sum()
    print(f"State {s}: n={n} ({n/len(states)*100:.1f}%)")
    for f in features:
        print(f"  {f:10s}: mean={xau[mask][f].mean():+.4f}")

# Turtle 是 trend follower, 需要 trend regime 入场
# 用 ema_dist (距离 EMA50) 强度判断 trend
# 高 |ema_dist| + 高 momentum = trend
# 低 |ema_dist| + 低 RV = chop
state_trend_score = {}
for s in range(4):
    mask = states == s
    avg_abs_emadist = xau[mask]['ema_dist'].abs().mean()
    avg_abs_mom = xau[mask]['mom_10'].abs().mean()
    avg_rv = xau[mask]['rv'].mean()
    state_trend_score[s] = avg_abs_emadist + avg_abs_mom
    print(f"State {s} trend_score (|ema_dist|+|mom|) = {state_trend_score[s]:.4f}, avg_rv={avg_rv:.4f}")

# 排序: 高 trend_score = trend regime (allow trade), 低 = chop (skip)
sorted_states = sorted(state_trend_score.items(), key=lambda x: -x[1])
print(f"\n排序 (高 trend → 低): {sorted_states}")
# Allow 高 2 个 trend state, skip 低 2 个 chop state
allow_states = [sorted_states[0][0], sorted_states[1][0]]
skip_states = [sorted_states[2][0], sorted_states[3][0]]
print(f"Allow (trend) states: {allow_states}")
print(f"Skip (chop) states: {skip_states}")

# Broadcast D1 state 到 H1 (生成 H1 regime CSV)
# 每个 D1 state 适用于该 D1 内所有 H1 bar
print(f"\n生成 H1 regime CSV (broadcast D1 → 24× H1)...")
out_records = []
for d1_idx, d1_row in xau.iterrows():
    d1_state = int(d1_row['state'])
    d1_allow = 1 if d1_state in allow_states else 0
    # 该 D1 内 24 根 H1 (UTC)
    d1_start = d1_idx.replace(hour=0, minute=0, second=0)
    if d1_start.tz is None:
        d1_start = d1_start.tz_localize('UTC')
    for h in range(24):
        h1_time = d1_start + pd.Timedelta(hours=h)
        out_records.append((h1_time, d1_state, d1_allow))

out = pd.DataFrame(out_records, columns=['utc_dt', 'state', 'allow'])
out['broker_epoch'] = ((out['utc_dt'].dt.tz_localize(None) - pd.Timestamp('1970-01-01')).dt.total_seconds().astype('int64') + 10800)
out_csv = out[['broker_epoch', 'state', 'allow']].copy()
out_csv.to_csv('/tmp/regime_turtle_5y.csv', index=False, header=False)
print(f"  写出 {len(out_csv)} rows")
print(f"  allow %: {out_csv['allow'].mean()*100:.1f}%")
print(f"  覆盖: {out['utc_dt'].iloc[0]} → {out['utc_dt'].iloc[-1]}")
