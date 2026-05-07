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
}

interface Ticker {
  ticker: string;
  data: string;
}

function App() {
  const [activeTab, setActiveTab] = useState<'users' | 'stocks'>('users');
  const [users, setUsers] = useState<User[]>([]);
  const [tickers, setTickers] = useState<Ticker[]>([]);

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
    const init = async () => {
      await Promise.all([fetchUsers(), fetchTickers()]);
    };
    init();
  }, []);

  const handleUpdateBalance = async (accNum: string, currentBalance: number) => {
    const amount = prompt("Enter new balance:", currentBalance.toString());
    if (amount === null) return;
    
    try {
      await fetch('http://localhost:9000/admin/account/update-balance', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: jsonEncode({ accountNumber: accNum, newBalance: parseFloat(amount) })
      });
      fetchUsers();
    } catch (e) { alert("Failed to update balance"); }
  };

  const handleAddTicker = async () => {
    const ticker = prompt("Enter ticker symbol (e.g. BTC):");
    const price = prompt("Enter initial price:");
    if (!ticker || !price) return;

    try {
      await fetch('http://localhost:9001/admin/ticker/add', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ ticker, initialPrice: parseInt(price) })
      });
      fetchTickers();
    } catch (e) { alert("Failed to add ticker"); }
  };

  const handleRemoveTicker = async (ticker: string) => {
    if (!confirm(`Remove ${ticker}?`)) return;
    try {
      await fetch(`http://localhost:9001/admin/ticker/remove?ticker=${ticker}`, { method: 'POST' });
      fetchTickers();
    } catch (e) { alert("Failed to remove ticker"); }
  };

  return (
    <div className="admin-layout">
      <div className="sidebar">
        <h1>MTS ADMIN</h1>
        <div className="nav-links">
          <div 
            className={`nav-item ${activeTab === 'users' ? 'active' : ''}`}
            onClick={() => setActiveTab('users')}
          >
            Users & Accounts
          </div>
          <div 
            className={`nav-item ${activeTab === 'stocks' ? 'active' : ''}`}
            onClick={() => setActiveTab('stocks')}
          >
            Stock Management
          </div>
        </div>
      </div>

      <main className="main-content">
        <header style={{ marginBottom: '2rem' }}>
          <h2>{activeTab === 'users' ? 'Users & Accounts' : 'Stock Management'}</h2>
        </header>

        <div className="stats-grid">
          <div className="stat-card">
            <h3>Total Users</h3>
            <div className="value">{users.length}</div>
          </div>
          <div className="stat-card">
            <h3>Active Tickers</h3>
            <div className="value">{tickers.length}</div>
          </div>
        </div>

        {activeTab === 'users' ? (
          <div className="dashboard-card">
            <table>
              <thead>
                <tr>
                  <th>Username</th>
                  <th>Email</th>
                  <th>Accounts</th>
                </tr>
              </thead>
              <tbody>
                {users.map(user => (
                  <tr key={user.id}>
                    <td>{user.username}</td>
                    <td>{user.email}</td>
                    <td>
                      {user.accounts.map(acc => (
                        <div key={acc.accountNumber} style={{ marginBottom: '0.5rem', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                          <span>{acc.accountNumber} ({acc.accountType}): <strong>₩{acc.balance.toLocaleString()}</strong></span>
                          <button className="btn btn-primary" onClick={() => handleUpdateBalance(acc.accountNumber, acc.balance)}>Edit</button>
                        </div>
                      ))}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <div className="dashboard-card">
            <div style={{ display: 'flex', justifyContent: 'flex-end', marginBottom: '1rem' }}>
              <button className="btn btn-primary" onClick={handleAddTicker}>+ Add Ticker</button>
            </div>
            <table>
              <thead>
                <tr>
                  <th>Ticker</th>
                  <th>Data (Raw)</th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                {tickers.map(t => (
                  <tr key={t.ticker}>
                    <td><strong>{t.ticker}</strong></td>
                    <td style={{ fontSize: '0.8rem', color: 'var(--text-secondary)' }}>{t.data}</td>
                    <td>
                      <button className="btn btn-danger" onClick={() => handleRemoveTicker(t.ticker)}>Remove</button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </main>
    </div>
  );
}

// Helper since JSON.stringify was misused in my thought
const jsonEncode = (obj: any) => JSON.stringify(obj);

export default App;
