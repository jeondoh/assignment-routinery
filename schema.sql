-- 스키마 생성
CREATE DATABASE IF NOT EXISTS routinery
DEFAULT CHARACTER SET utf8mb4
DEFAULT COLLATE utf8mb4_unicode_ci;

USE routinery;

-- 회원
CREATE TABLE users (
    userId BIGINT NOT NULL AUTO_INCREMENT COMMENT '회원ID',
    email VARCHAR(50) NOT NULL COMMENT '이메일',
    birthYear SMALLINT NULL COMMENT '나이',
    gender VARCHAR(6) NULL COMMENT '성별',
    thumb VARCHAR(1024) NULL COMMENT '프로필 이미지',
    selfDesc VARCHAR(500) NULL COMMENT '자기소개',
    publicId VARCHAR(10) NOT NULL COMMENT '친구기능 공개ID',
    country CHAR(2) NOT NULL COMMENT '국가코드',
    timezone VARCHAR(50) NOT NULL COMMENT '시간대',
    dayEndingTime INT NULL COMMENT '하루 종료 시각(분 단위)',
    streakSaver INT NULL COMMENT '연속일 복구권 보유수',
    registeredAt DATETIME NOT NULL COMMENT '최초 가입 타임스탬프',
    receiveFriendRoutineStart BOOLEAN NOT NULL COMMENT '친구 알림 받기 여부',
    PRIMARY KEY (userId),
    UNIQUE KEY uk_users_email (email),
    UNIQUE KEY uk_users_public_id (publicId)
);

-- 태그
CREATE TABLE tag (
    tagId BIGINT NOT NULL AUTO_INCREMENT COMMENT '태그ID',
    name VARCHAR(100) NOT NULL COMMENT '태그명',
    isActive BOOLEAN NOT NULL DEFAULT TRUE COMMENT '활성화여부',
    PRIMARY KEY (tagId)
);

-- 팝업/가이드
CREATE TABLE guide_item (
    guideId BIGINT NOT NULL AUTO_INCREMENT COMMENT '가이드ID',
    name VARCHAR(100) NOT NULL COMMENT '가이드명',
    itemType VARCHAR(30) NOT NULL COMMENT '아이템타입(팝업/가이드)',
    isActive BOOLEAN NOT NULL COMMENT '활성화여부',
    PRIMARY KEY (guideId)
);

-- 회원 기기
-- users 테이블과 1:N 관계
CREATE TABLE user_device (
    userDeviceId BIGINT NOT NULL AUTO_INCREMENT COMMENT '회원기기ID',
    userId BIGINT NOT NULL COMMENT '회원ID',
    os VARCHAR(20) NOT NULL COMMENT '운영체제',
    deviceId VARCHAR(100) NOT NULL COMMENT '사용 디바이스 ID',
    firebaseToken VARCHAR(512) NOT NULL COMMENT 'FCM 토큰',
    firebaseUpdatedAt DATETIME NOT NULL COMMENT 'FCM 업데이트 시간',
    PRIMARY KEY (userDeviceId),
    CONSTRAINT fk_user_device_user FOREIGN KEY (userId) REFERENCES users (userId)
);

-- 회원 루틴 지표
-- users와 1:1 관계
CREATE TABLE user_metrics (
    userMetricId BIGINT NOT NULL AUTO_INCREMENT COMMENT '회원루틴지표ID',
    userId BIGINT NOT NULL COMMENT '회원ID',
    maxContinualDays INT NOT NULL COMMENT '최대 연속 수행일',
    historicalMaxStreak INT NOT NULL COMMENT '역대 최대 스트릭',
    historicalCumulativeDays INT NOT NULL COMMENT '누적 수행일',
    PRIMARY KEY (userMetricId),
    CONSTRAINT fk_user_metrics_user FOREIGN KEY (userId) REFERENCES users (userId)
);

