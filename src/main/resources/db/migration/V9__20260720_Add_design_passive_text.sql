-- 카드 디자인별 패시브 문구.
-- 공유 스킬 사전(gatcha_skills)과 별개로 카드 표면에 직접 노출되는
-- 짧은 패시브 설명을 운영자가 등록할 수 있게 한다.

ALTER TABLE gatcha_designs
    ADD COLUMN passive_text TEXT;
