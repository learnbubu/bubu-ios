// The avatar player's drawing: parts bent on the CPU, drawn here bottom up; the light's shadows made per part (the
// shapes of the parts above it that cast, moved from the lamp, into one mask), then laid on the part's own colour.
#include <metal_stdlib>
using namespace metal;

/// document units -> clip space; `shift` moves a caster's shape away from the lamp (document units)
struct AvatarFrame { float2 scale; float2 offset; float2 shift; };
/// a part's opacity, how dark its shadow is, and the drawable's size (to find its place in the shadow mask)
struct AvatarPaint { float opacity; float strength; float2 viewport; };

struct AvatarVOut { float4 pos [[position]]; float2 uv; };

vertex AvatarVOut avatar_vertex(const device float2 *pos [[buffer(0)]], const device float2 *uv [[buffer(1)]],
                                constant AvatarFrame &f [[buffer(2)]], uint vid [[vertex_id]]) {
    AvatarVOut o;
    o.pos = float4((pos[vid] + f.shift) * f.scale + f.offset, 0, 1);
    o.uv = uv[vid];
    return o;
}

/// a part: its picture (premultiplied), darkened where the shadow mask says, at its opacity
fragment float4 avatar_part(AvatarVOut in [[stage_in]], texture2d<float> tex [[texture(0)]], texture2d<float> mask [[texture(1)]],
                            constant AvatarPaint &p [[buffer(0)]]) {
    constexpr sampler s(filter::linear, mip_filter::linear, address::clamp_to_edge);
    float4 c = tex.sample(s, in.uv);
    float m = mask.sample(s, in.pos.xy / p.viewport).r;
    c.rgb *= 1.0 - p.strength * m;
    return c * p.opacity;
}

/// a caster's shape, white where it's drawn (into a shadow mask)
fragment float4 avatar_silhouette(AvatarVOut in [[stage_in]], texture2d<float> tex [[texture(0)]]) {
    constexpr sampler s(filter::linear, mip_filter::linear, address::clamp_to_edge);
    float a = tex.sample(s, in.uv).a;
    return float4(a, a, a, a);
}

/// a part in a caster's way: only marks the stencil where it's drawn
fragment float4 avatar_blocker(AvatarVOut in [[stage_in]], texture2d<float> tex [[texture(0)]]) {
    constexpr sampler s(filter::linear, mip_filter::linear, address::clamp_to_edge);
    if (tex.sample(s, in.uv).a < 0.5) discard_fragment();
    return float4(0);
}
