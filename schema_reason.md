# 목차
- [User 정규화](#user-정규화)
  - [1. users](#1-users)
  - [2. user_device](#2-user_device)
  - [3. user_metrics](#3-user_metrics)
  - [4. tag & user_tag](#4-tag--user_tag)
  - [5. guide_item & user_guide_item](#5-guide_item--user_guide_item)
- [routine 정규화](#routine-정규화)
  - [1. routine](#1-routine)
  - [2. routine_metric](#2-routine_metric)
  - [3. routine_start_option](#3-routine_start_option)
  - [4. routine_period](#4-routine_period)
  - [5. routine_period_weekly/monthly](#5-routine_period_weekly--monthly)
  - [6. routine_tag](#6-routine_tag)
  - [7. routine_alarm](#7-routine_alarm)
- [Habit 정규화](#habit-정규화)
  - [1. habit](#1-habit)
- [Log 정규화](#log-정규화)
  - [1. log](#1-log)
  - [2. log_habit_snapshot](#2-log_habit_snapshot)
  - [3. log_habit_check](#3-log_habit_check)
  - [4. log_habit_timer](#4-log_habit_timer)
- [Subscription 정규화](#subscription-정규화)
  - [1. subscription](#1-subscription)
  - [2. subscription_product](#2-subscription_product)
  - [3. subscription_history](#3-subscription_history)
- [Friend 정규화](#friend-정규화)
- [테이블 설계중 모호한 부분](#테이블-설계중-모호한-부분)
---

# 스키마 구조
- 모든 테이블은 확장성과 데이터 무결성을 고려하여 정규화를 기반으로 설계했습니다.
- 정규화&책임 분리를 할수록 JOIN이 증가하여 조회 성능에 영향을 줄 수 있습니다.
- 따라서 초기에는 정규화를 유지하되, 인덱스 및 쿼리 최적화 이후에도 성능 문제가 발생할 경우에 한해 반정규화를 고려하는 것이 적절하다고 판단했습니다.

## User 정규화
### 1. users
<img width="50%" src="https://github.com/user-attachments/assets/4693bb08-5ff7-41a9-8f24-580aeb3ca65c" />  

- `age` > `birthYear` 타입 및 데이터 저장 방식
  - 나이는 매년 변하는 값이므로 저장 시 데이터 정합성이 깨질 수 있음
  - 서버에서 출생연도로 변환하여 저장하고 조회 시 나이를 동적으로 계산
- `thumb` 데이터 저장 방식
  - 전체 URL 대신 상대경로를 저장하여 스토리지 변경에 유연하게 대응
    - env 환경변수(base URL) + profile/user22/thumb.png 조합
- `init`, `initTime` > `registeredAt` 가입 시간 한 컬럼으로 축소
  - 동일 의미의 컬럼 분리는 불필요하며, 데이터 불일치 가능성이 존재
  - 하나의 컬럼으로 통합하여 관리 및 정렬/인덱싱을 단순화
- `receiveFriendRoutineStart` 친구 알림 받기 여부를 추가
  - 앱에서 친구 개개인의 알림을 따로 설정하는것이 아닌 전체로 설정하는것으로 확인하여 users 테이블에 있는게 적절하다고 판단했습니다.

### 2. user_device
<img width="50%" src="https://github.com/user-attachments/assets/4d8e24b3-c6ba-4b97-9c11-a7d246aed3a5" />  

- 테이블 분리 이유
  - [FCM 등록 토큰 관리를 위한 권장사항](https://firebase.google.com/docs/cloud-messaging/manage-tokens?utm_source=chatgpt.com&hl=ko) 문서를 참고했을때, FCM 토큰은 디바이스마다 개별 토큰이 저장된다는것을 알 수 있습니다.
  - 하나의 유저가 여러 디바이스를 사용할 수 있어 별도 테이블로 분리
    - user 1명당 `deviceId`와 `firebaseToken`은 여러개로 저장되는 형태

### 3. user_metrics
<img width="50%" src="https://github.com/user-attachments/assets/7ab1efc2-2779-4072-9ceb-88781b550c9d" />  

- 루틴 수행 관련 집계 지표를 저장하는 테이블
- 제가 이해한 최대/역대/누적 수행일은 한 유저의 모든 루틴의 지표의 최대값을 모아둔 컬럼으로 이해했습니다.
- 테이블 분리 이유
  - 조회 시 매번 집계하지 않고, 이벤트 발생 시 갱신하는 반정규화 테이블
  - `users` 테이블과 분리하여 락 경합 감소
  - 집계 데이터의 역할 분리 및 조회 성능 향상

### 4. tag & user_tag
<img width="50%" src="https://github.com/user-attachments/assets/5c30052c-37f9-40bc-8718-940ef30450e5" />  

- `tag`
  - 태그를 공통 엔티티로 분리하여 데이터 정합성을 확보
  - 태그명 변경 시 단일 row 수정으로 전체 반영 가능
- `user_tag`
  - `users`와 `tag` 간 N:M 관계를 해소하기 위한 조인 테이블
  - 중복 데이터 방지 및 유연한 확장 가능

### 5. guide_item & user_guide_item
<img width="50%" src="https://github.com/user-attachments/assets/94bdc8d1-e961-40b6-85d6-930046476838" />  

- 테이블 분리 이유
  - 위(`tag`)와 동일한 의도로 분리하였으며, 가이드/팝업 정의와 사용자 상태를 분리하여 관리
  - 사용자별 상태 추적 및 기능 확장(재노출 등)에 유리한 구조

## routine 정규화
### 1. routine
<img width="50%" src="https://github.com/user-attachments/assets/e6938cd2-0d57-4ed8-a2de-f8a6fb0f7a9c" />  

- 루틴의 기본 메타 정보를 관리하는 테이블
- 루틴을 중심으로 하위 요소(habit, period, startOption, alarm 등)를 분리하여 확장성과 유지보수성을 확보

### 2. routine_metric
<img width="50%" src="https://github.com/user-attachments/assets/659795b6-f67d-4db4-99ba-d3a6b91436f8" />  

- 루틴 단위의 수행 지표를 저장하는 테이블
- 테이블 분리 이유
  - 매 조회 시 계산하지 않고, 수행 시점에 갱신하는 반정규화 구조
  - `routine` 테이블과 분리하여 락 경합 감소
  - 집계 데이터의 역할 분리 및 조회 성능 향상

### 3. routine_start_option
<img width="50%" src="https://github.com/user-attachments/assets/86f0fa9b-b16d-43a8-8620-7f4b8c50dfa2" />  

- 루틴 시작 조건을 관리하는 테이블
- 테이블 분리 이유
  - 시작 조건 타입(`time`, `condition`, `location`)에 따라 컬럼을 분리하여 명확한 구조 유지
  - 향후 옵션 확장 시 routine 테이블 비대화를 방지하고, 책임 분리를 위함

### 4. routine_period
<img width="50%" src="https://github.com/user-attachments/assets/1c90031d-a803-4386-a872-5347955168c1" />  

- 루틴 반복 주기의 기본 정보를 관리하는 테이블
- 테이블 분리 이유
  - 반복 타입별 테이블을 분리하여 다양한 반복 정책 확장 가능
    - 요일별, 월별 반복 등

### 5. routine_period_weekly / monthly
<img width="40%" src="https://github.com/user-attachments/assets/5a25a194-f4f3-4b87-81f5-84a5b60c26d7" />
<img width="40%" src="https://github.com/user-attachments/assets/3946450c-c73c-44ef-8270-082784befbd8" />  

- 반복 조건의 상세를 row 기반으로 저장하는 테이블
- 테이블 분리 이유
  - row로 분리하여 쿼리 및 인덱싱 효율 확보
    - weekly: 요일 단위 반복 (dayOfWeek)
    - monthly: 날짜 단위 반복 (dayOfMonth)

### 6. routine_tag
<img width="50%" src="https://github.com/user-attachments/assets/63f68f28-5c21-4705-8d1a-a2fee966a0c9" />  

- 루틴과 태그 간 관계를 관리하는 테이블
- 테이블 분리 이유
  - `routine`과 `tag` 간 N:M 관계를 해소하기 위한 조인 테이블
  - 중복 데이터 방지 및 유연한 확장 가능

### 7. routine_alarm
<img width="50%" src="https://github.com/user-attachments/assets/acbaf4ad-8750-4641-bb6d-8a2b48d169e7" />  

- 루틴별 알림 관리 테이블
- 테이블 분리 이유
  - 책임 분리, 알림 옵션 추가 대응

## Habit 정규화
### 1. habit
<img width="50%" src="https://github.com/user-attachments/assets/08f2d292-f862-4ab2-9f43-afe93c7bd2b1" />  

- 루틴을 구성하는 하위 수행 단위(todo)를 관리하는 테이블
- NoSQL의 배열 구조(Habit[])를 row 기반으로 분리하여 정렬, 수정, 확장에 유리하도록 설계

## Log 정규화
### 1. log
<img width="50%" src="https://github.com/user-attachments/assets/1626afc0-33fd-4bfb-94d7-0eec4fc7fb50" />  

- 루틴 수행 결과의 기본 정보를 저장하는 테이블
- NoSQL에서 하루 단위 문서 + routineId map 구조를 row 기반으로 정규화
- 하루 여러 번 수행 시 row가 누적되는 구조 (NoSQL의 before 재귀 대체)

### 2. log_habit_snapshot
<img width="50%" src="https://github.com/user-attachments/assets/a51b9269-3e1b-43ea-8d62-c40ddf91f5f8" />  

- 기록 당시의 Habit 상태를 스냅샷으로 저장하는 테이블
- 수행 이후 Habit이 변경되더라도, 당시 상태를 보존하기 위함
- Habit의 모든 속성을 복제하여 저장 (정합성 보존)

### 3. log_habit_check
<img width="50%" src="https://github.com/user-attachments/assets/14ec8429-b68b-4dce-bb5e-619cf8235037" />  

- 전체 완료/스킵 상태를 저장하는 테이블
- NoSQL의 check 배열을 정규화하여 row로 분리

### 4. log_habit_timer
<img width="50%" src="https://github.com/user-attachments/assets/cf6a0dc2-0fa7-4c39-8859-91da20b69be5" />  

- 타이머 기반 수행 기록을 저장하는 테이블
- NoSQL의 routines 배열(HabitLog)을 분리

## Subscription 정규화
### 1. subscription
<img width="50%" src="https://github.com/user-attachments/assets/40ca216e-365b-450b-820c-6971648e1c1e" />  

- 회원의 현재 구독 상태를 관리하는 테이블
- NoSQL에서 `user` 문서에 내장된 구독 정보를 분리하여 명확한 도메인 구조로 설계

### 2. subscription_product
<img width="50%" src="https://github.com/user-attachments/assets/471ad07e-4ec9-4161-8917-e9ff25116836" />  

- 구독 상품 정보를 관리하는 테이블
- 테이블 분리 이유
  - 스토어(App Store/Play Store) 상품 정보를 공통 엔티티로 분리하여 재사용성과 정합성 확보
  - 유료 상품은 BM에 따라 언제든 확장 가능하고 변경 가능해야 한다고 판단했습니다. 

### 3. subscription_history
<img width="50%" src="https://github.com/user-attachments/assets/917e099e-b360-46d7-95c5-258fefd5442a" />  

- 구독 변경 이력을 저장하는 테이블
- 테이블 분리 이유
  - 회원의 구독 상태 변경(갱신, 취소 등)을 모두 기록하여 이력 추적 및 장애 대응 가능
  - 구독 당시의 모든 데이터를 스냅샷으로 저장, 특히 결제(BM)에 관련하여 모든 사항이 추적가능 해야한다고 판단했습니다.

## Friend 정규화
<img width="50%" src="https://github.com/user-attachments/assets/e383a44b-f272-4ee2-9e6d-36940ab6a821" />  

- 사용자 간 친구 관계를 관리하는 테이블
- NoSQL의 양방향 배열(friendIds) 구조를 단일 row 기반 관계로 정규화
- 루티너리의 도메인상으로 한명이 친구 추가시 다른사람의 별도 동의없이 양방향 친구 상태가 됩니다.
- userLowId, userHighId로 하나의 관계를 한 row로 관리
  - 두 userId 중 작은 값을 low, 큰 값을 high로 저장하여 중복 방지
  - (userLowId, userHighId) 유니크 제약으로 데이터 정합성 확보
- 예시
  - 유저 A(id:50)가 B(id:30)의 초대 코드를 입력하여 A와 B모두 친구가 된 상태
  - 반대로 B(id:30)이 A(id:50)에게 친구 요청을 하더라도
  - userLowId = 30, userHighId = 50
  - 1개의 row만 삽입되더라도 둘 사이에 친구라는 관계가 맺어집니다.

# 테이블 설계중 모호한 부분
### 챌린지
- user 스키마의 챌린지 완료 여부(isChallengeCompleted), routine 스키마의 챌린지 목표일(challengeDay)이 정확히 어떤걸 의미하는지 파악하지 못했습니다.
- 각 루틴마다 챌린지 목표일이 있고 그 값이 다르다면 별도로 완료체크를 해야할텐데 user 스키마에 완료여부가 있는 이유를 모르겠습니다. 

### 현재/최대 연속일의 기준?
- 매주 월요일에 하는 루틴을 수요일 단 하루만 완료한 상태에서 연속일 복구권으로 (금,일,화)요일 3일을 복구하면 현재 연속일, 최대 연속일이 1에서 4로 변경됩니다.

| ![이미지1](https://github.com/user-attachments/assets/b9348250-d1e6-4c9e-b48a-4b5aa47d6ca2) | ![이미지2](https://github.com/user-attachments/assets/38fdf954-059b-485b-9e86-a68bcdd890a9) |
| :---: | :---: |

### 알림의 기준? 
- 친구 > 알림 > 내 알림 관리(내가 루틴을 시작하면 친구들이 알림을 받는다)에서 하나를 지정하고 루틴을 시작하면 본인도 알람을 받게됩니다.

| ![이미지1](https://github.com/user-attachments/assets/f32c18a7-65fb-4f11-9dc1-3b1389e40a94) | ![이미지2](https://github.com/user-attachments/assets/4e939d6e-09e8-4f10-a7e6-52d9239a874a) |
| :---: | :---: |


  

  
