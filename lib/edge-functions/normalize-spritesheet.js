import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { Image } from 'https://deno.land/x/imagescript@1.2.15/mod.ts';
const SUPABASE_URL = Deno.env.get('SUPABASE_URL');
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY');
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
const serviceClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
async function getInternalSecret() {
  const { data } = await serviceClient.from('function_secrets').select('value').eq('key', 'NORMALIZE_EDGE_SECRET').maybeSingle();
  return data?.value ?? null;
}
function normalizeKey(input, bucket) {
  let v = input;
  // Trim URL to path
  v = v.replace(/^https?:\/\/[^/]*\//, '');
  // Drop storage routing
  v = v.replace(/^storage\/v1\/object\/(?:public|sign)\//, '');
  // Drop leading 'public/'
  v = v.replace(/^public\//, '');
  // Drop bucket prefix
  const prefix = `${bucket}/`;
  if (v.startsWith(prefix)) v = v.slice(prefix.length);
  return v;
}
Deno.serve(async (req)=>{
  const reqId = crypto.randomUUID();
  try {
    console.log(`[normalize:${reqId}] start`);
    if (!(req.headers.get('content-type') || '').includes('application/json')) {
      console.error(`[normalize:${reqId}] bad content-type`, req.headers.get('content-type'));
      return new Response(JSON.stringify({
        error: 'Expected application/json'
      }), {
        status: 400
      });
    }
    const payload = await req.json();
    console.log(`[normalize:${reqId}] payload`, JSON.stringify(payload));
    const { bucket, key, user_id } = payload;
    if (!bucket || !key || !user_id) {
      console.error(`[normalize:${reqId}] missing fields`, { hasBucket: !!bucket, hasKey: !!key, hasUser: !!user_id });
      return new Response(JSON.stringify({
        error: 'bucket, key, and user_id are required'
      }), {
        status: 400
      });
    }
    const headerSecret = req.headers.get('x-internal-secret');
    const storedSecret = await getInternalSecret();
    const isInternal = !!headerSecret && !!storedSecret && headerSecret === storedSecret;
    const authHeader = req.headers.get('Authorization') || '';
    const externalClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: {
        headers: {
          Authorization: authHeader
        }
      }
    });
    if (!isInternal) {
      const { data: userData, error: userErr } = await externalClient.auth.getUser();
      if (userErr || !userData?.user) return new Response(JSON.stringify({
        error: 'Unauthorized'
      }), {
        status: 401
      });
      if (userData.user.id !== user_id) return new Response(JSON.stringify({
        error: 'user_id does not match authenticated user'
      }), {
        status: 403
      });
    }
    const normalizedKey = normalizeKey(key, bucket);
    console.log(`[normalize:${reqId}] normalizedKey`, normalizedKey);
    const expectedPrefix = `raw/${user_id}/`;
    if (!normalizedKey.startsWith(expectedPrefix)) return new Response(JSON.stringify({
      error: `key must start with ${expectedPrefix}`
    }), {
      status: 400
    });
    const { transparencyThreshold = 10, normalizedPadding = 2, forceTileWidth = null, forceTileHeight = null } = payload.options ?? {};
    console.log(`[normalize:${reqId}] options`, { transparencyThreshold, normalizedPadding, forceTileWidth, forceTileHeight });
    const supabase = isInternal ? serviceClient : externalClient;
    // Download raw sprite
    const { data: dl, error: dlErr } = await supabase.storage.from(bucket).download(normalizedKey);
    if (dlErr || !dl) {
      console.error(`[normalize:${reqId}] download failed`, dlErr);
      return new Response(JSON.stringify({
        error: `download failed: ${dlErr?.message ?? 'unknown'}`
      }), {
        status: 400
      });
    }
    const bytes = new Uint8Array(await dl.arrayBuffer());
    console.log(`[normalize:${reqId}] bytes`, { size: bytes.byteLength });
    let src;
    try {
      src = await Image.decode(bytes);
    } catch (e) {
      console.error(`[normalize:${reqId}] decode failed`, e?.message || e);
      return new Response(JSON.stringify({ error: `decode failed: ${e?.message || 'unknown'}` }), { status: 422 });
    }
    // Detection
    const width = src.width, height = src.height;
    console.log(`[normalize:${reqId}] image dims`, { width, height });
    const visited = new Uint8Array(width * height);
    const boxes = [];
    const alphaAt = (x, y)=>{
      if (x < 0 || y < 0 || x >= width || y >= height) return 0;
      try {
        return src.getPixelAt(x, y) >>> 24 & 0xff;
      } catch (_) {
        return 0;
      }
    };
    const floodFill = (sx, sy)=>{
      const stack = [
        [
          sx,
          sy
        ]
      ];
      let minX = sx, maxX = sx, minY = sy, maxY = sy;
      while(stack.length){
        const [x, y] = stack.pop();
        if (x < 0 || y < 0 || x >= width || y >= height) continue;
        const idx = y * width + x;
        if (visited[idx]) continue;
        const a = alphaAt(x, y);
        if (a < transparencyThreshold) continue;
        visited[idx] = 1;
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
        stack.push([
          x + 1,
          y
        ], [
          x - 1,
          y
        ], [
          x,
          y + 1
        ], [
          x,
          y - 1
        ]);
      }
      return {
        x: minX,
        y: minY,
        width: maxX - minX + 1,
        height: maxY - minY + 1
      };
    };
    for(let y = 0; y < height; y++){
      for(let x = 0; x < width; x++){
        const idx = y * width + x;
        if (visited[idx]) continue;
        if (alphaAt(x, y) >= transparencyThreshold) {
          const box = floodFill(x, y);
          if (box.width > 5 && box.height > 5) boxes.push(box);
        }
      }
    }
    console.log(`[normalize:${reqId}] boxes`, { count: boxes.length });
    if (boxes.length === 0) return new Response(JSON.stringify({
      error: 'No frames detected'
    }), {
      status: 422
    });
    boxes.sort((a, b)=>a.y - b.y);
    const rows = [];
    let curr = [];
    let currY = boxes[0].y;
    for (const b of boxes){
      if (Math.abs(b.y - currY) < b.height * 0.5) curr.push(b);
      else {
        if (curr.length) rows.push(curr);
        curr = [
          b
        ];
        currY = b.y;
      }
    }
    if (curr.length) rows.push(curr);
    const extracted = [];
    let maxW = 0, maxH = 0;
    rows.forEach((row, rowIndex)=>{
      row.sort((a, b)=>a.x - b.x);
      row.forEach((box, frameIndex)=>{
        // Clamp crop region within image bounds to avoid OOB
        const cx = Math.max(0, Math.min(box.x, width - 1));
        const cy = Math.max(0, Math.min(box.y, height - 1));
        const cw = Math.max(1, Math.min(box.width, width - cx));
        const ch = Math.max(1, Math.min(box.height, height - cy));
        let frame;
        try {
          frame = src.crop(cx, cy, cw, ch);
        } catch (e) {
          // Skip invalid regions defensively
          return;
        }
        extracted.push({
          img: frame,
          rowIndex,
          frameIndex,
          box
        });
        if (box.width > maxW) maxW = box.width;
        if (box.height > maxH) maxH = box.height;
      });
    });
    const cellW = forceTileWidth ?? maxW + normalizedPadding * 2;
    const cellH = forceTileHeight ?? maxH + normalizedPadding * 2;
    const cols = Math.max(...rows.map((r)=>r.length));
    const totalRows = rows.length;
    const sheetW = cols * cellW;
    const sheetH = totalRows * cellH;
    console.log(`[normalize:${reqId}] grid`, { rows: totalRows, cols, cellW, cellH, sheetW, sheetH });
    const normalized = new Image(sheetW, sheetH);
    normalized.fill(0x00000000);
    const innerW = cellW - normalizedPadding * 2;
    const innerH = cellH - normalizedPadding * 2;
    for (const frame of extracted){
      const col = frame.frameIndex;
      const row = frame.rowIndex;
      const x = col * cellW;
      const y = row * cellH;

      // Ensure the frame fits into the inner cell area; downscale if needed
      let img = frame.img;
      if (img.width > innerW || img.height > innerH) {
        const sx = innerW / img.width;
        const sy = innerH / img.height;
        const scale = Math.min(sx, sy);
        const newW = Math.max(1, Math.floor(img.width * scale));
        const newH = Math.max(1, Math.floor(img.height * scale));
        img = img.resize(newW, newH);
      }

      // Center within cell; clamp to avoid negative offsets
      const offsetX = Math.max(0, Math.floor((innerW - img.width) / 2));
      const offsetY = Math.max(0, Math.floor((innerH - img.height) / 2));
      const ox = x + normalizedPadding + offsetX;
      const oy = y + normalizedPadding + offsetY;

      // Composite
      normalized.composite(img, ox, oy);
    }
    const pngBytes = await normalized.encode();
    const metadata = {
      originalFrameCount: extracted.length,
      normalizedDimensions: {
        width: sheetW,
        height: sheetH
      },
      frameSize: {
        width: cellW,
        height: cellH
      },
      contentSize: {
        width: maxW,
        height: maxH
      },
      padding: normalizedPadding,
      grid: {
        rows: totalRows,
        cols
      },
      forcedTileSize: {
        width: forceTileWidth,
        height: forceTileHeight
      },
      frames: extracted.map((f)=>({
          rowIndex: f.rowIndex,
          frameIndex: f.frameIndex,
          originalBoundingBox: f.box,
          originalSize: {
            width: f.img.width,
            height: f.img.height
          }
        }))
    };
    const outPngPath = `normalized/${user_id}/spritesheet.png`;
    const outMetaPath = `normalized/${user_id}/metadata.json`;
    const up1 = await supabase.storage.from(bucket).upload(outPngPath, new Blob([
      pngBytes
    ], {
      type: 'image/png'
    }), {
      upsert: true,
      contentType: 'image/png'
    });
    if (up1.error) {
      console.error(`[normalize:${reqId}] upload png failed`, up1.error);
      return new Response(JSON.stringify({
        error: up1.error.message
      }), {
        status: 400
      });
    }
    const up2 = await supabase.storage.from(bucket).upload(outMetaPath, new Blob([
      JSON.stringify(metadata, null, 2)
    ], {
      upsert: true,
      contentType: 'application/json'
    }));
    if (up2.error) {
      console.error(`[normalize:${reqId}] upload meta failed`, up2.error);
      return new Response(JSON.stringify({
        error: up2.error.message
      }), {
        status: 400
      });
    }
    const prof = await supabase.from('profiles').update({
      normalized_sprite_path: outPngPath
    }).eq('id', user_id);
    if (prof.error) {
      console.error(`[normalize:${reqId}] update profile failed`, prof.error);
    }
    const upd = await serviceClient.from('generation_jobs').update({
      normalized_path: outPngPath,
      normalized_metadata_path: outMetaPath,
      normalized_at: new Date().toISOString()
    }).eq('user_id', user_id).eq('output_path', key).is('normalized_path', null);
    if (upd.error) {
      console.error(`[normalize:${reqId}] update job failed`, upd.error);
    }
    console.log(`[normalize:${reqId}] ok`, { outPngPath, outMetaPath });
    return new Response(JSON.stringify({
      ok: true,
      normalized_png_path: outPngPath,
      metadata_path: outMetaPath,
      frame_size: {
        w: cellW,
        h: cellH
      },
      mode: isInternal ? 'internal' : 'external'
    }), {
      headers: {
        'content-type': 'application/json'
      }
    });
  } catch (err) {
    console.error(`[normalize:${reqId}] fatal`, err?.message || err);
    return new Response(JSON.stringify({
      error: err.message,
      reqId
    }), {
      status: 500
    });
  }
});
