import { useState, useEffect, useMemo } from 'react';
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
  email: string | null;
  name: string;
  password?: string;
  rrn?: string;
  phone?: string;
  address?: string;
  job?: string;
  workplace?: string;
  accounts: Array<{
    accountNumber: string;
    accountType: string;
    balance: number;
    isPrimary?: boolean;
    assets: Array<{
      ticker: string;
      quantity: number;
      avgPrice: number;
    }>;
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

const API_HOST = window.location.hostname === 'localhost' ? 'localhost' : (import.meta.env.VITE_API_HOST || '100.91.106.15');
const ACCOUNT_SERVER_URL = import.meta.env.VITE_ACCOUNT_SERVER_URL || `http://${API_HOST}:9000`;
const TRADING_SERVER_URL = import.meta.env.VITE_TRADING_SERVER_URL || `http://${API_HOST}:9001`;

function App() {
  const [activeTab, setActiveTab] = useState<'users' | 'stocks' | 'price-check' | 'system' | 'trades'>('users');
  const [users, setUsers] = useState<User[]>([]);
  const [tickers, setTickers] = useState<Ticker[]>([]);
  const [systemMetrics, setSystemMetrics] = useState<{[key: string]: SystemMetrics}>({});
  const [metricsHistory, setMetricsHistory] = useState<{[key: string]: any[]}>({});
  const [priceHistory, setPriceHistory] = useState<{[key: string]: any[]}>({});
  const [trades, setTrades] = useState<Trade[]>([]);
  const [tradePage, setTradePage] = useState(0); // 거래 내역 페이지 상태 추가
  const [searchTerm, setSearchTerm] = useState('');
  const [tickerSearchTerm, setTickerSearchTerm] = useState(''); // 종목 검색어 추가
  
  // Filtered Users using useMemo for performance
  const filteredUsers = useMemo(() => users.filter((u: User) => {
    const term = searchTerm.toLowerCase();
    return (
      u.name.toLowerCase().includes(term) ||
      u.username.toLowerCase().includes(term) ||
      (u.email && u.email.toLowerCase().includes(term)) ||
      (u.phone && u.phone.replaceAll('-', '').includes(term.replaceAll('-', ''))) ||
      u.accounts.some((acc: any) => acc.accountNumber.replaceAll('-', '').includes(term.replaceAll('-', '')))
    );
  }), [users, searchTerm]);
  
  // Filtered Tickers
  const filteredTickers = useMemo(() => tickers.filter((t: Ticker) => {
    const term = tickerSearchTerm.toLowerCase();
    return (
      t.ticker.toLowerCase().includes(term) ||
      t.name.toLowerCase().includes(term) ||
      t.sector.toLowerCase().includes(term)
    );
  }), [tickers, tickerSearchTerm]);
  
  // Modal States
  const [showUserModal, setShowUserModal] = useState(false);
  const [showCreateUserModal, setShowCreateUserModal] = useState(false);
  const [showTickerModal, setShowTickerModal] = useState(false);
  const [showAddTickerModal, setShowAddTickerModal] = useState(false);
  const [newTicker, setNewTicker] = useState({ ticker: '', initialPrice: 0, name: '', sector: '' });
  const [newUser, setNewUser] = useState({
    username: '',
    password: '',
    name: '',
    email: '',
    rrn: '',
    phone: '',
    address: '',
    job: '',
    workplace: '',
    accountType: 'CONSIGNMENT',
    initialBalance: 0
  });
  const [editingUser, setEditingUser] = useState<User | null>(null);
  const [editingTicker, setEditingTicker] = useState<Ticker | null>(null);
  const [loading, setLoading] = useState(false);
  const [originalTickerSymbol, setOriginalTickerSymbol] = useState<string>("");

  const fetchUsers = async () => {
    try {
      const res = await fetch(`${ACCOUNT_SERVER_URL}/admin/users`);
      const data = await res.json();
      setUsers(data);
    } catch (e) { console.error(e); }
  };

  const fetchTickers = async () => {
    try {
      const res = await fetch(`${TRADING_SERVER_URL}/admin/tickers`);
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
      let dataTrading: any = null;
      let dataAccount: any = null;

      try {
        const resTrading = await fetch(`${TRADING_SERVER_URL}/admin/system/metrics`);
        if (resTrading.ok) dataTrading = await resTrading.json();
      } catch (e) { console.error("Trading metrics failed", e); }
      
      try {
        const resAccount = await fetch(`${ACCOUNT_SERVER_URL}/admin/system/metrics`);
        if (resAccount.ok) dataAccount = await resAccount.json();
      } catch (e) { console.error("Account metrics failed", e); }

      const timestamp = new Date().toLocaleTimeString('ko-KR', { hour12: false, hour: '2-digit', minute: '2-digit', second: '2-digit' });

      const metricsMap: {[key: string]: any} = {};
      if (dataTrading) {
        metricsMap['Trading Server'] = dataTrading;
        if (dataTrading.redisPrimaryMetrics) metricsMap['Redis (Primary)'] = dataTrading.redisPrimaryMetrics;
        if (dataTrading.redisSecondaryMetrics) metricsMap['Redis (Secondary)'] = dataTrading.redisSecondaryMetrics;
      }
      if (dataAccount) {
        metricsMap['Account Server'] = dataAccount;
        if (dataAccount.dbMetrics) metricsMap['PostgreSQL (User DB)'] = dataAccount.dbMetrics;
      }

      setSystemMetrics(metricsMap);

      setMetricsHistory(prev => {
        const newHistory = { ...prev };
        Object.entries(metricsMap).forEach(([name, data]) => {
          const history = newHistory[name] || [];
          newHistory[name] = [...history, {
            time: timestamp,
            cpu: parseFloat(data?.cpuUsage || '0'),
            memoryMB: Math.round((data?.usedMemory || 0) / (1024 * 1024)),
            jvmMB: data?.jvm ? Math.round(data.jvm.used / (1024 * 1024)) : 0,
            memoryTotalMB: Math.round((data?.totalMemory || 0) / (1024 * 1024)),
            jvmTotalMB: data?.jvm ? Math.round(data.jvm.total / (1024 * 1024)) : 0
          }].slice(-30);
        });
        return newHistory;
      });
    } catch (e) { console.error("Global metrics update failed", e); }
  };

  const fetchTrades = async (page: number = 0) => {
    try {
      const res = await fetch(`${ACCOUNT_SERVER_URL}/admin/trades?page=${page}&size=50`);
      const data = await res.json();
      setTrades(data);
    } catch (e) { console.error(e); }
  };

  // Helper formatting functions
  const formatPhone = (value: string) => {
    const nums = value.replace(/[^\d]/g, "");
    if (nums.length <= 3) return nums;
    if (nums.length <= 7) return `${nums.slice(0, 3)}-${nums.slice(3)}`;
    return `${nums.slice(0, 3)}-${nums.slice(3, 7)}-${nums.slice(7, 11)}`;
  };

  const formatRRN = (value: string) => {
    const nums = value.replace(/[^\d]/g, "");
    if (nums.length <= 6) return nums;
    return `${nums.slice(0, 6)}-${nums.slice(6, 13)}`;
  };

  const getAccountTypeLabel = (type: string) => {
    switch (type) {
      case 'CONSIGNMENT': return '위탁계좌';
      case 'CMA': return 'CMA계좌';
      case 'PENSION': return '연금계좌';
      default: return type;
    }
  };

  useEffect(() => {
    fetchUsers();
    fetchTickers();
    fetchSystemMetrics();
    fetchTrades(tradePage);

    const interval = setInterval(() => {
      if (activeTab === 'system') fetchSystemMetrics();
      if (activeTab === 'trades') fetchTrades(tradePage);
      if (activeTab === 'price-check' || activeTab === 'stocks') fetchTickers();
    }, 3000);

    return () => clearInterval(interval);
  }, [activeTab, tradePage]);

  // User Edit Logic
  const handleEditUser = (user: User) => {
    setEditingUser(JSON.parse(JSON.stringify(user))); // Deep clone
    setShowUserModal(true);
  };

  const addAccount = () => {
    if (!editingUser) return;
    const randNum = Math.floor(10000000 + Math.random() * 90000000).toString();
    setEditingUser({
      ...editingUser,
      accounts: [...editingUser.accounts, { 
        accountNumber: `${randNum}-01`, 
        accountType: 'CONSIGNMENT', 
        balance: 0, 
        isPrimary: false,
        assets: [] 
      }]
    });
  };

  const removeAccount = (index: number) => {
    if (!editingUser) return;
    const newAccs = [...editingUser.accounts];
    newAccs.splice(index, 1);
    setEditingUser({ ...editingUser, accounts: newAccs });
  };

  const addAssetToAccount = (accIdx: number) => {
    if (!editingUser) return;
    const newAccs = [...editingUser.accounts];
    newAccs[accIdx].assets = [
      ...newAccs[accIdx].assets, 
      { ticker: tickers[0]?.ticker || '', quantity: 0, avgPrice: 0 }
    ];
    setEditingUser({ ...editingUser, accounts: newAccs });
  };

  const removeAssetFromAccount = (accIdx: number, assetIdx: number) => {
    if (!editingUser) return;
    const newAccs = [...editingUser.accounts];
    newAccs[accIdx].assets.splice(assetIdx, 1);
    setEditingUser({ ...editingUser, accounts: newAccs });
  };

  const saveUserUpdate = async () => {
    if (!editingUser) return;
    setLoading(true);
    try {
      const res = await fetch(`${ACCOUNT_SERVER_URL}/admin/users/${editingUser.id}/full`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          username: editingUser.username,
          email: editingUser.email || null,
          name: editingUser.name,
          password: editingUser.password || undefined,
          rrn: editingUser.rrn || null,
          phone: editingUser.phone || null,
          address: editingUser.address || null,
          job: editingUser.job || null,
          workplace: editingUser.workplace || null,
          accounts: editingUser.accounts.map(a => ({ 
            accountNumber: a.accountNumber, 
            balance: a.balance,
            accountType: a.accountType,
            isPrimary: a.isPrimary,
            assets: a.assets.filter(stock => stock.ticker)
          }))
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
      const response = await fetch(`${ACCOUNT_SERVER_URL}/admin/users/${userId}`, {
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
      const response = await fetch(`${TRADING_SERVER_URL}/admin/ticker/remove?ticker=${ticker}`, {
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

  const handleDeposit = async (accountNumber: string) => {
    const amountStr = window.prompt(`${accountNumber} 계좌에 입금할 금액을 입력하세요:`, "");
    if (!amountStr) return;
    
    // Remove commas if user entered them
    const amount = parseFloat(amountStr.replace(/,/g, ''));
    if (isNaN(amount) || amount <= 0) {
      alert("올바른 금액을 입력해주세요.");
      return;
    }

    try {
      const response = await fetch(`${ACCOUNT_SERVER_URL}/admin/account/deposit`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ accountNumber, amount })
      });
      
      if (response.ok) {
        await response.json();
        alert("입금이 완료되었습니다.");
        await fetchUsers(); // Refresh data
      } else {
        alert("입금 처리에 실패했습니다.");
      }
    } catch (err) {
      console.error("Deposit error:", err);
      alert("네트워크 오류가 발생했습니다.");
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
      const res = await fetch(`${TRADING_SERVER_URL}/admin/tickers/${originalTickerSymbol}/full`, {
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
      const res = await fetch(`${TRADING_SERVER_URL}/admin/ticker/add`, {
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

  const handleCreateUser = async () => {
    if (!newUser.username || !newUser.password || !newUser.name || !newUser.rrn || !newUser.phone) {
      alert("Please fill in all required fields (ID, Password, Name, RRN, Phone)");
      return;
    }
    setLoading(true);
    try {
      const res = await fetch(`${ACCOUNT_SERVER_URL}/admin/users`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(newUser)
      });
      const result = await res.json();
      if (res.ok && result.status === 'Success') {
        await fetchUsers();
        setShowCreateUserModal(false);
        setNewUser({
          username: '',
          password: '',
          name: '',
          email: '',
          rrn: '',
          phone: '',
          address: '',
          job: '',
          workplace: '',
          accountType: 'CONSIGNMENT',
          initialBalance: 0
        });
        alert("회원이 성공적으로 생성되었습니다.");
      } else {
        alert("회원 생성 실패: " + (result.message || "Unknown error"));
      }
    } catch (e) {
      console.error(e);
      alert("회원 생성 실패: 연결 오류");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="admin-layout">
      <div className="sidebar">
        <h1>MTS 관리자</h1>
        <div className="nav-links">
          <div className={`nav-item ${activeTab === 'users' ? 'active' : ''}`} onClick={() => setActiveTab('users')}>사용자 및 계좌 관리</div>
          <div className={`nav-item ${activeTab === 'stocks' ? 'active' : ''}`} onClick={() => setActiveTab('stocks')}>주식 종목 관리</div>
          <div className={`nav-item ${activeTab === 'price-check' ? 'active' : ''}`} onClick={() => setActiveTab('price-check')}>실시간 시세 조회</div>
          <div className={`nav-item ${activeTab === 'system' ? 'active' : ''}`} onClick={() => setActiveTab('system')}>시스템 모니터링</div>
          <div className={`nav-item ${activeTab === 'trades' ? 'active' : ''}`} onClick={() => setActiveTab('trades')}>전체 거래 내역</div>
        </div>
      </div>

      <main className="main-content">
        <header style={{ marginBottom: '2rem', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <h2>{activeTab === 'users' ? '사용자 및 계좌 관리' : activeTab === 'stocks' ? '주식 종목 관리' : activeTab === 'price-check' ? '실시간 시세 조회' : activeTab === 'system' ? '시스템 모니터링' : '전체 거래 내역'}</h2>
          <div style={{ display: 'flex', gap: '1rem' }}>
            {activeTab === 'users' && (
              <button className="btn btn-primary" onClick={() => setShowCreateUserModal(true)}>+ 회원 생성</button>
            )}
            {activeTab === 'stocks' && (
              <button className="btn btn-primary" onClick={() => setShowAddTickerModal(true)}>+ 종목 추가</button>
            )}
          </div>
        </header>

        <div className="stats-grid">
          <div className="stat-card"><h3>총 회원 수</h3><div className="value">{users.length}</div></div>
          <div className="stat-card"><h3>상장 종목 수</h3><div className="value">{tickers.length}</div></div>
        </div>

        {activeTab === 'users' ? (
          <div className="dashboard-card">
            <div style={{ marginBottom: '1.5rem', display: 'flex', gap: '1rem' }}>
              <div className="form-group" style={{ flex: 1, marginBottom: 0 }}>
                <input 
                  type="text" 
                  className="glass-input" 
                  placeholder="이름, ID, 전화번호, 계좌번호로 검색..." 
                  value={searchTerm}
                  onChange={e => setSearchTerm(e.target.value)}
                  style={{ padding: '0.8rem 1.2rem' }}
                />
              </div>
              <div className="stat-card" style={{ padding: '0.5rem 1.5rem', minWidth: 'auto', display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                <span style={{ fontSize: '0.8rem', color: 'var(--text-secondary)' }}>검색 결과:</span>
                <span style={{ fontWeight: 'bold', color: 'var(--accent-color)' }}>
                  {filteredUsers.length}
                </span>
              </div>
            </div>
            <table>
              <thead><tr><th>회원 정보</th><th>계좌 목록</th><th>관리</th></tr></thead>
              <tbody>
                {filteredUsers.map((user: User) => (
                  <tr key={user.id}>
                    <td>
                      <strong style={{ fontSize: '1.1rem', color: 'var(--accent-color)' }}>{user.name}</strong><br/>
                      <strong>ID: {user.username}</strong><br/>
                      <span style={{ fontSize: '0.8rem', color: 'var(--text-secondary)' }}>{user.email || '이메일 없음'} | {user.phone || '전화번호 없음'}</span>
                    </td>
                    <td>
                      {user.accounts.map((acc: any) => (
                        <div key={acc.accountNumber} style={{ fontSize: '0.85rem', marginBottom: '0.5rem', padding: '0.5rem', background: 'rgba(255,255,255,0.03)', borderRadius: '8px' }}>
                          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                            <div>
                              <strong>{acc.accountNumber} ({getAccountTypeLabel(acc.accountType)})</strong>
                              <button 
                                onClick={() => handleDeposit(acc.accountNumber)}
                                style={{ marginLeft: '0.5rem', background: 'var(--success)', border: 'none', color: 'white', padding: '0.1rem 0.4rem', borderRadius: '4px', fontSize: '0.7rem', cursor: 'pointer' }}
                              >
                                입금
                              </button>
                            </div>
                            <strong>₩{acc.balance.toLocaleString()}</strong>
                          </div>
                          <div style={{ display: 'flex', flexWrap: 'wrap', gap: '0.3rem', marginTop: '0.3rem' }}>
                            {acc.assets.map((asset: any) => (
                              <span key={asset.ticker} style={{ background: 'rgba(56, 189, 248, 0.1)', color: 'var(--accent-color)', padding: '0.1rem 0.4rem', borderRadius: '0.3rem', fontSize: '0.75rem' }}>
                                {asset.ticker}: {asset.quantity}주
                              </span>
                            ))}
                          </div>
                        </div>
                      ))}
                    </td>
                    <td style={{ display: 'flex', gap: '0.5rem' }}>
                      <button className="btn btn-primary" onClick={() => handleEditUser(user)}>회원 관리</button>
                      <button className="btn btn-danger" onClick={() => handleDeleteUser(user.id)}>삭제</button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : activeTab === 'stocks' ? (
          <div className="dashboard-card">
            <div style={{ marginBottom: '1.5rem', display: 'flex', gap: '1rem' }}>
              <div className="form-group" style={{ flex: 1, marginBottom: 0 }}>
                <input 
                  type="text" 
                  className="glass-input" 
                  placeholder="티커, 종목명, 섹터로 검색..." 
                  value={tickerSearchTerm}
                  onChange={e => setTickerSearchTerm(e.target.value)}
                  style={{ padding: '0.8rem 1.2rem' }}
                />
              </div>
              <div className="stat-card" style={{ padding: '0.5rem 1.5rem', minWidth: 'auto', display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                <span style={{ fontSize: '0.8rem', color: 'var(--text-secondary)' }}>검색 결과:</span>
                <span style={{ fontWeight: 'bold', color: 'var(--accent-color)' }}>
                  {filteredTickers.length}
                </span>
              </div>
            </div>
            <table>
              <thead><tr><th>티커</th><th>종목명</th><th>섹터</th><th>현재가</th><th>관리</th></tr></thead>
              <tbody>
                {filteredTickers.map((t: Ticker) => (
                  <tr key={t.ticker}>
                    <td><strong>{t.ticker}</strong></td>
                    <td>{t.name}</td>
                    <td><span style={{ fontSize: '0.85rem', opacity: 0.8 }}>{t.sector}</span></td>
                    <td><strong>₩{Number(t.price).toLocaleString()}</strong></td>
                    <td style={{ display: 'flex', gap: '0.5rem' }}>
                      <button className="btn btn-primary" onClick={() => handleEditTicker(t)}>정보 수정</button>
                      <button className="btn btn-danger" onClick={() => handleDeleteTicker(t.ticker)}>삭제</button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : activeTab === 'price-check' ? (
          <div className="dashboard-card">
            <div style={{ marginBottom: '1.5rem', display: 'flex', gap: '1rem' }}>
              <div className="form-group" style={{ flex: 1, marginBottom: 0 }}>
                <input 
                  type="text" 
                  className="glass-input" 
                  placeholder="Search ticker to check price..." 
                  value={tickerSearchTerm}
                  onChange={e => setTickerSearchTerm(e.target.value)}
                  style={{ padding: '0.8rem 1.2rem' }}
                />
              </div>
            </div>
            <div style={{ marginBottom: '1rem', color: 'var(--text-secondary)', fontSize: '0.9rem' }}>
              Real-time price data cached in Redis. Reference price is used to calculate daily fluctuations.
            </div>
            <table>
              <thead><tr><th>Ticker</th><th>Name</th><th>Current Price</th><th>Trend (Last 30)</th><th>Base Price</th><th>Change</th><th>Raw Redis Data</th></tr></thead>
              <tbody>
                {filteredTickers.map((t: Ticker) => {
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
                          <h3>CPU 사용량 (%)</h3>
                          <strong style={{ color: 'var(--accent-color)' }}>{metrics.cpuUsage}%</strong>
                        </div>
                        <div style={{ height: '280px', width: '100%' }}>
                          <ResponsiveContainer width="100%" height="100%">
                            <LineChart data={metricsHistory[serviceName]} margin={{ top: 10, right: 30, left: 0, bottom: 20 }}>
                              <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.1)" />
                              <XAxis dataKey="time" stroke="#94a3b8" fontSize={11} tickMargin={10} />
                              <YAxis domain={[0, 100]} stroke="#94a3b8" fontSize={11} label={{ value: '%', angle: 0, position: 'insideTopLeft', offset: -10, fill: '#94a3b8' }} />
                              <Tooltip contentStyle={{ background: '#0f172a', border: '1px solid var(--accent-color)' }} />
                              <Line type="monotone" dataKey="cpu" stroke="var(--accent-color)" strokeWidth={2} name="CPU %" />
                            </LineChart>
                          </ResponsiveContainer>
                        </div>
                        <div style={{ fontSize: '0.8rem', color: 'var(--text-secondary)', marginTop: '1rem' }}>
                          프로세서 수: {metrics.availableProcessors} | 시스템 로드 평균: {metrics.systemLoadAverage}
                        </div>
                      </div>

                      {/* Memory Chart */}
                      <div className="dashboard-card" style={{ height: '400px' }}>
                        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1.5rem' }}>
                          <h3>메모리 사용량 (MB)</h3>
                          <div style={{ fontSize: '0.8rem', display: 'flex', gap: '1rem' }}>
                            <span style={{ color: 'var(--success)' }}>컨테이너: {Math.round(metrics.usedMemory/(1024*1024))}MB</span>
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
                              <Line type="monotone" dataKey="memoryMB" stroke="var(--success)" strokeWidth={2} name="컨테이너 MB" />
                              <Line type="monotone" dataKey="jvmMB" stroke="#f59e0b" strokeWidth={2} name="JVM MB" />
                            </LineChart>
                          </ResponsiveContainer>
                        </div>
                        <div style={{ fontSize: '0.8rem', color: 'var(--text-secondary)', marginTop: '1rem', display: 'flex', justifyContent: 'space-between' }}>
                          <span>총 메모리: {Math.round(metrics.totalMemory/(1024*1024))}MB</span>
                          <span>JVM 전체: {Math.round(metrics.jvm.total/(1024*1024))}MB</span>
                        </div>
                      </div>
                    </div>

                    {metrics.health && (
                      <div className="dashboard-card" style={{ gridColumn: 'span 2' }}>
                        <h3>서비스 연결 상태</h3>
                        <div style={{ display: 'flex', gap: '2rem', marginTop: '1rem' }}>
                          {Object.entries(metrics.health).map(([service, status]) => (
                            <div key={service} style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', background: 'rgba(255,255,255,0.05)', padding: '0.5rem 1rem', borderRadius: '8px' }}>
                              <div style={{ width: '10px', height: '10px', borderRadius: '50%', background: status === 'UP' ? 'var(--success)' : 'var(--danger)' }}></div>
                              <span>{service === 'postgres' ? '데이터베이스' : service === 'redis' ? '레디스' : service === 'accountServer' ? '계좌 서버' : service === 'tradingServer' ? '거래 서버' : service}:</span>
                              <strong style={{ color: status === 'UP' ? 'var(--success)' : 'var(--danger)' }}>{status === 'UP' ? '정상' : '중단'}</strong>
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
              시스템 전체에서 발생한 최근 50건의 거래 내역을 표시합니다.
            </div>
            <table>
              <thead><tr><th>번호</th><th>티커</th><th>채결가</th><th>수량</th><th>매수자 ID</th><th>매도자 ID</th><th>채결시간</th></tr></thead>
              <tbody>
                {trades.map(trade => (
                  <tr key={trade.id}>
                    <td>{trade.id}</td>
                    <td><strong>{trade.ticker}</strong></td>
                    <td>₩{trade.price.toLocaleString()}</td>
                    <td>{trade.quantity}</td>
                    <td>{trade.buyerId}</td>
                    <td>{trade.sellerId}</td>
                    <td style={{ fontSize: '0.85rem', opacity: 0.8 }}>
                      {new Date(trade.timestamp.endsWith('Z') || trade.timestamp.includes('+') ? trade.timestamp : trade.timestamp + 'Z').toLocaleString('ko-KR', { timeZone: 'Asia/Seoul' })}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
            
            {/* Pagination Controls */}
            <div style={{ marginTop: '1.5rem', display: 'flex', justifyContent: 'center', alignItems: 'center', gap: '1rem' }}>
              <button 
                className="btn" 
                style={{ background: 'rgba(255,255,255,0.05)', color: tradePage === 0 ? '#4b5563' : 'white' }}
                disabled={tradePage === 0}
                onClick={() => setTradePage(prev => Math.max(0, prev - 1))}
              >
                ← 이전 페이지
              </button>
              <span style={{ color: 'var(--text-secondary)' }}>페이지 {tradePage + 1}</span>
              <button 
                className="btn" 
                style={{ background: 'rgba(255,255,255,0.05)', color: trades.length < 50 ? '#4b5563' : 'white' }}
                disabled={trades.length < 50}
                onClick={() => setTradePage(prev => prev + 1)}
              >
                다음 페이지 →
              </button>
            </div>
          </div>
        )}
      </main>

      {/* Version Footer for verification */}
      <div style={{ position: 'fixed', bottom: '10px', right: '10px', fontSize: '0.7rem', opacity: 0.3, color: 'white' }}>
        Version v1.1 (KST/Deposit Fix)
      </div>

      {/* Full User Edit Modal */}
      {showUserModal && editingUser && (
        <div className="modal-overlay">
          <div className="modal-container" style={{ maxWidth: '600px' }}>
            <div className="modal-header"><h3>회원 관리: {editingUser.username}</h3></div>
            <div className="modal-body" style={{ maxHeight: '70vh', overflowY: 'auto', paddingRight: '1rem' }}>
              <h4 style={{ marginBottom: '1rem', color: 'var(--accent-color)' }}>기본 정보</h4>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem' }}>
                <div className="form-group">
                  <label>이름</label>
                  <input 
                    className="glass-input" 
                    placeholder="이름 입력"
                    value={editingUser.name} 
                    onChange={e => setEditingUser({...editingUser, name: e.target.value})} 
                  />
                </div>
                <div className="form-group">
                  <label>사용자 ID</label>
                  <input 
                    className="glass-input" 
                    placeholder="ID 입력"
                    value={editingUser.username} 
                    onChange={e => setEditingUser({...editingUser, username: e.target.value})} 
                  />
                </div>
                <div className="form-group">
                  <label>이메일 주소</label>
                  <input 
                    className="glass-input" 
                    placeholder="example@mail.com"
                    value={editingUser.email || ''} 
                    onChange={e => setEditingUser({...editingUser, email: e.target.value || null})} 
                  />
                </div>
                <div className="form-group">
                  <label>전화번호</label>
                  <input 
                    className="glass-input" 
                    placeholder="010-0000-0000"
                    value={editingUser.phone || ''} 
                    onChange={e => setEditingUser({...editingUser, phone: formatPhone(e.target.value)})} 
                  />
                </div>
                <div className="form-group">
                  <label>주민등록번호</label>
                  <input 
                    className="glass-input" 
                    placeholder="000000-0000000"
                    value={editingUser.rrn || ''} 
                    onChange={e => setEditingUser({...editingUser, rrn: formatRRN(e.target.value)})} 
                  />
                </div>
              </div>

              <h4 style={{ margin: '1.5rem 0 1rem', color: 'var(--accent-color)' }}>추가 정보</h4>
              <div className="form-group">
                <label>주소</label>
                <input className="glass-input" value={editingUser.address || ''} onChange={e => setEditingUser({...editingUser, address: e.target.value})} />
              </div>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem', marginTop: '1rem' }}>
                <div className="form-group">
                  <label>직업</label>
                  <input className="glass-input" value={editingUser.job || ''} onChange={e => setEditingUser({...editingUser, job: e.target.value})} />
                </div>
                <div className="form-group">
                  <label>직장</label>
                  <input className="glass-input" value={editingUser.workplace || ''} onChange={e => setEditingUser({...editingUser, workplace: e.target.value})} />
                </div>
              </div>

              <div className="form-group" style={{ marginTop: '1rem' }}>
                <label>새 비밀번호 (변경 시에만 입력)</label>
                <input 
                  type="password" 
                  className="glass-input" 
                  placeholder="새 비밀번호 입력"
                  value={editingUser.password || ''} 
                  onChange={e => setEditingUser({...editingUser, password: e.target.value})} 
                />
              </div>

              <h4 style={{ margin: '1.5rem 0 1rem', color: 'var(--accent-color)', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                계좌 및 보유 자산
                <button className="btn btn-primary" style={{ padding: '0.3rem 0.6rem', fontSize: '0.75rem' }} onClick={addAccount}>+ 계좌 추가</button>
              </h4>
              
              <div style={{ display: 'flex', flexDirection: 'column', gap: '1.5rem' }}>
                {editingUser.accounts.map((acc, accIdx) => (
                  <div key={accIdx} style={{ padding: '1.2rem', background: 'rgba(255,255,255,0.03)', borderRadius: '12px', border: '1px solid rgba(255,255,255,0.1)', position: 'relative' }}>
                    <button 
                      className="btn btn-danger" 
                      style={{ position: 'absolute', top: '0.8rem', right: '0.8rem', padding: '0.2rem 0.5rem', fontSize: '0.7rem' }}
                      onClick={() => removeAccount(accIdx)}
                    >
                      계좌 삭제
                    </button>

                    <div style={{ display: 'grid', gridTemplateColumns: '1.5fr 1fr 1fr 0.5fr', gap: '1rem', marginBottom: '1rem', alignItems: 'flex-end' }}>
                      <div className="form-group">
                        <label>계좌 번호</label>
                        <input className="glass-input" value={acc.accountNumber} onChange={e => {
                          const newAccs = [...editingUser.accounts];
                          newAccs[accIdx].accountNumber = e.target.value;
                          setEditingUser({...editingUser, accounts: newAccs});
                        }} />
                      </div>
                      <div className="form-group">
                        <label>유형</label>
                        <select className="glass-input" value={acc.accountType} onChange={e => {
                          const newAccs = [...editingUser.accounts];
                          newAccs[accIdx].accountType = e.target.value;
                          setEditingUser({...editingUser, accounts: newAccs});
                        }}>
                          <option value="CONSIGNMENT">위탁계좌</option>
                          <option value="CMA">CMA계좌</option>
                          <option value="PENSION">연금계좌</option>
                        </select>
                      </div>
                      <div className="form-group">
                        <label>잔고 (₩)</label>
                        <input type="number" className="glass-input" value={acc.balance} onChange={e => {
                          const newAccs = [...editingUser.accounts];
                          newAccs[accIdx].balance = parseFloat(e.target.value);
                          setEditingUser({...editingUser, accounts: newAccs});
                        }} />
                      </div>
                      <div className="form-group">
                        <button 
                          className="btn" 
                          style={{ background: 'var(--success)', color: 'white', width: '100%', padding: '0.8rem 0' }}
                          onClick={() => handleDeposit(acc.accountNumber)}
                        >
                          +
                        </button>
                      </div>
                    </div>

                    <div style={{ paddingLeft: '1rem', borderLeft: '2px solid rgba(56, 189, 248, 0.3)' }}>
                      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '0.8rem' }}>
                        <h5 style={{ margin: 0, fontSize: '0.9rem', color: 'var(--text-secondary)' }}>계좌 보유 자산</h5>
                        <button className="btn btn-primary" style={{ padding: '0.2rem 0.5rem', fontSize: '0.65rem' }} onClick={() => addAssetToAccount(accIdx)}>+ 자산 추가</button>
                      </div>

                      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(200px, 1fr))', gap: '0.8rem' }}>
                        {acc.assets.map((asset, assetIdx) => (
                          <div key={assetIdx} style={{ padding: '0.8rem', background: 'rgba(255,255,255,0.05)', borderRadius: '8px', position: 'relative' }}>
                            <span 
                              style={{ position: 'absolute', top: '0.3rem', right: '0.3rem', cursor: 'pointer', color: 'var(--error-color)', fontSize: '1.2rem', lineHeight: 1 }}
                              onClick={() => removeAssetFromAccount(accIdx, assetIdx)}
                            >×</span>
                            
                            <div className="form-group" style={{ marginBottom: '0.5rem' }}>
                              <select className="glass-input" style={{ fontSize: '0.8rem', padding: '0.3rem' }} value={asset.ticker} onChange={e => {
                                const newAccs = [...editingUser.accounts];
                                newAccs[accIdx].assets[assetIdx].ticker = e.target.value;
                                setEditingUser({...editingUser, accounts: newAccs});
                              }}>
                                <option value="">종목 선택</option>
                                {tickers.map(t => <option key={t.ticker} value={t.ticker}>{t.ticker} ({t.name})</option>)}
                              </select>
                            </div>
                            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1.2fr', gap: '0.5rem' }}>
                              <input type="number" className="glass-input" style={{ fontSize: '0.8rem', padding: '0.3rem' }} placeholder="수량" value={asset.quantity} onChange={e => {
                                const newAccs = [...editingUser.accounts];
                                newAccs[accIdx].assets[assetIdx].quantity = parseInt(e.target.value);
                                setEditingUser({...editingUser, accounts: newAccs});
                              }} />
                              <input type="number" className="glass-input" style={{ fontSize: '0.8rem', padding: '0.3rem' }} placeholder="평단가" value={asset.avgPrice} onChange={e => {
                                const newAccs = [...editingUser.accounts];
                                newAccs[accIdx].assets[assetIdx].avgPrice = parseFloat(e.target.value);
                                setEditingUser({...editingUser, accounts: newAccs});
                              }} />
                            </div>
                          </div>
                        ))}
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            </div>
            <div className="modal-footer">
              <button className="btn" style={{ background: 'transparent', color: 'white' }} onClick={() => setShowUserModal(false)}>취소</button>
              <button className="btn btn-primary" onClick={saveUserUpdate} disabled={loading}>
                {loading ? "저장 중..." : "전체 저장"}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Full Ticker Edit Modal */}
      {showTickerModal && editingTicker && (
        <div className="modal-overlay">
          <div className="modal-container">
            <div className="modal-header"><h3>종목 정보 수정: {originalTickerSymbol}</h3></div>
            <div className="modal-body">
              <div className="form-group">
                <label>티커 심볼</label>
                <input className="glass-input" value={editingTicker.ticker} onChange={e => setEditingTicker({...editingTicker, ticker: e.target.value.toUpperCase()})} />
              </div>
              <div className="form-group">
                <label>종목명</label>
                <input className="glass-input" value={editingTicker.name} onChange={e => setEditingTicker({...editingTicker, name: e.target.value})} />
              </div>
              <div className="form-group">
                <label>섹터</label>
                <input className="glass-input" value={editingTicker.sector} onChange={e => setEditingTicker({...editingTicker, sector: e.target.value})} />
              </div>
              <div className="form-group">
                <label>현재가 (₩)</label>
                <input type="number" className="glass-input" value={editingTicker.price} onChange={e => setEditingTicker({...editingTicker, price: parseInt(e.target.value)})} />
              </div>
            </div>
            <div className="modal-footer">
              <button className="btn" style={{ background: 'transparent', color: 'white' }} onClick={() => setShowTickerModal(false)}>취소</button>
              <button className="btn btn-primary" onClick={saveTickerUpdate} disabled={loading}>
                {loading ? "저장 중..." : "종목 정보 저장"}
              </button>
            </div>
          </div>
        </div>
      )}
      {/* Add Ticker Modal */}
      {showAddTickerModal && (
        <div className="modal-overlay">
          <div className="modal-container">
            <div className="modal-header"><h3>새 종목 추가</h3></div>
            <div className="modal-body">
              <div className="form-group">
                <label>티커 심볼</label>
                <input className="glass-input" placeholder="예: AAPL" value={newTicker.ticker} onChange={e => setNewTicker({...newTicker, ticker: e.target.value.toUpperCase()})} />
              </div>
              <div className="form-group">
                <label>종목명</label>
                <input className="glass-input" placeholder="예: 애플" value={newTicker.name} onChange={e => setNewTicker({...newTicker, name: e.target.value})} />
              </div>
              <div className="form-group">
                <label>섹터</label>
                <input className="glass-input" placeholder="예: 기술주" value={newTicker.sector} onChange={e => setNewTicker({...newTicker, sector: e.target.value})} />
              </div>
              <div className="form-group">
                <label>시작 가격</label>
                <input type="number" className="glass-input" placeholder="0" value={newTicker.initialPrice} onChange={e => setNewTicker({...newTicker, initialPrice: parseInt(e.target.value) || 0})} />
              </div>
            </div>
            <div className="modal-footer">
              <button className="btn" style={{ background: 'transparent', color: 'white' }} onClick={() => setShowAddTickerModal(false)}>취소</button>
              <button className="btn btn-primary" onClick={handleAddTicker} disabled={loading}>
                {loading ? "추가 중..." : "종목 추가"}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Create User Modal */}
      {showCreateUserModal && (
        <div className="modal-overlay">
          <div className="modal-container" style={{ maxWidth: '600px' }}>
            <div className="modal-header"><h3>새 회원 생성</h3></div>
            <div className="modal-body" style={{ maxHeight: '70vh', overflowY: 'auto', paddingRight: '1rem' }}>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem' }}>
                <div className="form-group">
                  <label>사용자 ID *</label>
                  <input className="glass-input" placeholder="ID" value={newUser.username} onChange={e => setNewUser({...newUser, username: e.target.value})} />
                </div>
                <div className="form-group">
                  <label>비밀번호 *</label>
                  <input type="password" title="password" className="glass-input" placeholder="비밀번호" value={newUser.password} onChange={e => setNewUser({...newUser, password: e.target.value})} />
                </div>
                <div className="form-group">
                  <label>이름 *</label>
                  <input className="glass-input" placeholder="이름" value={newUser.name} onChange={e => setNewUser({...newUser, name: e.target.value})} />
                </div>
                <div className="form-group">
                  <label>이메일</label>
                  <input className="glass-input" placeholder="example@email.com" value={newUser.email} onChange={e => setNewUser({...newUser, email: e.target.value})} />
                </div>
                <div className="form-group">
                  <label>주민등록번호 *</label>
                  <input className="glass-input" placeholder="000000-0000000" value={newUser.rrn} onChange={e => setNewUser({...newUser, rrn: formatRRN(e.target.value)})} />
                </div>
                <div className="form-group">
                  <label>전화번호 *</label>
                  <input className="glass-input" placeholder="010-0000-0000" value={newUser.phone} onChange={e => setNewUser({...newUser, phone: formatPhone(e.target.value)})} />
                </div>
              </div>
              <div className="form-group">
                <label>주소</label>
                <input className="glass-input" placeholder="주소" value={newUser.address} onChange={e => setNewUser({...newUser, address: e.target.value})} />
              </div>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem' }}>
                <div className="form-group">
                  <label>직업</label>
                  <input className="glass-input" placeholder="직업" value={newUser.job} onChange={e => setNewUser({...newUser, job: e.target.value})} />
                </div>
                <div className="form-group">
                  <label>직장</label>
                  <input className="glass-input" placeholder="직장" value={newUser.workplace} onChange={e => setNewUser({...newUser, workplace: e.target.value})} />
                </div>
              </div>
              <hr style={{ margin: '1.5rem 0', opacity: 0.1 }} />
              <h4 style={{ marginBottom: '1rem', color: 'var(--accent-color)' }}>초기 계좌 설정</h4>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem' }}>
                <div className="form-group">
                  <label>계좌 종류</label>
                  <select className="glass-input" value={newUser.accountType} onChange={e => setNewUser({...newUser, accountType: e.target.value})}>
                    <option value="CONSIGNMENT">위탁계좌</option>
                    <option value="CMA">CMA계좌</option>
                    <option value="PENSION">연금계좌</option>
                  </select>
                </div>
                <div className="form-group">
                  <label>초기 예수금 (₩)</label>
                  <input type="number" className="glass-input" placeholder="0" value={newUser.initialBalance} onChange={e => setNewUser({...newUser, initialBalance: parseInt(e.target.value) || 0})} />
                </div>
              </div>
            </div>
            <div className="modal-footer">
              <button className="btn" style={{ background: 'transparent', color: 'white' }} onClick={() => setShowCreateUserModal(false)}>취소</button>
              <button className="btn btn-primary" onClick={handleCreateUser} disabled={loading}>
                {loading ? "생성 중..." : "회원 생성"}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

export default App;
