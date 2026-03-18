# [루티너리] Routinery Backend Design 과제
## 목차
- [ERD](#erd)
- [테이블 설계](#테이블-설계)
- [설계 설명](#설계-설명)
  - [Todo 배열을 어떤 구조로 저장했나요?](#1-todo-배열을-어떤-구조로-저장했나요)
  - [Log 기록은 어떤 방식으로 저장하도록 설계했나요?](#2-log-기록은-어떤-방식으로-저장하도록-설계했나요)
  - [Log의 Todo 스냅샷(Log.all)은 어떻게 처리했나요?](#3-log의-todo-스냅샷logall은-어떻게-처리했나요)
  - [Friend 관계는 어떤 구조로 저장했나요?](#4-friend-관계는-어떤-구조로-저장했나요)
  - [Firestore 구조와 비교했을 때 SQL 구조의 장단점은 무엇인가요?](#5-firestore-구조와-비교했을-때-sql-구조의-장단점은-무엇인가요)
  - [설계 결정의 이유와 트레이드오프를 설명해주세요.](#6-설계-결정의-이유와-트레이드오프를-설명해주세요)
- [API 설계](#api-설계)
  - [루틴 목록 조회](#루틴-목록-조회)
  - [특정 루틴 실행 기록 조회](#특정-루틴-실행-기록-조회)
  - [친구 목록 조회](#친구-목록-조회)
- [AI 활용 설명](#ai-활용-설명)

---
## ERD
- erdcloud를 사용해서 테이블을 정의하였습니다.
- DB 엔진은 mysql 기준으로 작성되었습니다.
- [루티너리 ERD](https://www.erdcloud.com/d/BLkhEjjYTfWmAkfHT)

## 테이블 설계
- DB 엔진은 mysql 기준으로 작성되었습니다.
- [schema.sql](https://github.com/jeondoh/assignment-routinery/blob/main/schema.sql)

## 설계 설명
### 1. Todo 배열을 어떤 구조로 저장했나요?
- routine과 habit간 1:N 관계로 정규화하여 routine 테이블을 부모로 두고, 각 항목은 habit 테이블의 개별 행으로 저장되도록 설계했습니다.
- habit.routineId를 FK로 두어 하나의 루틴에 여러 개의 habit 데이터가 연결되도록 구성했습니다.
- 장점
  - 특정 루틴에 속한 habit 목록을 안정적 조회 가능
  - 개별 habit 수정, 추가, 삭제 쉬움
  - 항목 단위별 관리 가능(정렬 순서, 활성화 여부 등)
- 단점
  - nosql에선 문서 하나만 읽어오면 내부 todo 배열까지 한번에 가져올 수 있으나, RDB에서는 routine과 habit을 JOIN해서 조회해야 하므로 비교적 느립니다.
  - 데이터가 여러 행으로 분산되기 때문에 nosql처럼 한 번에 덩어리째 갱신하기보단, 트랜잭션 기반으로 관리해야 하는 비용이 있습니다.

```sql
-- 쿼리 예시
SELECT h.* 
FROM habit h
WHERE h.routineId = 33;
```
| 습관ID | 루틴ID | Habit 이름/키 | 아이콘    | 목표시간(초) | 루틴 순서 | 활성화 여부 | ... |
|----|----|------------|--------|---------|-----|--------|-|
| 1    | 33   | 스트레칭       | 🧘     | 300     | 0   | true   | |
| 2    | 33   | 조깅         | 🏃     | 1800    | 1   | true   | |
| 3    | 33   | 잠자기        |  🛏️| 600     | 2   | false  | |

### 2. Log 기록은 어떤 방식으로 저장하도록 설계했나요?
- 4개의 테이블로 분리하여 정규화 하였습니다.
  - `log`: 루틴 실행 단위
  - `log_habit_timer`: 타이머로 완료한 Habit 기록
  - `log_habit_check`: 전체 완료/스킵 기록
  - `log_habit_snapshot`: 기록 당시의 Habit 목록 스냅샷
- routine 테이블과 log 테이블은 1:N 구조로, 루틴 1회 수행시 1개의 row가 생성되도록 설계하였습니다.
- 루틴 하위의 Habit 로그들은 각 테이블에 역할에 따라 분리되어 저장됩니다.
  - 각 로그 테이블들은 logId를 FK로 두어 1:N 관계
- 테이블 단순화도 가능합니다.
  - `log` 테이블 1개와 나머지 분리된 3개의 테이블을 `log_habit_snapshot` 하나로 합치는것도 가능합니다.
  - 이미 Habit 정보가 모두 있기에, 실제 수행 시간(actualDuration), 목표 수행 시간(duration), 스킵 여부/상태(status)를 `log_habit_snapshot`테이블 컬럼으로 추가함으로써 관리가 가능합니다.
  - `log_habit_snapshot`테이블 하나로 합친다면
    - 기존의 `log_habit_timer`(routines/HabitLog[]) 조회 조건
      - status='DONE'이고 actualDurationSec > 0인 행 조회
    - 기존의 `log_habit_check` (check/CheckLog[]) 조회 조건
      - status에 따라 별도 조회 가능 ('done'/'skip'/'undo')

### 3. Log의 Todo 스냅샷(Log.all)은 어떻게 처리했나요?
- 동일 날짜에 여러 row를 insert하는 방식으로 `log_habit_snapshot`테이블을 설계하였습니다.
- 하루 2회 이상 수행 시 재귀 구조로 저장되는 것이 아닌 n회 실행시 n개의 row가 삽입되게 됩니다.
- 루틴 수행시 `log` 테이블에 루틴 정보들이 저장되고, 해당 루틴과 관련한 하위 Habit 데이터가 모두 `log_habit_snapshot`에 삽입되게 됩니다.

### 4. Friend 관계는 어떤 구조로 저장했나요?
- nosql 에서는 회원정보에 대한 데이터가 중복되어 친구 데이터에 모두 들어가 있습니다.
- 이를 RDB에서는 users 테이블과는 1:N 구조로, 관계만 저장하도록 정규화 하였습니다.
- 루티너리에서는 A가 B의 친구코드만 입력하면 A와 B모두 양방향 친구가 되는 시스템으로 확인하였습니다.
  - 두 userId를 정렬하여 저장하였고, 유니크 제약 조건으로 중복 관계를 방지하였습니다.
    - 작은 값의 userId = userLowId
    - 큰 값의 userId = userHighId
  - 하나의 row만 삽입되더라도 양쪽 모두 친구가 되도록 하였습니다.
```sql
-- 유저 A의 userId = 10, 유저 B의 userId = 30 이라고 가정
-- 유저 A의 친구 목록을 모두 가져오는 예시
SELECT u.userId, u.name, u.selfDesc
FROM users u
WHERE u.userId IN (
    SELECT userHighId FROM friend WHERE userLowId = 10
    UNION ALL
    SELECT userLowId FROM friend WHERE userHighId = 10
);
```
| 유저ID | 이름  | 자기소개 | ... |
|------|-----|------|----|
| 3    | Jay | 소개글1 |
| 15   | Kkk | 소개글2 |
| 30   | Min | 소개글3 |

### 5. Firestore 구조와 비교했을 때 SQL 구조의 장단점은 무엇인가요?
- Firestore(NoSQL)은 데이터가 문서 단위로 중첩되어 있어서 조회 성능, 구조 단순성에 강점이 있습니다.
- SQL은 데이터를 테이블로 분리하여 데이터 중복 제거(정규화)와 관계 관리에 강점이 있습니다.
- 장점
  - 데이터 중복 제거로 정합성을 보장합니다.
    - Friend 관계로 예를들면, 친구 관계가 양쪽 문서 각각에 friendIds 배열로 중복 저장해야하며, 양방향 동기화가 필요합니다.
    - SQL에선 FK로 user 존재를 보장하여, 양방향 동기화 및 불일치 자체가 발생이 불가합니다.
  - FK 기반 관계 설정으로 데이터 무결성을 확보합니다.
    - 존재하지 않는 userId로 routine 삽입이 불가능, 잘못된 참조 불가
    - 트랜잭션 단위로 처리하여 부분 기록 방지(rollback)
  - 데이터 개별 단위로 관리하여 부분 수정 및 조회, 삭제에 용이합니다.
  - 복잡한 조건 조회 및 집계 쿼리가 가능합니다.
- 단점
  - 테이블 구조 복잡도에 따라 JOIN이 필요하며 늘어날수록 읽기 속도가 저하됩니다.
  - 삽입시에 여러 테이블에 나누어 저장해야 하므로 쓰기 비용이 있습니다.

### 6. 설계 결정의 이유와 트레이드오프를 설명해주세요.
- 아래 문서에 정리하였습니다.
- [schema_reason.md]()

## API 설계
### 루틴 목록 조회
- GET /users/{userId}/routines

```json
// 요청
// - GET /users/33/routines

// 응답 예시
{
  "statusCode": 200,
  "message": "조회성공",
  "data": {
    "routines": [
      {
        "routineId": 1,
        "title": "미라클 모닝",
        "orders": 0,
        "archive": false,
        "startOption": "time",
        "startTime": 360,
        "period": {
          "type": "weekly",
          "unit": 2,
          "startDate": "2026-03-19",
          "dayOfWeek": [false, true, true, true, true, true, false]
        },
        "habitTotal": 5,
        "habits": [
          {
            "habitId": 1,
            "orders": 0,
            "icon": "🧘",
            "isActive": true,
            "unfinished": true
          },
          {
            "habitId": 2,
            "orders": 1,
            "icon": "🏃",
            "isActive": true,
            "unfinished": true
          }
        ]
      },
      {
        "routineId": 2,
        "title": "차분한 하루 시작",
        "orders": 1,
        "archive": false,
        "startOption": "time",
        "startTime": 420,
        "period": {
          "type": "weekly",
          "unit": 1,
          "startDate": "2026-03-19",
          "dayOfWeek": [false, false, true, false, true, true, false]
        },
        "habitTotal": 8,
        "habits": [
          {
            "habitId": 3,
            "orders": 0,
            "icon": "🧘",
            "isActive": true,
            "unfinished": true
          },
          {
            "habitId": 4,
            "orders": 1,
            "icon": "🏃",
            "isActive": true,
            "unfinished": false
          }
        ]
      }
    ]
  }
}

```


### 특정 루틴 실행 기록 조회
- GET /routines/{routineId}/logs

```json
// 요청
// - GET /routines/3/logs

// 응답 예시
{
  "statusCode": 200,
  "message": "조회성공",
  "data": {
    "routineId": 3,
    "title": "아침 루틴",
    "startTime": "360",
    "unfinished": false,
    "habits": [
      {
        "habitId": 1,
        "order": 0,
        "habitKeys": "스트레칭",
        "duration": 60,
        "status": "done"
      },
      {
        "habitId": 2,
        "order": 1,
        "habitKeys": "조깅",
        "duration": 100,
        "status": "skip"
      },
      ....
    ]
  }
}

```

### 친구 목록 조회
- GET /users/{userId}/friends

```json
// 요청 
// - GET /users/33/friends

// 응답 예시
{
  "statusCode": 200,
  "message": "조회성공",
  "data": {
    "myProfile": {
      "userId": 33,
      "name": "전도현",
      "thumb": "https://..../routinery.png",
      "selfDesc": "자기소개입니다.",
      "lastRoutineStartTime": 1704067200000,
      "lastRoutineEndTime": 1704069000000
    },
    "friends": [
      {
        "userId": 5,
        "name": "Jay",
        "thumb": "https://..../face.png",
        "selfDesc": "안녕하세요.",
        "lastRoutineStartTime": 1704067200000,
        "lastRoutineEndTime": 1704069000000
      },
      {
        "userId": 55,
        "name": "Kkk",
        "thumb": "https://..../dragon.png",
        "selfDesc": "반갑습니다.",
        "lastRoutineStartTime": 1704067200000,
        "lastRoutineEndTime": 1704069000000
      },
      .....
    ]
  }
}

```


## AI 활용 설명
### 어떤 도구를 사용했는지
- Gemini, ChatGPT
### 어떤 방식으로 활용했는지
- DDL 생성 & 누락 컬럼 확인
- 테이블 구조 토론
### AI 결과를 어떻게 검증했는지
- DDL은 테이블 구조, 유니크 제약조건, 연관관계 설정만 주면 자동으로 생성되게 하였고, 실제 데이터베이스에 쿼리를 실행해봄으로서 문법 확인
- 테이블 구조를 과제 요구사항, 실제 앱에서 테이블과 관련된 모든 기능 확인하면서 구조를 먼저 짰고, 제 의견에 대해 더 나은 방안이 있는지 혹은 보충해야할 사항이 있는지 논의하는 정도로 사용하였습니다. 
 