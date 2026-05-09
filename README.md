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
    TradingSrv --> RedisPrimary[(Redis Primary - Order/Price)]
    TradingSrv --> RedisSecondary[(Redis Secondary - Candle/Log)]
    
    PriceGen[Price Generator - Python] --> RedisPrimary
    PriceGen --> RedisSecondary
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
4. **사용자 친화적 MTS 앱 (Flutter)**:
   - **홈 화면 최근 활동**: 최근 체결된 내역을 홈 화면에서 즉시 확인.
   - **매수/매도 전용 탭**: 호가창과 함께 매수/매도 각각의 목적에 최적화된 주문 화면 제공.
   - **스마트 주문 보조**: 예수금 기반 '최대 매수 가능' 및 '보유 수량' 클릭 시 자동 수량 입력 기능.
   - **상세 체결 리스트**: 종목별 체결/미체결 수량과 시간을 포함한 상세 내역을 표 형식으로 제공.
5. **어드민 대시보드**:
   - **회원 및 계좌 관리**: 실시간 잔액 조회 및 비밀번호 강제 재설정 기능 제공.
   - **종목 관리**: 신규 종목 등록(종목명, 섹터 포함) 및 기존 정보 수정.
   - **실시간 시세 모니터링**: Redis에 캐시된 종목별 현재가, 기준가, 등락률 실시간 모니터링 및 RAW 데이터 조회.
   - **체결 내역 모니터링**: 시스템 전체에서 발생하는 최신 체결 내역(Trade Logs) 실시간 조회.
   - **시스템 모니터링**: 서버 CPU, RAM 사용량 및 JVM 메트릭 실시간 시각화.
   - **시스템 제어**: 통합 대시보드를 통한 서비스 상태 관리.

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
## 📝 업데이트 내역

- **호가창 시각화 오류 해결 및 실시간성 강화**
  - **Trading Server**: 시뮬레이션 봇(`user_id`)과 서버(`userId`) 간의 필드명 불일치로 인한 주문 거부 문제를 해결하고, 호가 변경 시 Redis를 통해 즉각 브로드캐스트하도록 개선.
  - **Flutter App**: 기존 2초 간격의 HTTP 폴링 방식을 폐기하고, WebSocket을 통한 실시간 호가 업데이트(`order_book_updates`)를 수신하도록 처리하여 매매 반응성 향상.
  - **Stability**: 고빈도 매매 상황에서 호가 데이터 조회 시 발생할 수 있는 동기화 오류(`ConcurrentModificationException`)를 방지하기 위해 스레드 안전성 확보.

### 2026.05.08
- **시스템 모니터링 고도화 및 안정화**
  - **Admin Web**: 시스템 모니터링 탭의 데이터 호출 구조를 독립적으로 분리하여 서버 장애 시에도 화면이 깨지지 않도록 개선 (Fault-tolerance).
  - **Trading Server**: Redis `INFO` 메트릭 추출 시 `java.util.Properties` 처리 로직을 수정하여 정확한 CPU 및 메모리 데이터 수집.
  - **Account Server**: PostgreSQL DB 용량 조회 쿼리를 `pg_database_size`로 최적화하여 보다 신뢰성 있는 지표 제공.
  - **UI/UX**: 차트 데이터 부재 시 크래시 방지를 위한 안전 장치(Safe Navigation) 추가 및 차트 갱신 로직 개선.

- **트레이딩 봇 확장 및 상품 분류 시스템 도입**
  - **Bot Scaling**: 자동 매매 봇을 기존 30개에서 **100개**로 대폭 확장하여 실제 시장과 유사한 고밀도 거래 환경 구축.
  - **Product Classification**: 3자리 숫자형 상품 코드 시스템 도입 (`100`: 주식, `200`: ETF).
  - **MTS UI 개선**: 종목 리스트 및 상세 화면에 상품 타입별(주식/ETF) 컬러 배지 및 라벨을 추가하여 시인성 강화.
  - **Stability Hardening**: Flutter 앱 내 타임스탬프 타입 불일치 해결 및 Null safety 강화로 안정적인 구동 환경 확보.

