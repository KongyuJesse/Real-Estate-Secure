-- Real Estate Secure - Remove land title registry tables and surveyor profiles.
-- The platform does not manage land titles or government registries directly.

DROP TABLE IF EXISTS land_titles CASCADE;
DROP TABLE IF EXISTS surveyor_profiles CASCADE;
