# Git Branching 전략 및 워크플로우

이 문서는 indexpage 프로젝트의 Git 브랜치 전략과 개발 워크플로우를 설명합니다.

## 📋 목차

1. [Branch 구조](#branch-구조)
2. [일상 개발 워크플로우](#일상-개발-워크플로우)
3. [배포 프로세스](#배포-프로세스)
4. [GitHub 설정](#github-설정)
5. [긴급 수정 (Hotfix)](#긴급-수정-hotfix)

---

## Branch 구조

### 주요 브랜치

```
main (프로덕션)
  ↑
  │ PR & Merge
  │
dev (개발)
  ↑
  │ PR & Merge
  │
feature/* (기능 개발)
```

### 브랜치별 역할

| Branch | 용도 | GitHub Actions | 보호 규칙 |
|--------|------|----------------|----------|
| **main** | 프로덕션 배포 | ✅ deploy.yml 실행 | ✅ 권장 |
| **dev** | 개발 통합 | ✅ ci.yml (빌드 테스트만) | ⚠️ 선택 |
| **feature/\*** | 기능 개발 | ✅ ci.yml | ❌ 없음 |

### GitHub Actions 동작

**deploy.yml (프로덕션 배포)**
- `main` 브랜치에 push 시 실행
- Oracle Cloud 서버에 자동 배포
- SSL 인증서 백업/복원
- 서비스 재시작

**ci.yml (빌드 & 테스트)**
- `dev`, `feature/*` 브랜치 push 시 실행
- PR 생성 시 실행
- 이미지 빌드 테스트
- Nginx 설정 검증
- Docker Compose 문법 체크
- **서버 배포하지 않음**

---

## 일상 개발 워크플로우

### 시나리오 1: 일반 개발 작업

**1. dev 브랜치에서 시작**

```bash
# dev 브랜치로 전환
git checkout dev

# 최신 상태 확인
git pull origin dev
```

**2. 로컬에서 개발**

```bash
# 코드 수정
vim main-page/index.html

# 로컬에서 테스트 (VS Code Task 사용)
# Cmd+Shift+P → Run Task → 3️⃣ Start Full Services

# 브라우저에서 확인
open https://localhost/

# 문제없으면 커밋
git add .
git commit -m "Update main page layout"
```

**3. dev에 푸시 (배포 안 됨)**

```bash
# dev 브랜치에 푸시
git push origin dev

# GitHub Actions에서 CI만 실행됨 (빌드 테스트)
# 서버 배포는 실행되지 않음 ✅
```

**4. 충분히 테스트 후 main으로 PR**

```bash
# GitHub에서 Pull Request 생성
# dev → main

# 또는 GitHub CLI 사용
gh pr create --base main --head dev --title "Release v1.2.3" --body "주요 변경사항..."
```

**5. PR Merge → 자동 배포**

```
PR Merge → main 브랜치 업데이트 → deploy.yml 실행 → 서버 배포
```

### 시나리오 2: 새로운 기능 개발 (Feature Branch)

큰 기능을 개발할 때는 별도 브랜치 사용:

```bash
# dev에서 feature 브랜치 생성
git checkout dev
git checkout -b feature/add-calendar-sync

# 기능 개발 및 커밋
git add .
git commit -m "Add calendar sync feature"
git push origin feature/add-calendar-sync

# GitHub에서 PR 생성: feature/add-calendar-sync → dev
gh pr create --base dev --head feature/add-calendar-sync

# PR 머지 후 브랜치 삭제
git branch -d feature/add-calendar-sync
git push origin --delete feature/add-calendar-sync
```

### 시나리오 3: 문서 수정만 할 때

문서만 수정하고 배포하고 싶지 않을 때:

```bash
# dev에서 작업
git checkout dev

# 문서 수정
vim README.md

# 커밋 & 푸시 (dev에만)
git add README.md
git commit -m "Update documentation"
git push origin dev

# 배포 안 됨 ✅
# 나중에 다른 변경사항과 함께 main으로 PR
```

---

## 배포 프로세스

### 정상 배포 (개발 완료 후)

```bash
# 1. dev에서 충분히 개발 및 테스트
git checkout dev
# ... 개발 작업 ...
git push origin dev

# 2. 로컬에서 프로덕션 모드로 최종 테스트
docker compose -f docker-compose.yml pull
docker compose -f docker-compose.yml up -d
# 테스트...
docker compose down

# 3. GitHub에서 PR 생성
gh pr create --base main --head dev \
  --title "Release $(date +%Y-%m-%d)" \
  --body "$(git log main..dev --oneline)"

# 4. PR 검토 및 승인

# 5. Merge → 자동 배포
# GitHub에서 "Merge pull request" 클릭
# 또는 CLI:
gh pr merge --merge
```

### 즉시 배포 (긴급)

dev를 거치지 않고 바로 main에 푸시:

```bash
# main 브랜치 체크아웃
git checkout main
git pull origin main

# 긴급 수정
vim fix-critical-bug.sh
git add .
git commit -m "HOTFIX: Fix critical security issue"

# main에 직접 푸시 → 즉시 배포
git push origin main
```

⚠️ **주의:** 긴급 상황에만 사용! 일반적으로는 dev → PR → main 사용

---

## GitHub 설정

### 1. 브랜치 보호 규칙 설정 (권장)

**main 브랜치 보호:**

GitHub → Settings → Branches → Add rule

```
Branch name pattern: main

✅ Require a pull request before merging
  ✅ Require approvals: 1 (혼자 작업 시 0)

✅ Require status checks to pass before merging
  ✅ Require branches to be up to date before merging
  Status checks: CI - Build and Test

✅ Do not allow bypassing the above settings
```

**설정 후 효과:**
- ❌ main 브랜치에 직접 push 불가
- ✅ PR을 통해서만 main에 반영 가능
- ✅ CI 통과해야만 merge 가능

### 2. 기본 브랜치 변경 (선택사항)

일상적으로 dev에서 작업하므로 기본 브랜치를 dev로 변경:

```
GitHub → Settings → Branches → Default branch → dev
```

**효과:**
- `git clone` 후 자동으로 dev 브랜치 체크아웃
- PR 생성 시 기본 base 브랜치가 dev

### 3. PR 템플릿 설정

`.github/PULL_REQUEST_TEMPLATE.md` 생성:

```markdown
## 변경 내용
<!-- 무엇을 변경했는지 설명 -->

## 테스트
- [ ] 로컬에서 테스트 완료
- [ ] Nginx 설정 검증 완료
- [ ] 엔드포인트 테스트 완료

## 체크리스트
- [ ] CI가 통과했습니다
- [ ] 문서가 업데이트되었습니다 (필요시)
- [ ] SSL 인증서 설정에 영향 없습니다
```

---

## 긴급 수정 (Hotfix)

프로덕션에 치명적인 버그가 발견된 경우:

### 방법 1: main에서 직접 수정 (가장 빠름)

```bash
# main 체크아웃
git checkout main
git pull origin main

# 긴급 수정
vim fix.sh
git add fix.sh
git commit -m "HOTFIX: Critical bug fix"

# 즉시 배포
git push origin main

# dev에도 반영 (중요!)
git checkout dev
git merge main
git push origin dev
```

### 방법 2: hotfix 브랜치 사용

```bash
# main에서 hotfix 브랜치 생성
git checkout main
git checkout -b hotfix/critical-fix

# 수정
vim fix.sh
git add fix.sh
git commit -m "HOTFIX: Critical bug fix"

# main으로 PR (fast-track)
gh pr create --base main --head hotfix/critical-fix --title "HOTFIX: Critical"

# 즉시 승인 & 머지
gh pr merge --merge

# dev에도 머지
git checkout dev
git merge main
git push origin dev

# hotfix 브랜치 삭제
git branch -d hotfix/critical-fix
```

---

## 일반적인 Git 명령어

### 브랜치 전환

```bash
# dev로 전환
git checkout dev

# main으로 전환
git checkout main

# 새 브랜치 생성 및 전환
git checkout -b feature/new-feature
```

### 브랜치 상태 확인

```bash
# 현재 브랜치 확인
git branch

# 원격 브랜치 포함
git branch -a

# 원격과의 차이 확인
git status
```

### 브랜치 동기화

```bash
# 원격 최신 상태 가져오기
git fetch origin

# 현재 브랜치를 원격과 동기화
git pull origin dev

# dev를 main과 동기화
git checkout dev
git merge main
```

### 커밋 히스토리

```bash
# 로그 보기
git log --oneline --graph --all

# dev와 main의 차이
git log main..dev --oneline

# 특정 파일 히스토리
git log -- path/to/file
```

---

## VS Code에서 Git 사용

### 1. 브랜치 전환

```
좌측 하단의 브랜치명 클릭 → 브랜치 선택
```

### 2. 커밋

```
Source Control (Cmd+Shift+G) → 변경사항 선택 → 메시지 입력 → Commit
```

### 3. Push/Pull

```
Source Control → ... → Push/Pull
```

### 4. PR 생성 (GitHub Pull Requests 확장 필요)

```
Cmd+Shift+P → "GitHub Pull Requests: Create Pull Request"
```

---

## 요약: 일상 워크플로우

### 일반 개발 (권장)

```bash
# 1. dev에서 작업
git checkout dev
# 2. 개발 및 커밋
git add . && git commit -m "..."
# 3. dev에 푸시 (배포 안 됨)
git push origin dev
# 4. PR 생성: dev → main
gh pr create --base main --head dev
# 5. PR 머지 → 자동 배포
```

### 빠른 배포 (긴급)

```bash
# main에 직접 푸시
git checkout main
git add . && git commit -m "HOTFIX: ..."
git push origin main  # 즉시 배포
```

### 실험적 기능

```bash
# feature 브랜치 사용
git checkout -b feature/experiment
git push origin feature/experiment
# PR: feature/experiment → dev
```

---

## 추가 리소스

- **[README.md](README.md)** - 프로젝트 개요
- **[GUIDE-DEPLOY-PROCESS.md](GUIDE-DEPLOY-PROCESS.md)** - 배포 프로세스
- **[LOCAL-DEVELOPMENT.md](LOCAL-DEVELOPMENT.md)** - 로컬 개발 가이드
- **Git 공식 문서**: https://git-scm.com/doc
- **GitHub Flow**: https://docs.github.com/en/get-started/quickstart/github-flow

---

**마지막 업데이트:** 2024-11-16
