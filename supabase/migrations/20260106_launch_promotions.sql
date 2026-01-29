-- Migration: Create launch_promotions table
-- Offre de lancement Tontetic: 20 créateurs × 10 personnes = 200 utilisateurs max

-- Table principale des promotions
CREATE TABLE IF NOT EXISTS launch_promotions (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL UNIQUE,
    type TEXT NOT NULL CHECK (type IN ('creator', 'invited')),
    invited_by TEXT REFERENCES launch_promotions(user_id),
    claimed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL,
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('available', 'claimed', 'active', 'expired', 'locked', 'cancelled')),
    tontine_started BOOLEAN NOT NULL DEFAULT FALSE,
    invites_sent INTEGER NOT NULL DEFAULT 0 CHECK (invites_sent >= 0 AND invites_sent <= 9),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index pour les requêtes fréquentes
CREATE INDEX idx_launch_promo_type ON launch_promotions(type);
CREATE INDEX idx_launch_promo_status ON launch_promotions(status);
CREATE INDEX idx_launch_promo_expires ON launch_promotions(expires_at);
CREATE INDEX idx_launch_promo_invited_by ON launch_promotions(invited_by);

-- Trigger pour updated_at
CREATE OR REPLACE FUNCTION update_launch_promo_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_launch_promo_updated
    BEFORE UPDATE ON launch_promotions
    FOR EACH ROW
    EXECUTE FUNCTION update_launch_promo_timestamp();

-- RLS (Row Level Security)
ALTER TABLE launch_promotions ENABLE ROW LEVEL SECURITY;

-- Politique: Un utilisateur peut voir sa propre promo
CREATE POLICY "Users can view own promo" ON launch_promotions
    FOR SELECT
    USING (auth.uid()::text = user_id);

-- Politique: Les admins peuvent tout voir
CREATE POLICY "Admins can view all promos" ON launch_promotions
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM admin_users 
            WHERE admin_users.user_id = auth.uid()::text
        )
    );

-- Vue pour les stats admin
CREATE OR REPLACE VIEW launch_promo_stats AS
SELECT
    COUNT(*) FILTER (WHERE type = 'creator') AS creators_used,
    20 - COUNT(*) FILTER (WHERE type = 'creator') AS creators_remaining,
    COUNT(*) FILTER (WHERE type = 'invited') AS total_invited,
    COUNT(*) FILTER (WHERE status = 'locked') AS total_locked,
    COUNT(*) FILTER (WHERE status = 'expired') AS total_expired,
    COUNT(*) FILTER (WHERE status = 'active') AS total_active,
    COUNT(*) AS total_users
FROM launch_promotions;

-- Fonction pour vérifier si l'offre créateur est disponible
CREATE OR REPLACE FUNCTION is_creator_promo_available()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN (SELECT COUNT(*) FROM launch_promotions WHERE type = 'creator') < 20;
END;
$$ LANGUAGE plpgsql;

-- Fonction pour verrouiller automatiquement quand tontine démarre
-- À appeler via trigger sur la table circles quand status = 'active'
CREATE OR REPLACE FUNCTION lock_promo_on_tontine_start()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status = 'active' AND OLD.status != 'active' THEN
        -- Verrouiller la promo du créateur
        UPDATE launch_promotions 
        SET tontine_started = TRUE, status = 'locked'
        WHERE user_id = NEW.created_by 
        AND status = 'active';
        
        -- Verrouiller les promos des membres
        UPDATE launch_promotions 
        SET tontine_started = TRUE, status = 'locked'
        WHERE user_id IN (
            SELECT member_id FROM circle_members WHERE circle_id = NEW.id
        )
        AND status = 'active';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Note: Activer ce trigger sur votre table circles si elle existe
-- CREATE TRIGGER trigger_lock_promo_on_tontine
--     AFTER UPDATE ON circles
--     FOR EACH ROW
--     EXECUTE FUNCTION lock_promo_on_tontine_start();

-- Fonction CRON pour expirer les promos (à appeler via pg_cron ou Edge Function)
CREATE OR REPLACE FUNCTION expire_old_promos()
RETURNS INTEGER AS $$
DECLARE
    expired_count INTEGER;
BEGIN
    UPDATE launch_promotions
    SET status = 'expired'
    WHERE status = 'active'
    AND expires_at < NOW();
    
    GET DIAGNOSTICS expired_count = ROW_COUNT;
    RETURN expired_count;
END;
$$ LANGUAGE plpgsql;

-- Commentaires pour documentation
COMMENT ON TABLE launch_promotions IS 'Offre de lancement: 20 créateurs × 9 invités = 200 users max, 3 mois Starter gratuit';
COMMENT ON COLUMN launch_promotions.type IS 'creator = 1 des 20 premiers, invited = invité par un créateur';
COMMENT ON COLUMN launch_promotions.tontine_started IS 'true = abonnement verrouillé, impossible d''annuler';
COMMENT ON COLUMN launch_promotions.invites_sent IS 'Nombre d''invitations envoyées (max 9 pour créateurs)';
