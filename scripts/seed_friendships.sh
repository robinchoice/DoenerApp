#!/bin/bash
# Run after your first Apple Sign-In on the iPhone to create 5 accepted
# friendships between you and the seeded test users (Ahmet, Mehmet, ...).
# Use this to test the socialButterfly achievement.
set -euo pipefail

docker exec backend-db-1 psql -U doener -d doenerapp <<'SQL'
DO $$
DECLARE
    me uuid;
    seed_id uuid;
BEGIN
    -- Pick the most recently created non-seed user (i.e. you)
    SELECT id INTO me
    FROM users
    WHERE apple_user_id NOT LIKE 'seed-%'
    ORDER BY created_at DESC
    LIMIT 1;

    IF me IS NULL THEN
        RAISE EXCEPTION 'No real user found. Sign in via Apple on the iPhone first.';
    END IF;

    RAISE NOTICE 'Creating friendships for user %', me;

    FOR seed_id IN SELECT id FROM users WHERE apple_user_id LIKE 'seed-%' LOOP
        INSERT INTO friendships (id, requester_id, addressee_id, status, created_at)
        VALUES (gen_random_uuid(), me, seed_id, 'accepted', now())
        ON CONFLICT (requester_id, addressee_id) DO UPDATE SET status = 'accepted';
    END LOOP;
END $$;

SELECT u.display_name, f.status
FROM friendships f
JOIN users u ON u.id = f.addressee_id
WHERE f.requester_id = (
    SELECT id FROM users WHERE apple_user_id NOT LIKE 'seed-%'
    ORDER BY created_at DESC LIMIT 1
);
SQL
