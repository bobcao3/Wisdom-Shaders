#define SSPT_SAMPLES 16 // [6 8 10 12 16 20]

ivec2 raytrace(in vec3 vpos, in vec2 iuv, in vec3 dir, float stride, float stride_multiplier, float zThickness, int noise_i, inout int lod, bool refine) {
    float rayLength = clamp(-vpos.z, 0.1, 16.0);

    vec3 vpos_target = vpos + dir * rayLength;

    vec4 start_proj_pos = gbufferProjection * vec4(vpos, 1.0);
    vec4 target_proj_pos = gbufferProjection * vec4(vpos_target, 1.0);

    float k0 = 1.0 / start_proj_pos.w;
    float k1 = 1.0 / target_proj_pos.w;

    vec3 P0 = start_proj_pos.xyz * k0;
    vec3 P1 = target_proj_pos.xyz * k1;

    vec2 ZW = vec2(vpos.z * k0, k0);
    vec2 dZW = vec2(vpos_target.z * k1 - vpos.z * k0, k1 - k0);

    vec2 uv_dir = (P1.st - P0.st) * 0.5;
    uv_dir *= vec2(viewWidth, viewHeight);

    float invdx = 1.0;

    if (abs(uv_dir.x) > abs(uv_dir.y)) {
        invdx = 1.0 / abs(uv_dir.x);
        uv_dir = vec2(sign(uv_dir.x), uv_dir.y * invdx);
    } else {
        invdx = 1.0 / abs(uv_dir.y);
        uv_dir = vec2(uv_dir.x * invdx, sign(uv_dir.y));
    }

    vec2 dither_uv = floor(vec2(iuv) + WeylNth(frameCounter + noise_i) * 64.0);
    float dither = bayer64(dither_uv); //hash(iuv + vec2((noise_i ^ frameCounter & 0xF) * viewWidth, 0.0));

    uv_dir *= stride;
    dZW *= invdx * stride;

    ivec2 hit = ivec2(-1);

    float last_z = 0.0;

    iuv += uv_dir * 3.0;
    ZW += dZW * 3.0;

    float z_prev = (ZW.x + dZW.x * 0.5) / (ZW.y + dZW.y * 0.5);
    for (int i = 0; i < SSPT_SAMPLES; i++) {
        iuv += uv_dir;
        ZW += dZW;

        vec2 P1 = iuv - uv_dir * dither;
        vec2 ZWd = ZW - dZW * dither;

        if (P1.x < 0 || P1.y < 0 || P1.x > viewWidth || P1.y > viewHeight) return ivec2(-1);

        float z = (ZWd.x + dZW.x * 0.5) / (ZWd.y + dZW.y * 0.5);

        // if (-z > far * 0.9 || -z < near) break;
        if (-z < near) break;

        float zmin = z_prev, zmax = z;
        if (z_prev > z) {
            zmin = z;
            zmax = z_prev;
        }

        int dlod = clamp(int(floor(log2(length(uv_dir)) - 1.0)), 0, lod);

        float sampled_zbuffer = sampleDepthLOD(ivec2(P1), dlod);
        float sampled_zmax = proj2view(getProjPos(ivec2(P1), sampled_zbuffer)).z;
        float sampled_zmin = sampled_zmax - zThickness;

        if (zmax > sampled_zmin && zmin < sampled_zmax && abs(abs(last_z - sampled_zmax) - abs(z - z_prev)) > 0.001) {
            hit = ivec2(P1);
            lod = dlod;
            break;
        }

        last_z = sampled_zmax;
        z_prev = z;

        uv_dir *= stride_multiplier;
        dZW *= stride_multiplier;
    }

    if (refine && hit != ivec2(-1))
    {
        iuv -= uv_dir * dither;
        ZW -= dZW * dither;
        for (int i = 0; i < 4; i++)
        {
            float z = ZW.x / ZW.y;

            int lod = clamp(int(floor(log2(length(uv_dir)) - 1.0)), 0, lod);

            hit = ivec2(iuv);

            vec2 uv = iuv * invWidthHeight;
            float sampled_zbuffer = sampleDepthLODBilinear(uv, lod);
            last_z = proj2view(getProjPos(uv, sampled_zbuffer)).z;
            z_prev = z;

            float z_next = (ZW.x + dZW.x * 1.0) / (ZW.y + dZW.y * 1.0);

            if ((last_z > z_prev && z_next < z_prev) || (last_z < z_prev && z_next > z_prev))
            {
                uv_dir *= -0.5;
                dZW *= -0.5;
            }
            else
            {
                uv_dir *= 0.5;
                dZW *= 0.5;
            }

            iuv += uv_dir;
            ZW += dZW;
        }
    }

    return hit;
}