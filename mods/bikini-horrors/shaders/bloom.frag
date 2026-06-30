#pragma header

uniform float brightness;
uniform float directions;
uniform int quality;
uniform float size;

#define PI 3.141592653589793
#define TWO_PI 6.283185307179586

void main(void) {
    vec2 uv = openfl_TextureCoordv.xy;
    vec4 color = textureCam(bitmap, uv);

    float safeBrightness = max(brightness, 0.0);
    float safeSize = max(size, 0.0);
    vec2 texSize = max(openfl_TextureSize, vec2(1.0));

    // 关键：brightness 为 0 或 size 接近 0 时直接输出原图
    if (safeBrightness <= 0.001 || safeSize <= 0.001) {
        gl_FragColor = color;
        return;
    }

    vec4 bloom = color;
    float maxApply = 1.0;

    float dir = clamp(directions, 1.0, 8.0);
    float q = clamp(float(quality), 1.0, 16.0);
    float radius = min(safeSize, 28.0);

    for (int di = 0; di < 8; di++) {
        float fdi = float(di);
        if (fdi >= dir) continue;

        float d = (fdi / dir) * TWO_PI;
        vec2 dirVec = vec2(sin(d) / texSize.y, cos(d) / texSize.x);

        for (int qi = 1; qi <= 16; qi++) {
            float fqi = float(qi);
            if (fqi > q) continue;

            float i = fqi / q;
            vec2 movement = dirVec * radius * i;

            bloom += textureCam(bitmap, uv + movement) * (1.0 - (i * 0.18));
            maxApply += 1.0;
        }
    }

    maxApply = max(maxApply, 1.0);

    float brightnessFactor = max(0.0, 1.0 - (1.0 / maxApply));
    bloom /= maxApply;

    float brightnessApply = safeBrightness;

    if (brightnessApply < 1.5)
        brightnessApply = max(0.55, mix(1.45, 0.2, abs(1.0 - ((brightnessApply - 1.0) * 2.0))));

    float outputScale = q > 8.0 ? 0.78 : 0.9;

    gl_FragColor = color + ((bloom * brightnessFactor) * brightnessApply * outputScale);
}
