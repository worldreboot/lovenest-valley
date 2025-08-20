-- Create a prompt preset for avatar spritesheet generation
INSERT INTO prompt_presets (preset_name, prompt_text, is_active, created_at)
VALUES (
  'avatar_spritesheet',
  'Create a pixel art character spritesheet for a 2D game with the following specifications:
- Character should be cute and friendly looking
- Suitable for a romantic/couple game theme
- Pixel art style with clear outlines and vibrant colors
- 32x32 pixel base size for each frame
- Spritesheet layout: 4 frames per row, 3 rows (up, right, down directions)
- Left direction will be created by flipping right frames
- Include idle animation frames
- Character should have distinct features that make them unique
- Style should be consistent across all frames
- Background should be transparent
- Character should be centered in each frame',
  true,
  NOW()
); 