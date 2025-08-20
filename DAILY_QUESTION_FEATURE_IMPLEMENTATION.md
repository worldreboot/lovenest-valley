# Daily Question Feature Implementation

## Overview

This feature implements a complete daily question system where the owl NPC provides unique seeds that correspond to daily questions. Users can plant these seeds, answer the questions, and then water them for 3 consecutive days to see them bloom into beautiful generated sprites.

## Architecture

### 1. Backend Integration
- **DailyQuestionSeedService**: Handles all backend operations for daily question seeds
- **QuestionService**: Manages daily question fetching and answer storage
- **Database Tables**: Uses existing `seeds`, `questions`, `user_daily_question_answers`, `farm_tiles`, and `generation_jobs` tables

### 2. Frontend Components
- **DailyQuestionPlantingDialog**: Dialog for answering questions before planting
- **DailyQuestionProgressIndicator**: Visual progress indicator for watering
- **OwlNpcComponent**: Enhanced with daily question functionality

### 3. Game Integration
- **SimpleEnhancedFarmGame**: Updated watering system to handle daily question seeds
- **GameScreen**: Integrated planting and progress tracking

## Feature Flow

### 1. Getting a Daily Question
1. User taps the owl NPC
2. Owl checks for available daily questions via `QuestionService.fetchDailyQuestion()`
3. If available, shows `DailyQuestionLetterSheet` for answer input
4. Answer is saved and daily question seed is added to inventory

### 2. Planting the Seed
1. User selects daily question seed from inventory
2. Taps on tilled soil
3. `DailyQuestionPlantingDialog` appears with the original question
4. User enters their answer
5. Seed is planted using `DailyQuestionSeedService.plantDailyQuestionSeed()`
6. Backend creates seed record and farm tile entry

### 3. Watering System
1. User waters the planted seed with watering can
2. `DailyQuestionSeedService.waterDailyQuestionSeed()` tracks progress
3. Water count increments in `farm_tiles` table
4. After 3 days of watering, seed is ready to bloom

### 4. Blooming Process
1. When water count reaches 3, `_generateAndStoreSprite()` is called
2. Creates generation job for flower sprite based on question and answer
3. Updates seed state to `bloom_stage_3`
4. Generated sprite URL is stored and can be displayed

## Key Components

### DailyQuestionSeedService
```dart
// Plant a daily question seed
static Future<bool> plantDailyQuestionSeed({
  required String questionId,
  required String answer,
  required int plotX,
  required int plotY,
  required String farmId,
})

// Water a daily question seed
static Future<bool> waterDailyQuestionSeed({
  required int plotX,
  required int plotY,
  required String farmId,
})

// Get watering progress
static Future<int> getWateringProgress(int plotX, int plotY, String farmId)

// Check if ready to bloom
static Future<bool> isReadyToBloom(int plotX, int plotY, String farmId)
```

### DailyQuestionPlantingDialog
- Shows the original question
- Provides text input for answer
- Handles planting with backend integration
- Shows loading states and error handling

### Enhanced Watering System
- Detects daily question seeds automatically
- Uses special watering service for progress tracking
- Provides visual feedback on watering progress

## Database Schema

The feature uses existing tables with these key relationships:

```sql
-- Seeds table stores the planted daily question
seeds (
  id, planter_id, question_id, text_content, 
  state, growth_score, plot_x, plot_y
)

-- Farm tiles tracks watering progress
farm_tiles (
  farm_id, x, y, plant_type, water_count, 
  growth_stage, planted_at, last_watered_at
)

-- Generation jobs for sprite creation
generation_jobs (
  id, user_id, status, prompt, final_image_url
)
```

## Testing Instructions

### 1. Test Daily Question Flow
1. Start the app and navigate to the farm
2. Tap the owl NPC (should show notification if daily question available)
3. Answer the question in the dialog
4. Check that daily question seed appears in inventory

### 2. Test Planting
1. Select the daily question seed from inventory
2. Tap on tilled soil
3. Verify the planting dialog appears with the question
4. Enter an answer and plant
5. Check that seed is planted and tile shows crop

### 3. Test Watering
1. Water the planted daily question seed
2. Check that water count increments (1/3, 2/3, 3/3)
3. Verify progress indicator shows correctly
4. After 3 days, check that seed blooms and sprite is generated

### 4. Test Sprite Generation
1. Complete 3 days of watering
2. Check that generation job is created in backend
3. Verify seed state changes to `bloom_stage_3`
4. Check that sprite URL is available for display

## Error Handling

- **No Daily Question Available**: Owl shows no notification
- **Planting Without Answer**: Shows error message
- **Watering Already Bloomed**: Prevents further watering
- **Backend Errors**: Graceful fallback with user feedback

## Future Enhancements

1. **Visual Feedback**: Add particle effects when seeds bloom
2. **Sound Effects**: Add audio cues for watering and blooming
3. **Achievement System**: Track completion of daily questions
4. **Social Features**: Share bloomed sprites with partner
5. **Weather Integration**: Different sprites based on weather conditions

## Technical Notes

- Uses existing generation job system for sprite creation
- Integrates with current farm tile system
- Maintains compatibility with existing seed types
- Follows established patterns for game object management
- Uses proper error handling and user feedback throughout 