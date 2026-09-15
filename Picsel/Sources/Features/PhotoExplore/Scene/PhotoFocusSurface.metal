//
//  PhotoFocusSurface.metal
//  Picsel
//
//  Created by Jonghyeon Lee on 9/15/26.
//

#include <metal_stdlib>
#include <RealityKit/RealityKit.h>

using namespace metal;

[[visible]]
void photoFocusSurface(realitykit::surface_parameters params)
{
    // x: 초점 거리, y: 선명한 깊이 범위, z: 최대 블러 깊이, w: 최대 mip bias (-1이면 빈 사진)
    const float4 focus = params.uniforms().custom_parameter();

    // 실제 렌더링 중인 카메라 기준으로 계산해 관성·포커스 애니메이션도 연속적으로 따릅니다.
    const float depth = -params.uniforms().model_to_view()[3].z;
    const float depthError = abs(depth - focus.x);
    const float blurAmount = smoothstep(focus.y, focus.z, depthError);

    half3 color = half3(params.material_constants().base_color_tint());
    if (focus.w >= 0.0) {
        // 추가 텍스처나 다중 패스 없이, 기존 mipmap으로 약하게 흐립니다.
        constexpr sampler photoSampler(address::clamp_to_edge, filter::linear, mip_filter::linear);
        float2 uv = params.geometry().uv0();
        uv.y = 1.0 - uv.y; // CGImage 텍스처를 기존 UnlitMaterial과 같은 방향으로 표시합니다.
        color *= params.textures().base_color().sample(
            photoSampler,
            uv,
            bias(blurAmount * focus.w)
        ).rgb;
    }

    // 알파를 낮추지 않고 배경과 어울리는 옅은 민트를 섞습니다.
    // 완전히 불투명한 면이 깊이를 기록하므로 뒤쪽 사진은 비치지 않습니다.
    constexpr half3 mistColor = half3(0.855h, 0.939h, 0.922h);
    constexpr half maximumFade = 0.8h;
    params.surface().set_emissive_color(mix(color, mistColor, half(blurAmount) * maximumFade));
    params.surface().set_opacity(1.0h);
}