-- 회원 관심 태그
-- user 테이블과 1:N 관계
-- tag 테이블과 1:N 관계
CREATE TABLE user_tag (
    userTagId BIGINT NOT NULL AUTO_INCREMENT COMMENT '회원태그ID',
    userId BIGINT NOT NULL COMMENT '회원ID',
    tagId BIGINT NOT NULL COMMENT '태그ID',
    PRIMARY KEY (userTagId),
    UNIQUE KEY uk_user_tags_user_tag (userId, tagId),
    CONSTRAINT fk_users_to_user_tags FOREIGN KEY (userId) REFERENCES users (userId),
    CONSTRAINT fk_tags_to_user_tags FOREIGN KEY (tagId) REFERENCES tag (tagId)
);

-- 회원 가이드 정보
-- users 테이블과 1:N 관계
-- guide_item 테이블과 1:N 관계
CREATE TABLE user_guide_item (
    userGuideItemId BIGINT NOT NULL AUTO_INCREMENT COMMENT '회원가이드ID',
    userId BIGINT NOT NULL COMMENT '회원ID',
    guideId BIGINT NOT NULL COMMENT '가이드ID',
    confirmedAt DATETIME NOT NULL COMMENT '완료일자',
    PRIMARY KEY (userGuideItemId),
    UNIQUE KEY uk_user_guide (userId, guideId),
    CONSTRAINT fk_user_guide_user FOREIGN KEY (userId) REFERENCES users (userId),
    CONSTRAINT fk_user_guide_item FOREIGN KEY (guideId) REFERENCES guide_item (guideId)
);

-- 친구
-- users 테이블과 1:N 관계
CREATE TABLE friend (
    friendId BIGINT NOT NULL AUTO_INCREMENT COMMENT '친구ID',
    userLowId BIGINT NOT NULL COMMENT '회원ID(작은 번호)',
    userHighId BIGINT NOT NULL COMMENT '회원ID(큰 번호)',
    PRIMARY KEY (friendId),
    UNIQUE KEY uk_friend_unique (userLowId, userHighId),
    CONSTRAINT fk_friend_user_low FOREIGN KEY (userLowId) REFERENCES users (userId),
    CONSTRAINT fk_friend_user_high FOREIGN KEY (userHighId) REFERENCES users (userId)
);

-- 구독 상품
CREATE TABLE subscription_product (
    subscriptionProductId BIGINT NOT NULL AUTO_INCREMENT COMMENT '구독상품ID',
    vendorProductId VARCHAR(200) NOT NULL COMMENT '스토어 상품 ID',
    store VARCHAR(20) NOT NULL COMMENT '구독 플랫폼',
    isActive BOOLEAN NOT NULL COMMENT '활성화 여부',
    PRIMARY KEY (subscriptionProductId)
);

-- 구독
-- users 테이블과 1:1 관계
-- subscription_product 테이블과 1:N 관계
CREATE TABLE subscription (
    subscriptionId BIGINT NOT NULL AUTO_INCREMENT COMMENT '회원구독ID',
    userId BIGINT NOT NULL COMMENT '회원ID',
    subscriptionProductId BIGINT NOT NULL COMMENT '구독상품ID',
    activatedAt DATETIME NOT NULL COMMENT '구독 시작일시',
    renewedAt DATETIME NULL COMMENT '마지막 갱신일시',
    expiresAt DATETIME NOT NULL COMMENT '만료 시간',
    willRenew BOOLEAN NOT NULL COMMENT '자동 갱신 여부',
    unsubscribedAt DATETIME NULL COMMENT '구독 취소 시간',
    isInGracePeriod BOOLEAN NOT NULL COMMENT '결제 실패 유예 여부',
    isSandbox BOOLEAN NOT NULL COMMENT '테스트 구독 여부',
    vendorTransactionId VARCHAR(100) NULL COMMENT '스토어 거래 ID',
    vendorOriginalTransactionId VARCHAR(100) NULL COMMENT '원본 거래 ID',
    isActive BOOLEAN NOT NULL COMMENT '현재 활성 구독 여부',
    PRIMARY KEY (subscriptionId),
    CONSTRAINT fk_subscription_user FOREIGN KEY (userId) REFERENCES users (userId),
    CONSTRAINT fk_subscription_product FOREIGN KEY (subscriptionProductId) REFERENCES subscription_product (subscriptionProductId)
);

