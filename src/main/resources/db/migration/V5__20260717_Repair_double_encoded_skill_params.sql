-- V5: gatcha_skills.params 이중 인코딩 보정
-- 초기 등록분 일부가 jsonb 객체({}) 대신 jsonb 문자열("{}")로 저장됨
-- (등록 API가 파라미터를 문자열로 바인딩하던 버그 — 이미 수정됨).
-- 문자열 타입 params를 내부 JSON으로 풀어 객체로 되돌린다.

UPDATE gatcha_skills
SET params = (params #>> '{}')::jsonb
WHERE jsonb_typeof(params) = 'string';