### 2026.05.09
- **인프라 고도화 및 분산 환경 표준화**
  - **Redis High Availability (HA) & Traffic Split**: 단일 Redis 인스턴스 부하를 해결하기 위해 `Primary`(Trading)와 `Secondary`(Analytic)로 역할을 분리.
    - **Primary (6379)**: 실시간 현재가, 호가창, 주문 체결 로직 전담.
    - **Secondary (6380)**: 대용량 캔들 데이터(1m, 1h, 1d), 봇 하트비트, 시스템 로그 전담.
  - **Trading Server**: Spring Data Redis의 `@Qualifier`를 활용한 다중 Redis 템플릿 주입 구조 설계 및 데이터 성격에 따른 동적 라우팅 구현.
  - **Distributed Infrastructure**: 정적 IP 기반의 분산 환경 구동 표준화 및 마켓 데이터 조회 권한(403 Forbidden 해결)과 CORS 정책 완화(`*`)를 통해 외부 접근성 개선.
  - **Liquidity & Matching Engine**: 봇 매매 로직 고도화(호가 단위 10원 축소, 20% 공격적 시장가 매수 도입)를 통해 매매 체결 빈도를 극대화하고 호가창 데드락 현상 제거.
  - **Bot Scaling**: 시뮬레이션 환경의 현실성을 극대화하기 위해 거래 봇을 **1,000개**(`BOT_0001` ~ `BOT_1000`)로 대폭 증설.
  - **MTS Order Book UI**: 호가창을 '가격 사다리(Price Ladder)' 방식으로 재정렬하여 최우수 매도/매수가가 중앙(Spread)에 위치하도록 시각화 로직 최적화.
  - **Performance & Data Integrity**: `DataInitializer` 벌크 연산 전환으로 초기화 속도 10배 단축 및 실시간 체결 내역의 타임스탬프 파싱 로직 강화.
  - **Infrastructure Hardening**: Docker Compose를 통한 고가용성 인프라 오케스트레이션 및 네트워크 자동 복구 설정 강화.

- **어드민 웹 로컬라이징 및 운영 편의성 강화**
  - **Full Localization**: 대시보드 통계, 모달 UI, 네비게이션 등 어드민 웹 전체 인터페이스를 한국어로 전면 로컬라이징하여 운영 직관성 확보.
  - **Input UX Enhancement**: 사용자 정보 관리 시 휴대폰 번호 및 주민등록번호에 하이픈(`-`) 자동 삽입 로직 구현 및 숫자 외 입력 방지 처리를 통해 데이터 정합성 향상.
  - **Account Management**: 계좌 유형 라벨 개선 (Consignment -> 위탁계좌 등) 및 자산/보유 종목 관리 인터페이스 최적화.

- **백엔드 성능 최적화 및 데이터 정합성 확보**
  - **Redis Query Optimization**: `KEYS` 명령어를 `SCAN` 기반의 반복 조회 방식으로 대체하여 대규모 종목 리스트 조회 시의 서버 부하를 최소화하고 응답 속도 개선.
  - **System Stability**: `RedisConfig` 내 다중 Redis 템플릿(Primary/Secondary) 빈 주입 오류를 해결하여 분산 데이터 환경에서의 연결 안정성 강화.
  - **Data Integrity**: Redis 내 종목 정보(`ticker_info`) 데이터 전수 점검 및 한국어 종목명 매핑 정합성 교정.
  - **Account Opening UX (Flutter)**:
    - **프로세스 재설계**: 계좌 종류 선택 단계를 최상단으로 이동하여 직관적인 UX 제공.
    - **Smart Auto-fill**: 기존 가입 정보를 활용해 이름, 휴대폰, 주민번호를 자동으로 채우는 로직 구현 및 서버 데이터 실시간 동기화(`fetchUserData`) 연동.

- **CI/CD 인프라 구축 및 모니터링 정교화**
  - **GitHub Actions & Docker Hub**: `main`, `dev` 브랜치 푸시 시 Docker 이미지를 자동 빌드하고 Docker Hub로 업로드하는 CI 파이프라인 구축 및 안정화.
  - **Redis Monitoring Fix**: Trading Server의 Redis `INFO` 메트릭 파싱 로직을 개선(String/Properties 동시 대응)하여 어드민 대시보드 내 실시간 지표 표시 오류 해결.
  - **Deployment Script**: 최신 Docker 이미지 풀링 및 컨테이너 롤링 업데이트를 위한 배포 스크립트(`build.sh`) 최적화.

- **MTS UI 개인화 프레임워크 및 설정 영구 저장 구현**
  - **Settings Provider & Persistence**: `shared_preferences`를 도입하여 사용자의 UI 설정(테마, 차트 색상, 글자 크기 등)이 앱 종료 후에도 유지되도록 영구 저장 로직 구현.
  - **Full Theme Support (Light/Dark)**: 단순히 배경색을 바꾸는 것을 넘어, 전 화면의 카드 배경, 텍스트, 네비게이션 바 컬러가 시스템/사용자 테마에 맞춰 최적화되도록 테마 엔진 전면 개편.
  - **Dynamic Chart Colors**: 사용자 취향에 따라 상승/하락 색상 테마(국내식: 빨강/파랑, 해외식: 초록/빨강)를 실시간으로 전환하는 기능 및 전 화면 연동 완료.
  - **Global Font Scaling**: 앱 전체에 적용되는 폰트 크기 조절(작게, 보통, 크게) 기능을 구현하여 시인성 및 사용자 편의성 강화.
  - **UI Density Optimization**: '목록 간편 보기' 모드를 통해 종목 리스트의 밀도를 조절할 수 있는 기능 구현.
  - **Stability Fixes**: `0%` 변동률 시 중립 색상 처리, 누락된 파라미터 및 임포트 오류 등을 해결하여 UI 전반의 완성도 향상.

---
*본 문서는 개발 진행 상황에 따라 지속적으로 업데이트됩니다.*
