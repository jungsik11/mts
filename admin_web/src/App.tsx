import { useState, useEffect } from 'react';
import { 
  LineChart, 
  Line, 
  XAxis, 
  YAxis, 
  CartesianGrid, 
  Tooltip, 
  ResponsiveContainer
} from 'recharts';
import './index.css';

interface User {
  id: number;
  username: string;
  email: string;
  password?: string;
  accounts: Array<{
    accountNumber: string;
    accountType: string;
    balance: number;
  }>;
  assets: Array<{
    ticker: string;
    quantity: number;
    avgPrice: number;
  }>;
}

interface Ticker {
  ticker: string;
  price: number;
  basePrice?: number;
  name: string;
  sector: string;
  data?: string;
  raw?: string;
}

interface SystemMetrics {
  cpuUsage: string;
  totalMemory: number;
  usedMemory: number;
  freeMemory: number;
  memoryUsagePercent: string;
  jvm: {
    total: number;
    used: number;
    free: number;
  };
  health: {
    [key: string]: string;
  };
  heartbeats: {
    [key: string]: {
      status: string;
      timestamp?: string;
      [key: string]: any;
    };
  };
  availableProcessors: number;
  systemLoadAverage: number;
}

interface Trade {
  id: number;
  buyerId: number;
  sellerId: number;
  ticker: string;
  price: number;
  quantity: number;
  timestamp: string;
}