-- 구독 이력
CREATE TABLE subscription_history (
    subscriptionHistoryId BIGINT NOT NULL AUTO_INCREMENT COMMENT '구독이력ID',
    userId BIGINT NOT NULL COMMENT '회원ID',
    activatedAt DATETIME NOT NULL COMMENT '구독 시작일시',
    renewedAt DATETIME NULL COMMENT '마지막 갱신일시',
    expiresAt DATETIME NOT NULL COMMENT '만료 시간',
    willRenew BOOLEAN NOT NULL COMMENT '자동 갱신 여부',
    unsubscribedAt DATETIME NULL COMMENT '구독 취소 시간',
    isInGracePeriod BOOLEAN NOT NULL COMMENT '결제 실패 유예 여부',
    isSandbox BOOLEAN NOT NULL COMMENT '테스트 구독 여부',
    vendorTransactionId VARCHAR(100) NULL COMMENT '스토어 거래 ID',
    vendorOriginalTransactionId VARCHAR(100) NULL COMMENT '원본 거래 ID',
    isActive BOOLEAN NOT NULL COMMENT '현재 활성 구독 여부',
    vendorProductId VARCHAR(200) NOT NULL COMMENT '스토어 상품 ID',
    store VARCHAR(20) NOT NULL COMMENT '구독 플랫폼',
    PRIMARY KEY (subscriptionHistoryId)
);

-- 루틴
-- users 테이블과 1:N 관계
CREATE TABLE routine (
    routineId BIGINT NOT NULL AUTO_INCREMENT COMMENT '루틴ID',
    userId BIGINT NOT NULL COMMENT '회원ID',
    title VARCHAR(100) NOT NULL COMMENT '루틴 이름',
    orders INT NOT NULL COMMENT '목록 정렬 순서',
    deleted BOOLEAN NOT NULL COMMENT '소프트 삭제 여부',
    archive BOOLEAN NOT NULL COMMENT '보관 여부',
    lastUpdated DATETIME NOT NULL COMMENT '마지막 수정 시간',
    setTTS BOOLEAN NOT NULL COMMENT 'TTS 사용 여부',
    notifyFriendsOnStart BOOLEAN NOT NULL COMMENT '친구에게 내 활동 알림 여부',
    setAlarm BOOLEAN NOT NULL COMMENT '알림 설정 여부',
    notifType VARCHAR(20) NOT NULL COMMENT '알림 타입',
    alarmSoundId VARCHAR(20) NOT NULL COMMENT '알림 사운드 ID',
    setAlarmMethod VARCHAR(30) NOT NULL COMMENT '알림 방식',
    PRIMARY KEY (routineId),
    CONSTRAINT fk_routine_user FOREIGN KEY (userId) REFERENCES users (userId)
);

-- 루틴 지표
-- routine 테이블과 1:1 관계
CREATE TABLE routine_metric (
    routineMetricsId BIGINT NOT NULL AUTO_INCREMENT COMMENT '루틴지표ID',
    routineId BIGINT NOT NULL COMMENT '루틴ID',
    currentStreak INT NOT NULL COMMENT '현재 연속 수행일',
    maxStreak INT NOT NULL COMMENT '최대 연속 수행일',
    totalCount INT NOT NULL COMMENT '총 수행 횟수',
    avgStartTime INT NOT NULL COMMENT '평균 시작 시간(초)',
    avgDuration INT NOT NULL COMMENT '평균 수행 시간(초)',
    lastRoutineStartTime DATETIME NULL COMMENT '마지막 루틴 시작 타임스탬프',
    lastRoutineEndTime DATETIME NULL COMMENT '마지막 루틴 종료 타임스탬프',
    PRIMARY KEY (routineMetricsId),
    CONSTRAINT fk_routine_metric_routine FOREIGN KEY (routineId) REFERENCES routine (routineId)
);

-- 루틴 시작 조건
-- routine 테이블과 1:1 관계
CREATE TABLE routine_start_option (
    routineStartDetailId BIGINT NOT NULL AUTO_INCREMENT COMMENT '루틴시작상세ID',
    routineId BIGINT NOT NULL COMMENT '루틴ID',
    startOption VARCHAR(20) NOT NULL COMMENT '시작조건 타입',
    startTime INT NULL COMMENT '시작시간(분단위)',
    startCondition VARCHAR(100) NULL COMMENT '시작조건 텍스트',
    startLocation JSON NULL COMMENT '위치기반 조건',
    PRIMARY KEY (routineStartDetailId),
    CONSTRAINT fk_start_option_routine FOREIGN KEY (routineId) REFERENCES routine (routineId)
);

