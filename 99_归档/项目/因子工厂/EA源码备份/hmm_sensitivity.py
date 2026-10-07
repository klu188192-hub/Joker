"""HMM 参数 sensitivity: IS 切分时间 + states 数 ; 防过拟合验证"""
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

df = pd.read_csv('/tmp/v42_deals.csv')
df['time'] = pd.to_datetime(df['time_iso'], format='%Y.%m.%d %H:%M:%S')
positions = df.groupby('pos_id').agg(
    open_time=('time', 'min'), close_time=('time', 'max'),
    total_profit=('profit', 'sum'),
).reset_index()
positions['close_utc'] = pd.to_datetime(positions['close_time']).dt.tz_localize('UTC')

def find_state(t, idx, states):
    if t < idx[0] or t > idx[-1]: return -1
    pos = idx.searchsorted(t)
    if pos >= len(idx): pos = len(idx) - 1
    return states[pos]

def pf_calc(pnl):
    gp = pnl[pnl > 0].sum()
    gl = -pnl[pnl < 0].sum()
    return gp/gl if gl > 0 else 999

def run_wf(is_end_str, n_states, seed=42):
    IS_END = pd.Timestamp(is_end_str, tz='UTC')
    is_mask = xau.index <= IS_END
    oos_mask = xau.index > IS_END
    X_is = xau[is_mask][features].values
    X_oos = xau[oos_mask][features].values
    scaler = StandardScaler().fit(X_is)
    X_is_s = scaler.transform(X_is)
    X_oos_s = scaler.transform(X_oos)
    model = GaussianHMM(n_components=n_states, covariance_type='diag', n_iter=200, random_state=seed)
    model.fit(X_is_s)
    states_is = model.predict(X_is_s)
    states_oos = model.predict(X_oos_s)

    is_xau_idx = xau[is_mask].index
    oos_xau_idx = xau[oos_mask].index
    is_t = positions[positions['close_utc'] <= IS_END].copy()
    oos_t = positions[positions['close_utc'] > IS_END].copy()
    is_t['regime'] = is_t['close_utc'].apply(lambda t: find_state(t, is_xau_idx, states_is))
    oos_t['regime'] = oos_t['close_utc'].apply(lambda t: find_state(t, oos_xau_idx, states_oos))

    is_stats = is_t[is_t['regime'] >= 0].groupby('regime')['total_profit'].sum()
    skip = is_stats[is_stats < 0].index.tolist()

    oos_kept = oos_t[(~oos_t['regime'].isin(skip)) & (oos_t['regime'] >= 0)]
    oos_pf = pf_calc(oos_kept['total_profit'])
    oos_base_pf = pf_calc(oos_t['total_profit'])
    return {
        'is_end': is_end_str, 'n_states': n_states,
        'is_n': len(is_t), 'oos_n': len(oos_t), 'oos_kept_n': len(oos_kept),
        'skip': skip, 'oos_pf': oos_pf, 'oos_base': oos_base_pf,
        'delta': oos_pf - oos_base_pf, 'oos_kept_pnl': oos_kept['total_profit'].sum(),
    }

print(f"{'IS_end':12s} {'N':3s} {'is_n':>5s} {'oos_n':>5s} {'kept':>4s} {'skip':12s} {'oos_pf':>7s} {'base':>7s} {'Δ':>7s} {'pnl':>8s}")
results = []
for is_end in ['2025-06-30', '2025-09-30', '2025-12-31']:
    for ns in [3, 4, 5]:
        r = run_wf(is_end, ns)
        results.append(r)
        print(f"{r['is_end']:12s} {r['n_states']:3d} {r['is_n']:5d} {r['oos_n']:5d} {r['oos_kept_n']:4d} {str(r['skip'])[:12]:12s} {r['oos_pf']:7.3f} {r['oos_base']:7.3f} {r['delta']:+7.3f} ${r['oos_kept_pnl']:+8.2f}")

# 统计
deltas = [r['delta'] for r in results]
positives = sum(1 for d in deltas if d > 0)
print(f"\nPositive OOS Δ: {positives}/{len(results)} ({positives/len(results)*100:.0f}%)")
import statistics
print(f"OOS PF median: {statistics.median([r['oos_pf'] for r in results]):.3f}")
print(f"OOS Δ median: {statistics.median(deltas):+.3f}")