function App() {
  const [activeTab, setActiveTab] = useState<'users' | 'stocks' | 'price-check' | 'system' | 'trades'>('users');
  const [users, setUsers] = useState<User[]>([]);
  const [tickers, setTickers] = useState<Ticker[]>([]);
  const [systemMetrics, setSystemMetrics] = useState<{[key: string]: SystemMetrics}>({});
  const [metricsHistory, setMetricsHistory] = useState<{[key: string]: any[]}>({});
  const [priceHistory, setPriceHistory] = useState<{[key: string]: any[]}>({});
  const [trades, setTrades] = useState<Trade[]>([]);
  
  // Modal States
  const [showUserModal, setShowUserModal] = useState(false);
  const [showTickerModal, setShowTickerModal] = useState(false);
  const [showAddTickerModal, setShowAddTickerModal] = useState(false);
  const [newTicker, setNewTicker] = useState({ ticker: '', initialPrice: 0, name: '', sector: '' });
  const [editingUser, setEditingUser] = useState<User | null>(null);
  const [editingTicker, setEditingTicker] = useState<Ticker | null>(null);
  const [loading, setLoading] = useState(false);
  const [originalTickerSymbol, setOriginalTickerSymbol] = useState<string>("");

  const fetchUsers = async () => {
    try {
      const res = await fetch('http://localhost:9000/admin/users');
      const data = await res.json();
      setUsers(data);
    } catch (e) { console.error(e); }
  };

  const fetchTickers = async () => {
    try {
      const res = await fetch('http://localhost:9001/admin/tickers');
      const data: Ticker[] = await res.json();
      setTickers(data);

      const timestamp = new Date().toLocaleTimeString('ko-KR', { hour12: false, hour: '2-digit', minute: '2-digit', second: '2-digit' });

      setPriceHistory(prev => {
        const newHistory = { ...prev };
        data.forEach(t => {
          const history = newHistory[t.ticker] || [];
          newHistory[t.ticker] = [...history, {
            time: timestamp,
            price: t.price
          }].slice(-30);
        });
        return newHistory;
      });
    } catch (e) { console.error(e); }
  };

  const fetchSystemMetrics = async () => {
    try {
      // Fetch from Trading Server
      const resTrading = await fetch('http://localhost:9001/admin/system/metrics');
      const dataTrading = await resTrading.json();
      
      // Fetch from Account Server
      const resAccount = await fetch('http://localhost:9000/admin/system/metrics');
      const dataAccount = await resAccount.json();

      const timestamp = new Date().toLocaleTimeString('ko-KR', { hour12: false, hour: '2-digit', minute: '2-digit', second: '2-digit' });

      setSystemMetrics({
        'Trading Server': dataTrading,
        'Redis (Cache)': dataTrading.redisMetrics,
        'Account Server': dataAccount,
        'PostgreSQL (User DB)': dataAccount.dbMetrics
      });

      setMetricsHistory(prev => {
        const newHistory = { ...prev };
        const servers = {
          'Trading Server': dataTrading,
          'Redis (Cache)': dataTrading.redisMetrics,
          'Account Server': dataAccount,
          'PostgreSQL (User DB)': dataAccount.dbMetrics
        };

        Object.entries(servers).forEach(([name, data]) => {
          if (!data) return;
          const history = newHistory[name] || [];
          newHistory[name] = [...history, {
            time: timestamp,
            cpu: parseFloat(data.cpuUsage),
            memoryMB: Math.round(data.usedMemory / (1024 * 1024)),
            jvmMB: data.jvm ? Math.round(data.jvm.used / (1024 * 1024)) : 0,
            memoryTotalMB: Math.round(data.totalMemory / (1024 * 1024)),
            jvmTotalMB: data.jvm ? Math.round(data.jvm.total / (1024 * 1024)) : 0
          }].slice(-30); // Keep last 30 data points
        });
        return newHistory;
      });
    } catch (e) { console.error(e); }
  };

  const fetchTrades = async () => {
    try {
      const res = await fetch('http://localhost:9000/admin/trades');
      const data = await res.json();
      setTrades(data);
    } catch (e) { console.error(e); }
  };

  useEffect(() => {
    fetchUsers();
    fetchTickers();
    fetchSystemMetrics();
    fetchTrades();

    const interval = setInterval(() => {
      if (activeTab === 'system') fetchSystemMetrics();
      if (activeTab === 'trades') fetchTrades();
      if (activeTab === 'price-check' || activeTab === 'stocks') fetchTickers();
    }, 3000);

    return () => clearInterval(interval);
  }, [activeTab]);

  // User Edit Logic
  const handleEditUser = (user: User) => {
    setEditingUser(JSON.parse(JSON.stringify(user))); // Deep clone
    setShowUserModal(true);
  };

  const addUserAsset = () => {
    if (!editingUser) return;
    setEditingUser({
      ...editingUser,
      assets: [...editingUser.assets, { ticker: tickers[0]?.ticker || '', quantity: 0, avgPrice: 0 }]
    });
  };

  const removeUserAsset = (index: number) => {
    if (!editingUser) return;
    const newAssets = [...editingUser.assets];
    newAssets.splice(index, 1);
    setEditingUser({ ...editingUser, assets: newAssets });
  };

  const saveUserUpdate = async () => {
    if (!editingUser) return;
    setLoading(true);
    try {
      const res = await fetch(`http://localhost:9000/admin/users/${editingUser.id}/full`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          username: editingUser.username,
          email: editingUser.email,
          password: editingUser.password || undefined,
          accounts: editingUser.accounts.map(a => ({ accountNumber: a.accountNumber, balance: a.balance })),
          assets: editingUser.assets.filter(a => a.ticker)
        })
      });
      if (res.ok) {
        await fetchUsers();
        setShowUserModal(false);
      } else {
        alert("Failed to update user: " + res.statusText);
      }
    } catch (e) { 
      console.error(e);
      alert("Failed to update user: Connection Error"); 
    } finally {
      setLoading(false);
    }
  };

  const handleDeleteUser = async (userId: number) => {
    if (!window.confirm("Are you sure you want to delete this user and all their data?")) return;
    try {
      const response = await fetch(`http://localhost:9000/admin/users/${userId}`, {
        method: 'DELETE'
      });
      if (response.ok) {
        setUsers(users.filter(u => u.id !== userId));
      } else {
        alert("Failed to delete user");
      }
    } catch (err) {
      console.error("Delete user error:", err);
    }
  };

  const handleDeleteTicker = async (ticker: string) => {
    if (!window.confirm(`Are you sure you want to delete ${ticker}?`)) return;
    try {
      const response = await fetch(`http://localhost:9001/admin/ticker/remove?ticker=${ticker}`, {
        method: 'POST'
      });
      if (response.ok) {
        setTickers(tickers.filter(t => t.ticker !== ticker));
      } else {
        alert("Failed to delete ticker");
      }
    } catch (err) {
      console.error("Delete ticker error:", err);
    }
  };

  // Ticker Edit Logic
  const handleEditTicker = (ticker: Ticker) => {
    setEditingTicker(JSON.parse(JSON.stringify(ticker)));
    setOriginalTickerSymbol(ticker.ticker);
    setShowTickerModal(true);
  };

  const saveTickerUpdate = async () => {
    if (!editingTicker) return;
    setLoading(true);
    try {
      const res = await fetch(`http://localhost:9001/admin/tickers/${originalTickerSymbol}/full`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          ticker: editingTicker.ticker,
          price: editingTicker.price,
          name: editingTicker.name,
          sector: editingTicker.sector
        })
      });
      if (res.ok) {
        await fetchTickers();
        setShowTickerModal(false);
      } else {
        alert("Failed to update ticker: " + res.statusText);
      }
    } catch (e) { 
      console.error(e);
      alert("Failed to update ticker: Connection Error"); 
    } finally {
      setLoading(false);
    }
  };

  const handleAddTicker = async () => {
    if (!newTicker.ticker || newTicker.initialPrice <= 0) {
      alert("Please enter a valid ticker and price");
      return;
    }
    setLoading(true);
    try {
      const res = await fetch('http://localhost:9001/admin/ticker/add', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(newTicker)
      });
      if (res.ok) {
        await fetchTickers();
        setShowAddTickerModal(false);
        setNewTicker({ ticker: '', initialPrice: 0, name: '', sector: '' });
      } else {
        alert("Failed to add ticker");
      }
    } catch (e) {
      console.error(e);
    } finally {
      setLoading(false);
    }
  };

  const handleQuickDeleteHolding = async (userId: number, ticker: string) => {
    if (!window.confirm(`Delete ${ticker} from user's holdings?`)) return;
    const user = users.find(u => u.id === userId);
    if (!user) return;
    const newAssets = user.assets.filter(a => a.ticker !== ticker);
    try {
      const res = await fetch(`http://localhost:9000/admin/users/${userId}/full`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          username: user.username,
          email: user.email,
          accounts: user.accounts.map(a => ({ accountNumber: a.accountNumber, balance: a.balance })),
          assets: newAssets
        })
      });
      if (res.ok) await fetchUsers();
    } catch (e) { console.error(e); }
  };

  return (
    <div className="admin-layout">
      <div className="sidebar">
        <h1>MTS ADMIN</h1>
        <div className="nav-links">
          <div className={`nav-item ${activeTab === 'users' ? 'active' : ''}`} onClick={() => setActiveTab('users')}>Users & Accounts</div>
          <div className={`nav-item ${activeTab === 'stocks' ? 'active' : ''}`} onClick={() => setActiveTab('stocks')}>Stock Management</div>
          <div className={`nav-item ${activeTab === 'price-check' ? 'active' : ''}`} onClick={() => setActiveTab('price-check')}>Price Data Check</div>
          <div className={`nav-item ${activeTab === 'system' ? 'active' : ''}`} onClick={() => setActiveTab('system')}>System Monitor</div>
          <div className={`nav-item ${activeTab === 'trades' ? 'active' : ''}`} onClick={() => setActiveTab('trades')}>Trade History</div>
        </div>
      </div>

      <main className="main-content">
        <header style={{ marginBottom: '2rem', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <h2>{activeTab === 'users' ? 'Users & Accounts' : activeTab === 'stocks' ? 'Stock Management' : activeTab === 'price-check' ? 'Price Data Check' : activeTab === 'system' ? 'System Monitor' : 'Trade History'}</h2>
          {activeTab === 'stocks' && (
            <button className="btn btn-primary" onClick={() => setShowAddTickerModal(true)}>+ Add Ticker</button>
          )}
        </header>

        <div className="stats-grid">
          <div className="stat-card"><h3>Total Users</h3><div className="value">{users.length}</div></div>
          <div className="stat-card"><h3>Active Tickers</h3><div className="value">{tickers.length}</div></div>
        </div>

        {activeTab === 'users' ? (
          <div className="dashboard-card">
            <table>
              <thead><tr><th>User</th><th>Details</th><th>Holdings</th><th>Actions</th></tr></thead>
              <tbody>
                {users.map(user => (
                  <tr key={user.id}>
                    <td>
                      <strong>{user.username}</strong><br/>
                      <span style={{ fontSize: '0.8rem', color: 'var(--text-secondary)' }}>{user.email}</span>
                    </td>
                    <td>
                      {user.accounts.map(acc => (
                        <div key={acc.accountNumber} style={{ fontSize: '0.85rem' }}>
                          {acc.accountNumber} ({acc.accountType}): <strong>₩{acc.balance.toLocaleString()}</strong>
                        </div>
                      ))}
                    </td>
                    <td>
                      <div style={{ display: 'flex', flexWrap: 'wrap', gap: '0.5rem' }}>
                        {user.assets.length > 0 ? user.assets.map(asset => (
                          <span key={asset.ticker} style={{ background: 'rgba(56, 189, 248, 0.1)', color: 'var(--accent-color)', padding: '0.2rem 0.5rem', borderRadius: '0.4rem', fontSize: '0.8rem', display: 'flex', alignItems: 'center', gap: '0.3rem' }}>
                            {asset.ticker}: {asset.quantity}주
                            <span 
                              style={{ cursor: 'pointer', opacity: 0.7, fontWeight: 'bold' }} 
                              onClick={() => handleQuickDeleteHolding(user.id, asset.ticker)}
                              title="Delete Holding"
                            >
                              ×
                            </span>
                          </span>
                        )) : <span style={{ color: 'var(--text-secondary)', fontSize: '0.8rem' }}>None</span>}
                      </div>
                    </td>
                    <td style={{ display: 'flex', gap: '0.5rem' }}>
                      <button className="btn btn-primary" onClick={() => handleEditUser(user)}>Manage User</button>
                      <button className="btn btn-danger" onClick={() => handleDeleteUser(user.id)}>Delete</button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : activeTab === 'stocks' ? (
          <div className="dashboard-card">
            <table>
              <thead><tr><th>Ticker</th><th>Company</th><th>Sector</th><th>Price</th><th>Actions</th></tr></thead>
              <tbody>
                {tickers.map(t => (
                  <tr key={t.ticker}>
                    <td><strong>{t.ticker}</strong></td>
                    <td>{t.name}</td>
                    <td><span style={{ fontSize: '0.85rem', opacity: 0.8 }}>{t.sector}</span></td>
                    <td><strong>₩{Number(t.price).toLocaleString()}</strong></td>
                    <td style={{ display: 'flex', gap: '0.5rem' }}>
                      <button className="btn btn-primary" onClick={() => handleEditTicker(t)}>Edit Info</button>
                      <button className="btn btn-danger" onClick={() => handleDeleteTicker(t.ticker)}>Delete</button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : activeTab === 'price-check' ? (
          <div className="dashboard-card">
            <div style={{ marginBottom: '1rem', color: 'var(--text-secondary)', fontSize: '0.9rem' }}>
              Real-time price data cached in Redis. Reference price is used to calculate daily fluctuations.
            </div>
            <table>
              <thead><tr><th>Ticker</th><th>Name</th><th>Current Price</th><th>Trend (Last 30)</th><th>Base Price</th><th>Change</th><th>Raw Redis Data</th></tr></thead>
              <tbody>
                {tickers.map(t => {
                  let rawData = {};
                  try {
                    rawData = JSON.parse(t.data || t.raw || '{}');
                  } catch(e) {}
                  
                  const basePrice = t.basePrice || 0;
                  const currentPrice = t.price || 0;
                  const diff = basePrice !== 0 ? currentPrice - basePrice : 0;
                  const percent = basePrice !== 0 ? (diff / basePrice * 100).toFixed(2) : '0.00';
                  const color = diff > 0 ? '#ef4444' : diff < 0 ? '#3b82f6' : 'white';
                  
                  return (
                    <tr key={t.ticker}>
                      <td><strong>{t.ticker}</strong></td>
                      <td>{t.name}</td>
                      <td><strong style={{ color: 'var(--accent-color)' }}>₩{currentPrice.toLocaleString()}</strong></td>
                      <td style={{ width: '220px', height: '100px', padding: '10px' }}>
                        <ResponsiveContainer width="100%" height="100%">
                          <LineChart data={priceHistory[t.ticker]} margin={{ top: 5, right: 5, left: -20, bottom: 5 }}>
                            <CartesianGrid strokeDasharray="2 2" stroke="rgba(255,255,255,0.05)" />
                            <XAxis dataKey="time" hide />
                            <YAxis domain={['auto', 'auto']} stroke="#94a3b8" fontSize={10} tick={{ fill: '#94a3b8' }} />
                            <Tooltip contentStyle={{ background: '#0f172a', border: 'none', fontSize: '10px' }} labelStyle={{ display: 'none' }} />
                            <Line type="monotone" dataKey="price" stroke={color} strokeWidth={2} dot={false} animationDuration={300} />
                          </LineChart>
                        </ResponsiveContainer>
                      </td>
                      <td>₩{basePrice.toLocaleString()}</td>
                      <td style={{ color }}>
                        {diff > 0 ? '+' : ''}{diff.toLocaleString()} ({percent}%)
                      </td>
                      <td>
                        <code style={{ fontSize: '0.75rem', background: 'rgba(255,255,255,0.05)', padding: '0.3rem', borderRadius: '4px', display: 'block', maxWidth: '300px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                          {t.raw || JSON.stringify(rawData)}
                        </code>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        ) : activeTab === 'system' ? (
          <div className="system-monitor">
            {Object.keys(systemMetrics).length > 0 ? (
              <div style={{ display: 'flex', flexDirection: 'column', gap: '3rem' }}>
                {Object.entries(systemMetrics).map(([serviceName, metrics]) => (
                  <div key={serviceName}>
                    <h3 style={{ marginBottom: '1rem', color: 'var(--accent-color)', borderBottom: '1px solid var(--border-color)', paddingBottom: '0.5rem' }}>
                      {serviceName}
                    </h3>
                    <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '2rem' }}>
                      {/* CPU Chart */}
                      <div className="dashboard-card" style={{ height: '400px' }}>
                        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1.5rem' }}>
                          <h3>CPU Usage (%)</h3>
                          <strong style={{ color: 'var(--accent-color)' }}>{metrics.cpuUsage}%</strong>
                        </div>
                        <div style={{ height: '280px', width: '100%' }}>
                          <ResponsiveContainer width="100%" height="100%">
                            <LineChart data={metricsHistory[serviceName]} margin={{ top: 10, right: 30, left: 0, bottom: 20 }}>
                              <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.1)" />
                              <XAxis dataKey="time" stroke="#94a3b8" fontSize={11} tickMargin={10} />
                              <YAxis domain={[0, 100]} stroke="#94a3b8" fontSize={11} label={{ value: '%', angle: 0, position: 'insideTopLeft', offset: -10, fill: '#94a3b8' }} />
                              <Tooltip contentStyle={{ background: '#0f172a', border: '1px solid var(--accent-color)' }} />
                              <Line type="monotone" dataKey="cpu" stroke="var(--accent-color)" strokeWidth={2} dot={{ r: 3 }} name="CPU %" />
                            </LineChart>
                          </ResponsiveContainer>
                        </div>
                        <div style={{ fontSize: '0.8rem', color: 'var(--text-secondary)', marginTop: '1rem' }}>
                          Processors: {metrics.availableProcessors} | Load Avg: {metrics.systemLoadAverage}
                        </div>
                      </div>

                      {/* Memory Chart */}
                      <div className="dashboard-card" style={{ height: '400px' }}>
                        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1.5rem' }}>
                          <h3>Memory Usage (MB)</h3>
                          <div style={{ fontSize: '0.8rem', display: 'flex', gap: '1rem' }}>
                            <span style={{ color: 'var(--success)' }}>Container: {Math.round(metrics.usedMemory/(1024*1024))}MB</span>
                            <span style={{ color: '#f59e0b' }}>JVM: {Math.round(metrics.jvm.used/(1024*1024))}MB</span>
                          </div>
                        </div>
                        <div style={{ height: '280px', width: '100%' }}>
                          <ResponsiveContainer width="100%" height="100%">
                            <LineChart data={metricsHistory[serviceName]} margin={{ top: 10, right: 30, left: 10, bottom: 20 }}>
                              <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.1)" />
                              <XAxis dataKey="time" stroke="#94a3b8" fontSize={11} tickMargin={10} />
                              <YAxis stroke="#94a3b8" fontSize={11} label={{ value: 'MB', angle: 0, position: 'insideTopLeft', offset: -10, fill: '#94a3b8' }} />
                              <Tooltip contentStyle={{ background: '#0f172a', border: '1px solid var(--success)' }} />
                              <Line type="monotone" dataKey="memoryMB" stroke="var(--success)" strokeWidth={2} dot={{ r: 3 }} name="Container MB" />
                              <Line type="monotone" dataKey="jvmMB" stroke="#f59e0b" strokeWidth={2} dot={{ r: 3 }} name="JVM MB" />
                            </LineChart>
                          </ResponsiveContainer>
                        </div>
                        <div style={{ fontSize: '0.8rem', color: 'var(--text-secondary)', marginTop: '1rem', display: 'flex', justifyContent: 'space-between' }}>
                          <span>Total: {Math.round(metrics.totalMemory/(1024*1024))}MB</span>
                          <span>JVM Total: {Math.round(metrics.jvm.total/(1024*1024))}MB</span>
                        </div>
                      </div>
                    </div>

                    {metrics.health && (
                      <div className="dashboard-card" style={{ gridColumn: 'span 2' }}>
                        <h3>Service Connectivity</h3>
                        <div style={{ display: 'flex', gap: '2rem', marginTop: '1rem' }}>
                          {Object.entries(metrics.health).map(([service, status]) => (
                            <div key={service} style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', background: 'rgba(255,255,255,0.05)', padding: '0.5rem 1rem', borderRadius: '8px' }}>
                              <div style={{ width: '10px', height: '10px', borderRadius: '50%', background: status === 'UP' ? 'var(--success)' : 'var(--danger)' }}></div>
                              <span style={{ textTransform: 'capitalize' }}>{service.replace(/([A-Z])/g, ' $1')}:</span>
                              <strong style={{ color: status === 'UP' ? 'var(--success)' : 'var(--danger)' }}>{status}</strong>
                            </div>
                          ))}
                        </div>
                      </div>
                    )}
                  </div>
                ))}
              </div>
            ) : (
              <div className="dashboard-card">Loading per-container metrics...</div>
            )}
          </div>
        ) : (
          <div className="dashboard-card">
            <div style={{ marginBottom: '1rem', color: 'var(--text-secondary)', fontSize: '0.9rem' }}>
              Showing latest 50 trade executions in the system.
            </div>
            <table>
              <thead><tr><th>ID</th><th>Ticker</th><th>Price</th><th>Qty</th><th>Buyer ID</th><th>Seller ID</th><th>Time</th></tr></thead>
              <tbody>
                {trades.map(trade => (
                  <tr key={trade.id}>
                    <td>{trade.id}</td>
                    <td><strong>{trade.ticker}</strong></td>
                    <td>₩{trade.price.toLocaleString()}</td>
                    <td>{trade.quantity}</td>
                    <td>{trade.buyerId}</td>
                    <td>{trade.sellerId}</td>
                    <td style={{ fontSize: '0.85rem', opacity: 0.8 }}>{new Date(trade.timestamp).toLocaleString()}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </main>

      {/* Full User Edit Modal */}
      {showUserModal && editingUser && (
        <div className="modal-overlay">
          <div className="modal-container" style={{ maxWidth: '600px' }}>
            <div className="modal-header"><h3>Manage User: {editingUser.username}</h3></div>
            <div className="modal-body" style={{ maxHeight: '70vh', overflowY: 'auto', paddingRight: '1rem' }}>
              <h4 style={{ marginBottom: '1rem', color: 'var(--accent-color)' }}>Basic Information</h4>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem' }}>
                <div className="form-group">
                  <label>Username</label>
                  <input className="glass-input" value={editingUser.username} onChange={e => setEditingUser({...editingUser, username: e.target.value})} />
                </div>
                <div className="form-group">
                  <label>Email</label>
                  <input className="glass-input" value={editingUser.email} onChange={e => setEditingUser({...editingUser, email: e.target.value})} />
                </div>
              </div>
              <div className="form-group" style={{ marginTop: '1rem' }}>
                <label>New Password (leave blank to keep current)</label>
                <input 
                  type="password" 
                  className="glass-input" 
                  placeholder="Enter new password"
                  value={editingUser.password || ''} 
                  onChange={e => setEditingUser({...editingUser, password: e.target.value})} 
                />
              </div>

              <h4 style={{ margin: '1.5rem 0 1rem', color: 'var(--accent-color)' }}>Account Balances</h4>
              {editingUser.accounts.map((acc, idx) => (
                <div key={acc.accountNumber} className="form-group">
                  <label>{acc.accountNumber} ({acc.accountType})</label>
                  <input type="number" className="glass-input" value={acc.balance} 
                    onChange={e => {
                      const newAccs = [...editingUser.accounts];
                      newAccs[idx].balance = parseFloat(e.target.value);
                      setEditingUser({...editingUser, accounts: newAccs});
                    }} 
                  />
                </div>
              ))}

              <h4 style={{ margin: '1.5rem 0 1rem', color: 'var(--accent-color)', display: 'flex', justifyContent: 'space-between' }}>
                Stock Holdings
                <button className="btn btn-primary" style={{ padding: '0.2rem 0.5rem', fontSize: '0.7rem' }} onClick={addUserAsset}>+ Add Holding</button>
              </h4>
              {editingUser.assets.map((asset, idx) => (
                <div key={idx} style={{ flex: 1, minWidth: '200px', padding: '1rem', background: 'rgba(255,255,255,0.03)', borderRadius: '8px', border: '1px solid rgba(255,255,255,0.05)', position: 'relative' }}>
                  <button 
                    className="btn btn-danger" 
                    style={{ 
                      position: 'absolute', 
                      top: '0.5rem', 
                      right: '0.5rem', 
                      padding: '0.2rem 0.5rem', 
                      fontSize: '0.7rem',
                      borderRadius: '4px'
                    }} 
                    onClick={() => removeUserAsset(idx)}
                    title="Remove Holding"
                  >
                    Remove
                  </button>
                  <div className="form-group">
                    <label>Ticker</label>
                    <select 
                      className="glass-input" 
                      value={asset.ticker} 
                      onChange={e => {
                        const newAssets = [...editingUser.assets];
                        newAssets[idx].ticker = e.target.value;
                        setEditingUser({...editingUser, assets: newAssets});
                      }}
                    >
                      <option value="">Select Ticker</option>
                      {tickers.map(t => (
                        <option key={t.ticker} value={t.ticker}>{t.ticker} ({t.name})</option>
                      ))}
                    </select>
                  </div>
                  <div className="form-group">
                    <label>Quantity</label>
                    <input type="number" className="glass-input" value={asset.quantity} onChange={e => {
                      const newAssets = [...editingUser.assets];
                      newAssets[idx].quantity = parseInt(e.target.value);
                      setEditingUser({...editingUser, assets: newAssets});
                    }} />
                  </div>
                  <div className="form-group">
                    <label>Avg Price</label>
                    <input type="number" className="glass-input" value={asset.avgPrice} onChange={e => {
                      const newAssets = [...editingUser.assets];
                      newAssets[idx].avgPrice = parseFloat(e.target.value);
                      setEditingUser({...editingUser, assets: newAssets});
                    }} />
                  </div>
                </div>
              ))}
            </div>
            <div className="modal-footer">
              <button className="btn" style={{ background: 'transparent', color: 'white' }} onClick={() => setShowUserModal(false)}>Cancel</button>
              <button className="btn btn-primary" onClick={saveUserUpdate} disabled={loading}>
                {loading ? "Saving..." : "Save Everything"}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Full Ticker Edit Modal */}
      {showTickerModal && editingTicker && (
        <div className="modal-overlay">
          <div className="modal-container">
            <div className="modal-header"><h3>Edit Stock: {originalTickerSymbol}</h3></div>
            <div className="modal-body">
              <div className="form-group">
                <label>Ticker Symbol</label>
                <input className="glass-input" value={editingTicker.ticker} onChange={e => setEditingTicker({...editingTicker, ticker: e.target.value.toUpperCase()})} />
              </div>
              <div className="form-group">
                <label>Company Name</label>
                <input className="glass-input" value={editingTicker.name} onChange={e => setEditingTicker({...editingTicker, name: e.target.value})} />
              </div>
              <div className="form-group">
                <label>Sector</label>
                <input className="glass-input" value={editingTicker.sector} onChange={e => setEditingTicker({...editingTicker, sector: e.target.value})} />
              </div>
              <div className="form-group">
                <label>Current Price (KRW)</label>
                <input type="number" className="glass-input" value={editingTicker.price} onChange={e => setEditingTicker({...editingTicker, price: parseInt(e.target.value)})} />
              </div>
            </div>
            <div className="modal-footer">
              <button className="btn" style={{ background: 'transparent', color: 'white' }} onClick={() => setShowTickerModal(false)}>Cancel</button>
              <button className="btn btn-primary" onClick={saveTickerUpdate} disabled={loading}>
                {loading ? "Saving..." : "Save Ticker Info"}
              </button>
            </div>
          </div>
        </div>
      )}
      {/* Add Ticker Modal */}
      {showAddTickerModal && (
        <div className="modal-overlay">
          <div className="modal-container">
            <div className="modal-header"><h3>Add New Ticker</h3></div>
            <div className="modal-body">
              <div className="form-group">
                <label>Ticker Symbol</label>
                <input className="glass-input" placeholder="e.g. AAPL" value={newTicker.ticker} onChange={e => setNewTicker({...newTicker, ticker: e.target.value.toUpperCase()})} />
              </div>
              <div className="form-group">
                <label>Company Name</label>
                <input className="glass-input" placeholder="e.g. Apple Inc." value={newTicker.name} onChange={e => setNewTicker({...newTicker, name: e.target.value})} />
              </div>
              <div className="form-group">
                <label>Sector</label>
                <input className="glass-input" placeholder="e.g. Technology" value={newTicker.sector} onChange={e => setNewTicker({...newTicker, sector: e.target.value})} />
              </div>
              <div className="form-group">
                <label>Initial Price</label>
                <input type="number" className="glass-input" placeholder="0" value={newTicker.initialPrice} onChange={e => setNewTicker({...newTicker, initialPrice: parseInt(e.target.value) || 0})} />
              </div>
            </div>
            <div className="modal-footer">
              <button className="btn" style={{ background: 'transparent', color: 'white' }} onClick={() => setShowAddTickerModal(false)}>Cancel</button>
              <button className="btn btn-primary" onClick={handleAddTicker} disabled={loading}>
                {loading ? "Adding..." : "Add Ticker"}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

export default App;
