-- Create storage bucket for seashell audio files
-- This bucket will store audio recordings that users create for their partners

-- Create the bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'seashell-audio',
  'seashell-audio',
  true, -- public bucket so partners can access each other's audio
  10485760, -- 10MB file size limit
  ARRAY['audio/m4a', 'audio/mp3', 'audio/wav', 'audio/aac'] -- allowed audio formats
) ON CONFLICT (id) DO NOTHING;

-- Create RLS policies for the bucket
-- Allow authenticated users to upload audio files
CREATE POLICY "Users can upload audio files" ON storage.objects
FOR INSERT WITH CHECK (
  bucket_id = 'seashell-audio' AND
  auth.role() = 'authenticated'
);

-- Allow users to read audio files (for partners to listen)
CREATE POLICY "Users can read audio files" ON storage.objects
FOR SELECT USING (
  bucket_id = 'seashell-audio' AND
  auth.role() = 'authenticated'
);

-- Allow users to update their own audio files
CREATE POLICY "Users can update their audio files" ON storage.objects
FOR UPDATE USING (
  bucket_id = 'seashell-audio' AND
  auth.role() = 'authenticated'
);

-- Allow users to delete their own audio files
CREATE POLICY "Users can delete their audio files" ON storage.objects
FOR DELETE USING (
  bucket_id = 'seashell-audio' AND
  auth.role() = 'authenticated'
); 