-- 루틴 반복 주기
-- routine 테이블과 1:1 관계
CREATE TABLE routine_period (
    routinePeriodId BIGINT NOT NULL AUTO_INCREMENT COMMENT '루틴반복주기ID',
    routineId BIGINT NOT NULL COMMENT '루틴ID',
    type VARCHAR(20) NOT NULL COMMENT '반복타입',
    unit TINYINT NOT NULL COMMENT '반복주기',
    startDate DATETIME NOT NULL COMMENT '시작일자',
    PRIMARY KEY (routinePeriodId),
    CONSTRAINT fk_period_routine FOREIGN KEY (routineId) REFERENCES routine (routineId)
);

-- 루틴 요일별 반복
-- routine_period 테이블과 1:N 관계
CREATE TABLE routine_period_weekly (
    routineWeeklyId BIGINT NOT NULL AUTO_INCREMENT COMMENT '루틴요일반복ID',
    routinePeriodId BIGINT NOT NULL COMMENT '루틴반복주기ID',
    dayOfWeek TINYINT NOT NULL COMMENT '요일',
    PRIMARY KEY (routineWeeklyId),
    CONSTRAINT fk_weekly_period FOREIGN KEY (routinePeriodId) REFERENCES routine_period (routinePeriodId)
);

-- 루틴 월별 반복
-- routine_period 테이블과 1:N 관계
CREATE TABLE routine_period_monthly (
    routineMonthlyId BIGINT NOT NULL AUTO_INCREMENT COMMENT '루틴월반복ID',
    routinePeriodId BIGINT NOT NULL COMMENT '루틴반복주기ID',
    dayOfMonth TINYINT NOT NULL COMMENT '일자',
    PRIMARY KEY (routineMonthlyId),
    CONSTRAINT fk_monthly_period FOREIGN KEY (routinePeriodId) REFERENCES routine_period (routinePeriodId)
);

-- 루틴 태그
-- routine 테이블과 1:N 관계
-- tag 테이블과 1:N 관계
CREATE TABLE routine_tag (
    routineTagId BIGINT NOT NULL AUTO_INCREMENT COMMENT '루틴태그ID',
    routineId BIGINT NOT NULL COMMENT '루틴ID',
    tagId BIGINT NOT NULL COMMENT '태그ID',
    PRIMARY KEY (routineTagId),
    UNIQUE KEY uk_routine_tag (routineId, tagId),
    CONSTRAINT fk_routine_tag_routine FOREIGN KEY (routineId) REFERENCES routine (routineId),
    CONSTRAINT fk_routine_tag_tag FOREIGN KEY (tagId) REFERENCES tag (tagId)
);

-- 습관
-- routine 테이블과 1:N 관계
CREATE TABLE habit (
    habitId BIGINT NOT NULL AUTO_INCREMENT COMMENT '습관ID',
    routineId BIGINT NOT NULL COMMENT '루틴ID',
    habitKeys VARCHAR(100) NOT NULL COMMENT 'Habit 이름/키',
    icon VARCHAR(100) NULL COMMENT '아이콘 이미지 또는 코드',
    duration INT NOT NULL COMMENT '목표 수행 시간(초)',
    orders INT NOT NULL COMMENT '루틴내 정렬 순서',
    isActive BOOLEAN NOT NULL COMMENT '활성화 여부',
    type VARCHAR(20) NOT NULL COMMENT 'Habit 타입',
    description VARCHAR(500) NULL COMMENT '설명',
    tts BOOLEAN NOT NULL COMMENT 'TTS 여부',
    whitenoise BOOLEAN NOT NULL COMMENT '백색소음 사용 여부',
    whiteNoiseUrl VARCHAR(200) NULL COMMENT '백색소음 URL',
    lastUpdated DATETIME NULL COMMENT '마지막 수정 시간',
    autoComplete BOOLEAN NOT NULL COMMENT '자동 완료 여부',
    PRIMARY KEY (habitId),
    CONSTRAINT fk_habit_routine FOREIGN KEY (routineId) REFERENCES routine (routineId)
);

