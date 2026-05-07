import { useState, useEffect } from 'react';
import './index.css';

interface User {
  id: number;
  username: string;
  email: string;
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
  name: string;
  sector: string;
  data?: string;
}

function App() {
  const [activeTab, setActiveTab] = useState<'users' | 'stocks'>('users');
  const [users, setUsers] = useState<User[]>([]);
  const [tickers, setTickers] = useState<Ticker[]>([]);
  
  // Modal States
  const [showUserModal, setShowUserModal] = useState(false);
  const [showTickerModal, setShowTickerModal] = useState(false);
  const [showAddTickerModal, setShowAddTickerModal] = useState(false);
  const [newTicker, setNewTicker] = useState({ ticker: '', initialPrice: 0 });
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
      const data = await res.json();
      setTickers(data);
    } catch (e) { console.error(e); }
  };

  useEffect(() => {
    fetchUsers();
    fetchTickers();
  }, []);

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
        setNewTicker({ ticker: '', initialPrice: 0 });
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
        </div>
      </div>

      <main className="main-content">
        <header style={{ marginBottom: '2rem', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <h2>{activeTab === 'users' ? 'Users & Accounts' : 'Stock Management'}</h2>
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
        ) : (
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
