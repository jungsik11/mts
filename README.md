# Multi-Account MTS (Mobile Trading System) Project

이 프로젝트는 다중 계좌 시스템, 실시간 시세 시뮬레이션, 그리고 자동 트레이딩 봇이 통합된 차세대 MTS 플랫폼입니다.

## 🏗 시스템 아키텍처

시스템은 마이크로서비스 아키텍처(MSA)를 지향하며, Docker Compose를 통해 통합 관리됩니다.

```mermaid
graph TD
    User([사용자/봇]) --> Flutter[Flutter App]
    Admin([관리자]) --> AdminWeb[React Admin Dashboard]
    
    Flutter --> AccountSrv[Account Server - Kotlin]
    AdminWeb --> AccountSrv
    AdminWeb --> TradingSrv[Trading Server - Kotlin]
    
    AccountSrv --> Postgres[(PostgreSQL)]
    TradingSrv --> Redis[(Redis)]
    
    PriceGen[Price Generator - Python] --> Redis
    TradingBot[Trading Bot - Python] --> TradingSrv
```

## 🛠 기술 스택

### Backend
- **Language**: Kotlin 1.9
- **Framework**: Spring Boot 3.2
- **Database**: PostgreSQL (사용자 및 계좌 정보)
- **Cache/Real-time**: Redis (실시간 시세 및 호가창)
- **Security**: Spring Security + JWT

### Frontend
- **App**: Flutter (Mobile MTS UI)
- **Admin**: React + Vite (관리자 대시보드)

### Simulation & Utils
- **Simulation**: Python (100개 종목 시세 생성 및 봇 트레이딩)
- **Infrastructure**: Docker, Docker Compose

## 🚀 주요 기능

1. **다중 계좌 시스템**: 1인당 여러 유형(위탁, CMA, 전문투자 등)의 계좌 보유 가능.
2. **실시간 시세 서비스**: 100개의 국내외 주요 종목에 대한 실시간 가격 변동 시뮬레이션.
3. **전문 트레이딩 봇**: 4종의 고도화된 봇(`BOT_ALGO_ALPHA` 등)이 실제 계좌를 가지고 시장에 참여.
4. **어드민 대시보드**:
   - 실시간 회원 및 계좌 잔액 관리.
   - 종목별 마켓 데이터 모니터링 및 관리.
   - 시스템 상태 통합 제어.

## 📁 디렉토리 구조

- `account_server_kt/`: 사용자 인증 및 계좌 관리 (Kotlin)
- `trading_server_kt/`: 매매 체결 엔진 및 실시간 데이터 (Kotlin)
- `admin_web/`: 관리자용 웹 대시보드 (React)
- `flutter_mts/`: 사용자용 모바일 앱 (Flutter)
- `simulation/`: 시뮬레이션 스크립트 (Python)
  - `price_generator.py`: 100개 종목 시세 생성기
  - `trading_bot.py`: 자동 매매 봇

## ⚙️ 실행 방법

모든 서비스는 Docker를 통해 한 번에 실행할 수 있습니다.

```bash
# 전체 시스템 빌드 및 실행
docker-compose up -d --build

# 특정 서비스 재시작 (예: 어드민 웹)
docker-compose up -d --build admin-web
```

---
*본 문서는 개발 진행 상황에 따라 지속적으로 업데이트됩니다.*
