import os
import json
import base64
import openai
from supabase import create_client, Client

# Initialize clients outside the handler
try:
    SUPABASE_URL = os.environ.get("SUPABASE_URL")
    SUPABASE_KEY = os.environ.get("SUPABASE_SERVICE_KEY")
    WEBHOOK_SECRET = os.environ.get("WEBHOOK_SECRET_TOKEN")
    openai.api_key = os.environ.get("OPENAI_API_KEY")
    supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)
except Exception as e:
    print(f"ERROR: Could not initialize clients: {e}")

def _detect_mime_and_ext(blob: bytes):
    # PNG
    if len(blob) >= 8 and blob[:8] == b"\x89PNG\r\n\x1a\n":
        return ("image/png", ".png")
    # JPEG
    if len(blob) >= 3 and blob[:3] == b"\xff\xd8\xff":
        return ("image/jpeg", ".jpg")
    # WEBP: RIFF....WEBP
    if len(blob) >= 12 and blob[:4] == b"RIFF" and blob[8:12] == b"WEBP":
        return ("image/webp", ".webp")
    # Fallback to PNG to satisfy OpenAI (avoid octet-stream)
    return ("image/png", ".png")

def lambda_handler(event, context):
    # 1. Security Check
    headers = event.get('headers', {})
    if headers.get('x-secret-token') != WEBHOOK_SECRET:
        print("ERROR: Unauthorized - Incorrect or missing secret token.")
        return {'statusCode': 403, 'body': 'Forbidden'}

    # 2. Extract job details
    try:
        body = json.loads(event.get('body', '{}'))
        record = body.get('record', {})
        job_id = record.get('id')
        user_id = record.get('user_id')
        prompt = record.get('prompt')
        # Optional fields for routing
        preset_name = record.get('preset_name')  # e.g., 'avatar_spritesheet', 'item_sprite', 'gift_sprite'
        job_type = record.get('job_type')        # same idea as preset_name but more general
        template_spritesheet_path = record.get('template_spritesheet_path')  # optional base spritesheet
        # This might be None for text-to-image jobs, which is now expected.
        source_image_path = record.get('source_image_path')

        # A job is valid as long as it has an id, user, and prompt.
        if not all([job_id, user_id, prompt]):
            return {'statusCode': 400, 'body': 'Incomplete job data: missing id, user_id, or prompt.'}
    except Exception as e:
        return {'statusCode': 400, 'body': 'Invalid request body'}

    # 3. "Lock" the job
    try:
        supabase.table('generation_jobs').update({'status': 'processing'}).eq('id', job_id).execute()
    except Exception as e:
        return {'statusCode': 500, 'body': 'Failed to lock job'}

    try:
        # Determine effective job route
        effective_type = (job_type or preset_name or '').lower()

        # Helper to upload bytes to storage
        def upload_png(path: str, bytes_data: bytes) -> str:
            supabase.storage.from_('avatars').upload(
                path=path,
                file=bytes_data,
                file_options={"content-type": "image/png"}
            )
            return supabase.storage.from_('avatars').get_public_url(path)

        # CASE 1: Avatar + Spritesheet from a single user image
        if source_image_path and effective_type == 'avatar_spritesheet':
            print(f"Executing AVATAR+SPRITESHEET job {job_id}")

            # Download the source image
            source_image_bytes = supabase.storage.from_('avatars').download(source_image_path)
            src_mime, src_ext = _detect_mime_and_ext(source_image_bytes)
            src_filename = f"user_source{src_ext}"

            # Generate portrait avatar with a fixed prompt (user likeness, Stardew Valley style)
            avatar_prompt = "stardew valley style avatar portrait based on the user submitted image. keep the background transparent."
            avatar_result = openai.images.edit(
                model="gpt-image-1",
                image=(src_filename, source_image_bytes, src_mime),
                prompt=avatar_prompt
            )
            avatar_b64 = avatar_result.data[0].b64_json
            avatar_bytes = base64.b64decode(avatar_b64)
            avatar_path = f"raw/{user_id}/{job_id}-avatar.png"
            avatar_url = upload_png(avatar_path, avatar_bytes)

            # Generate spritesheet: use both user image and template for better likeness
            spritesheet_prompt = (
                f"{prompt}\n"
                "Create a Stardew Valley style spritesheet that looks like this person. "
                "3 rows: top=facing away, middle=facing right, bottom=facing forward. "
                "Each row shows walking animation. Transparent background."
            )

            # Resolve template base for reference
            spritesheet_base_bytes = None
            spritesheet_base_name = None
            # 1) Use explicit template path from job if present
            if template_spritesheet_path:
                try:
                    spritesheet_base_bytes = supabase.storage.from_('avatars').download(template_spritesheet_path)
                    # Detect template mime/ext and set filename accordingly
                    tpl_mime, tpl_ext = _detect_mime_and_ext(spritesheet_base_bytes)
                    base_name_only = template_spritesheet_path.split('/')[-1]
                    # Ensure we have an extension in the provided name
                    if '.' not in base_name_only:
                        base_name_only += tpl_ext
                    spritesheet_base_name = base_name_only
                    print(f"Using provided template_spritesheet_path: {template_spritesheet_path}")
                except Exception as _:
                    print("Provided template_spritesheet_path not found; will try default template or fallback.")
            # 2) Try default template location
            if spritesheet_base_bytes is None:
                default_template = 'templates/base_spritesheet.png'
                try:
                    spritesheet_base_bytes = supabase.storage.from_('avatars').download(default_template)
                    spritesheet_base_name = 'base_spritesheet.png'
                    print("Using default base spritesheet template.")
                except Exception as _:
                    print("Default base spritesheet not found; will fallback to generating from scratch.")

            # Perform spritesheet generation using both user image and template
            if spritesheet_base_bytes is not None:
                # Use gpt-4.1 with multiple images: user photo + template spritesheet
                spritesheet_prompt_with_template = (
                    f"{prompt}\n"
                    "Create a Stardew Valley style spritesheet that looks like the person in the first image. "
                    "Use the second image (template spritesheet) as a reference for the exact layout and structure. "
                    "Maintain the 3 rows: top=facing away, middle=facing right, bottom=facing forward. "
                    "Keep transparent background and walking animation frames. "
                    "Make the character in the spritesheet look like the person in the first image."
                )
                
                # Encode both images as base64
                user_image_b64 = base64.b64encode(source_image_bytes).decode('utf-8')
                template_b64 = base64.b64encode(spritesheet_base_bytes).decode('utf-8')
                
                # Get MIME types
                user_mime, _ = _detect_mime_and_ext(source_image_bytes)
                template_mime, _ = _detect_mime_and_ext(spritesheet_base_bytes)
                
                response = openai.responses.create(
                    model="gpt-4.1",
                    input=[
                        {
                            "role": "user",
                            "content": [
                                {"type": "input_text", "text": spritesheet_prompt_with_template},
                                {
                                    "type": "input_image",
                                    "image_url": f"data:{user_mime};base64,{user_image_b64}",
                                },
                                {
                                    "type": "input_image", 
                                    "image_url": f"data:{template_mime};base64,{template_b64}",
                                }
                            ],
                        }
                    ],
                    tools=[{"type": "image_generation"}],
                )
                
                # Extract the generated image
                image_generation_calls = [
                    output
                    for output in response.output
                    if output.type == "image_generation_call"
                ]
                
                if image_generation_calls:
                    sprite_b64 = image_generation_calls[0].result
                    sprite_bytes = base64.b64decode(sprite_b64)
                else:
                    raise Exception("No image generated from gpt-4.1 response")
            else:
                # No template available - skip spritesheet generation
                raise Exception("No template spritesheet available for generation")

            spritesheet_path = f"raw/{user_id}/{job_id}-spritesheet.png"
            spritesheet_url = upload_png(spritesheet_path, sprite_bytes)

            # Update job: final_image_url should reference spritesheet to match app poller; output_path triggers normalization
            supabase.table('generation_jobs').update({
                'status': 'completed',
                'final_image_url': spritesheet_url,
                'avatar_url': avatar_url,
                'spritesheet_url': spritesheet_url,
                'output_path': spritesheet_path
            }).eq('id', job_id).execute()

            # Also reflect avatar on profile immediately
            supabase.table('profiles').update({
                'avatar_url': avatar_url
            }).eq('id', user_id).execute()

            print(f"SUCCESS: Job {job_id} completed (avatar+spritesheet). Normalization will run for spritesheet.")
            return {'statusCode': 200, 'body': json.dumps({'message': 'Job completed', 'jobId': job_id})}

        # CASE 2: Items/Gifts or generic text-to-image jobs (single output)
        else:
            route_label = effective_type or 'generic'
            print(f"Executing single-output job {job_id} type={route_label}")

            # If image-to-image but not avatar_spritesheet, still do edit
            if source_image_path:
                source_image_bytes = supabase.storage.from_('avatars').download(source_image_path)
                src_mime, src_ext = _detect_mime_and_ext(source_image_bytes)
                src_filename = f"user_source{src_ext}"
                result = openai.images.edit(
                    model="gpt-image-1",
                    image=(src_filename, source_image_bytes, src_mime),
                    prompt=prompt
                )
            else:
                # Text to image (items/gifts)
                result = openai.images.generate(
                    model="gpt-image-1",
                    prompt=prompt,
                )

            image_base64 = result.data[0].b64_json
            image_bytes = base64.b64decode(image_base64)

            # Upload as raw and trigger normalization
            final_image_path = f"raw/{user_id}/{job_id}-generated.png"
            final_image_url = upload_png(final_image_path, image_bytes)

            supabase.table('generation_jobs').update({
                'status': 'completed',
                'final_image_url': final_image_url,
                'output_path': final_image_path
            }).eq('id', job_id).execute()

            print(f"SUCCESS: Job {job_id} completed (single-output). Normalization will run if applicable.")
            return {'statusCode': 200, 'body': json.dumps({'message': 'Job completed', 'jobId': job_id})}

    except Exception as e:
        # Error handling
        print(f"ERROR: Job {job_id} failed: {e}")
        error_message = str(e)
        supabase.table('generation_jobs').update({
            'status': 'failed',
            'error_message': error_message
        }).eq('id', job_id).execute()
        return {'statusCode': 500, 'body': json.dumps({'message': 'Job failed', 'error': error_message})}