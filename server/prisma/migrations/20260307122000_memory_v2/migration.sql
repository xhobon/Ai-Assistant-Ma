-- Memory V2: layered category + confidence + expiry + source
ALTER TABLE "UserMemory"
  ALTER COLUMN "category" SET DEFAULT 'preference';

ALTER TABLE "UserMemory"
  ADD COLUMN "confidence" DOUBLE PRECISION NOT NULL DEFAULT 0.65,
  ADD COLUMN "expiresAt" TIMESTAMP(3),
  ADD COLUMN "source" TEXT NOT NULL DEFAULT 'manual',
  ADD COLUMN "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP;

-- Backfill old category values
UPDATE "UserMemory"
SET "category" = 'preference'
WHERE "category" IS NULL OR "category" = '' OR "category" = 'fact';

-- Backfill expiry policy for old data (habit shorter, preference/goal longer)
UPDATE "UserMemory"
SET "expiresAt" = CASE
  WHEN "category" = 'habit' THEN "createdAt" + INTERVAL '180 days'
  WHEN "category" = 'goal' THEN NULL
  ELSE "createdAt" + INTERVAL '365 days'
END
WHERE "expiresAt" IS NULL;

CREATE INDEX IF NOT EXISTS "UserMemory_userId_expiresAt_idx" ON "UserMemory"("userId", "expiresAt");
CREATE INDEX IF NOT EXISTS "UserMemory_userId_confidence_idx" ON "UserMemory"("userId", "confidence");
