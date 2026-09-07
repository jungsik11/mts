# 0. 최신 Git 커밋 Pull (로컬 변경 사항이 있으면 stash 후 pull)
$status = git status --porcelain
if ($status) {
    Write-Host "Saving local changes to stash..." -ForegroundColor Yellow
    git stash
}

Write-Host "Pulling latest commits from Git..." -ForegroundColor Green
git pull

if ($status) {
    Write-Host "Restoring local changes from stash..." -ForegroundColor Yellow
    git stash pop
}

docker login

# 1. 최신 이미지 Pull (oliver173 계정)
docker pull oliver173/mts-account:latest
docker pull oliver173/mts-trading:latest
docker pull oliver173/mts-admin:latest
docker pull oliver173/mts-price-generator:latest
docker pull oliver173/mts-trading-bot:latest
docker pull oliver173/mts-trade-verifier:latest

# 2. 기존 컨테이너 중지 및 이미지 강제 삭제
docker-compose down

# 3. 최신 이미지 다시 Pull 및 서비스 시작
docker-compose pull
docker-compose up -d