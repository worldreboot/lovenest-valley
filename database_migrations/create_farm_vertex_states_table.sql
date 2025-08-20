-- Create farm_vertex_states table for storing vertex grid data
CREATE TABLE IF NOT EXISTS farm_vertex_states (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  farm_id UUID NOT NULL REFERENCES farms(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  vertex_grid JSONB NOT NULL,
  last_updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(farm_id, user_id)
);

-- Add indexes for better performance
CREATE INDEX IF NOT EXISTS idx_farm_vertex_states_farm_id ON farm_vertex_states (farm_id);
CREATE INDEX IF NOT EXISTS idx_farm_vertex_states_user_id ON farm_vertex_states (user_id);

-- Add RLS policies
ALTER TABLE farm_vertex_states ENABLE ROW LEVEL SECURITY;

-- Users can only see their own vertex states
CREATE POLICY "Users can view their own vertex states" ON farm_vertex_states
  FOR SELECT USING (auth.uid() = user_id);

-- Users can only insert their own vertex states
CREATE POLICY "Users can insert their own vertex states" ON farm_vertex_states
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Users can only update their own vertex states
CREATE POLICY "Users can update their own vertex states" ON farm_vertex_states
  FOR UPDATE USING (auth.uid() = user_id);

-- Users can only delete their own vertex states
CREATE POLICY "Users can delete their own vertex states" ON farm_vertex_states
  FOR DELETE USING (auth.uid() = user_id); 