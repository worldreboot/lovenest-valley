-- Update invite codes to be exactly 6 digits long
-- This migration modifies the create_couple_invite function to generate numeric codes

-- Drop the existing function if it exists
DROP FUNCTION IF EXISTS public.create_couple_invite();

-- Create the updated function that generates 6-digit codes
CREATE OR REPLACE FUNCTION public.create_couple_invite()
RETURNS TABLE (
    id UUID,
    inviter_id UUID,
    invite_code TEXT,
    expires_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_invite_id UUID;
    v_invite_code TEXT;
    v_expires_at TIMESTAMP WITH TIME ZONE;
BEGIN
    -- Check if user is authenticated
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    -- Check if user is already in a couple
    IF EXISTS (
        SELECT 1 FROM couples 
        WHERE user1_id = v_user_id OR user2_id = v_user_id
    ) THEN
        RAISE EXCEPTION 'Already in a couple';
    END IF;

    -- Check if user already has an active invite
    IF EXISTS (
        SELECT 1 FROM couple_invites 
        WHERE inviter_id = v_user_id AND expires_at > NOW()
    ) THEN
        RAISE EXCEPTION 'Already have an active invite';
    END IF;

    -- Generate a unique 6-digit code
    LOOP
        -- Generate a random 6-digit number (100000 to 999999)
        v_invite_code := LPAD(FLOOR(RANDOM() * 900000 + 100000)::TEXT, 6, '0');
        
        -- Check if this code is already in use
        EXIT WHEN NOT EXISTS (
            SELECT 1 FROM couple_invites 
            WHERE invite_code = v_invite_code AND expires_at > NOW()
        );
    END LOOP;

    -- Set expiration to 24 hours from now
    v_expires_at := NOW() + INTERVAL '24 hours';

    -- Create the invite
    INSERT INTO couple_invites (inviter_id, invite_code, expires_at)
    VALUES (v_user_id, v_invite_code, v_expires_at)
    RETURNING id INTO v_invite_id;

    -- Return the created invite
    RETURN QUERY
    SELECT 
        ci.id,
        ci.inviter_id,
        ci.invite_code,
        ci.expires_at,
        ci.created_at
    FROM couple_invites ci
    WHERE ci.id = v_invite_id;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.create_couple_invite() TO authenticated;

-- Add comment for documentation
COMMENT ON FUNCTION public.create_couple_invite() IS 'Creates a couple invite with a unique 6-digit code that expires in 24 hours';