-- 루틴 로그
CREATE TABLE log (
    logId BIGINT NOT NULL AUTO_INCREMENT COMMENT '로그ID',
    routineId BIGINT NULL COMMENT '루틴 ID',
    userId BIGINT NULL COMMENT '회원 ID',
    start DATETIME NULL COMMENT '루틴 시작 타임스탬프',
    end DATETIME NULL COMMENT '루틴 종료 타임스탬프',
    streak INT NULL COMMENT '수행 당일 기준 현재 연속일',
    saveTime DATETIME NULL COMMENT '기록 저장 타임스탬프',
    total INT NULL COMMENT '총 habit 수',
    unfinished BOOLEAN NOT NULL COMMENT '미완료 상태 여부',
    isStreakSaver BOOLEAN NOT NULL COMMENT '복구권으로 완료 처리 여부',
    mood TINYINT NULL COMMENT '기분 점수 1~5',
    impression VARCHAR(500) NULL COMMENT '한 줄 소감',
    PRIMARY KEY (logId)
);

-- 기록 당시의 Habit 목록 스냅샷 (Habit[])
-- log 테이블과 1:N 관계
CREATE TABLE log_habit_snapshot (
    logHabitSnapshotId BIGINT NOT NULL AUTO_INCREMENT COMMENT '습관스냅샷ID',
    logId BIGINT NOT NULL COMMENT '로그ID',
    habitId BIGINT NOT NULL COMMENT '습관ID',
    habitKeys VARCHAR(100) NOT NULL COMMENT 'Habit 이름/키',
    icon VARCHAR(20) NULL COMMENT '아이콘 이미지 또는 코드',
    duration INT NOT NULL COMMENT '목표 수행 시간(초)',
    orders INT NOT NULL COMMENT '루틴 내 정렬 순서',
    isActive BOOLEAN NOT NULL COMMENT '활성화 여부',
    type VARCHAR(20) NOT NULL COMMENT 'Habit 타입',
    description VARCHAR(500) NULL COMMENT '설명',
    tts BOOLEAN NOT NULL COMMENT 'TTS 읽기 여부',
    whitenoise BOOLEAN NOT NULL COMMENT '백색소음 사용 여부',
    whiteNoiseUrl VARCHAR(200) NULL COMMENT '백색소음 URL',
    lastUpdated DATETIME NULL COMMENT '마지막 수정 시간',
    auto BOOLEAN NOT NULL COMMENT '자동 완료 여부',
    PRIMARY KEY (logHabitSnapshotId),
    CONSTRAINT fk_log_habit_snapshot_log FOREIGN KEY (logId) REFERENCES log (logId)
);

-- 전체 완료/스킵 기록 배열 (CheckLog[])
-- log 테이블과 1:N 관계
CREATE TABLE log_habit_check (
    logHabitCheckId BIGINT NOT NULL AUTO_INCREMENT COMMENT '습관기록로그ID',
    logId BIGINT NOT NULL COMMENT '로그ID',
    actualDuration INT NULL COMMENT '실제 수행 시간',
    status VARCHAR(20) NULL COMMENT '상태',
    PRIMARY KEY (logHabitCheckId),
    CONSTRAINT fk_log_habit_check_log FOREIGN KEY (logId) REFERENCES log (logId)
);

-- 타이머로 완료한 Habit 기록 (HabitLog[])
-- log 테이블과 1:N 관계
CREATE TABLE log_habit_timer (
    logHabitTimerId BIGINT NOT NULL AUTO_INCREMENT COMMENT '습관타이머로그ID',
    logId BIGINT NOT NULL COMMENT '로그ID',
    habitId BIGINT NOT NULL COMMENT '습관ID',
    actualDuration INT NULL COMMENT '실제 수행 시간(초)',
    duration INT NULL COMMENT '목표 수행 시간(초)',
    finishedDate DATETIME NULL COMMENT '완료 타임스탬프',
    skip BOOLEAN NOT NULL COMMENT '스킵여부',
    PRIMARY KEY (logHabitTimerId),
    CONSTRAINT fk_log_habit_timer_log FOREIGN KEY (logId) REFERENCES log (logId)
);
